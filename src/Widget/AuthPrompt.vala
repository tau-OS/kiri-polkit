/*-
 * Copyright (c) 2022 Fyra Labs
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Library General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

// This is the PolKit agent for tauOS, using libhelium as the GUI

namespace TauPolkit {

    private class UserEntry : Gtk.Box {
        public Polkit.Identity? identity { get; construct; }
        public string? username { get; construct; }
        public string? realname { get; construct; }
        public string? icon { get; construct; }
        public int uid { get; set; }

        public UserEntry (Polkit.Identity _identity) {
            Object (
                    identity: _identity
            );
        }

        construct {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            // if identity is unix user
            if (identity == null) {
                return;
            }


            // if identity is of type UnixUser
            if (identity is Polkit.UnixUser) {
                var unix_user = identity as Polkit.UnixUser;
                unowned Posix.Passwd? user;
                user = Posix.getpwuid ((int) unix_user.get_uid ());
                username = user.pw_name;
                realname = user.pw_gecos;
                uid = (int) user.pw_uid;

                debug ("Username: %s", username);
                debug ("Realname: %s", realname);
                debug ("UID: %d", uid);
                // get pfp
                var pfp = user.pw_dir + "/.face";
                if (GLib.FileUtils.test (pfp, GLib.FileTest.EXISTS)) {
                    icon = pfp;
                } else {
                    icon = null;
                }
            }

            Gtk.Image icon_image;
            if (icon == null) {
                icon_image = new Gtk.Image () {
                    icon_name = "avatar-default-symbolic",
                };
            } else {
                icon_image = new Gtk.Image.from_file (icon);
            }

            icon_image.set_icon_size (Gtk.IconSize.LARGE);

            box.append (icon_image);

            string display_name = realname ?? username;
            debug ("Display name: %s", display_name);
            var name_label = new Gtk.Label (display_name) {
                halign = Gtk.Align.START,
                valign = Gtk.Align.CENTER
            };

            box.append (name_label);

            this.append (box);
        }

        public Gtk.ListBoxRow get_row () {
            var row = new Gtk.ListBoxRow ();
            row.set_child (this);
            return row;
        }

        public UserEntry new_instance () {
            return new UserEntry (identity);
        }
    }

    public class PromptWindow : He.Dialog {
        public signal void done ();

        public bool was_canceled = false;
        private PolkitAgent.Session? pk_session = null;
        private Polkit.Identity? pk_identity = null;
        private unowned Cancellable cancellable;
        private unowned List<Polkit.Identity?>? idents;

        private Gtk.MenuButton user_select;

        private Gtk.Popover user_popover;

        private Gtk.ListBox user_list;

        private ulong error_signal_id;
        private ulong request_signal_id;
        private ulong info_signal_id;
        private ulong complete_signal_id;

        private UserEntry? selected_user;

        // private Gtk.Widget error_box;
        private Gtk.Label error_label;

        public string msg { get; set; }

        private string cookie;
        private bool canceling = false;

        private Gtk.Entry password_entry;


        public PromptWindow (string message, string icon_name, string _cookie,
            List<Polkit.Identity?>? _idents, GLib.Cancellable _cancellable) {
            Object (
            );


            // debug ("_Cookie: %s", _cookie);
            cookie = _cookie;
            debug ("Cookie: %s", cookie);
            cancellable = _cancellable;
            idents = _idents;
            debug (idents.length ().to_string ());
            msg = message;
            subtitle = msg;
            cancellable.cancelled.connect (cancel);
            debug ("Message: %s", msg);
            load_idents ();
            grab_focus ();
            // debug ("Icon: %s", icon_name);

            // return construct
        }

        private void cancel () {
            canceling = true;
            if (pk_session != null) {
                pk_session.cancel ();
            }

            debug ("Authentication cancelled");
            was_canceled = true;

            canceling = false;
            done ();
        }

        // private Gtk.Box main_box;

        private void load_idents () {
            if (idents == null) {
                return;
            }

            // if user_list is already populated, clear it
            user_list.selected_foreach ((row) => {
                user_list.remove (row);
            });
            foreach (unowned Polkit.Identity? ident in idents) {
                if (ident == null) {
                    continue;
                }

                var user_entry = new UserEntry (ident);
                // if uid
                // get uid
                var current_uid = (int) Posix.getuid ();
                if (user_entry.uid == current_uid) {
                    user_select.set_child (user_entry.new_instance ());
                    selected_user = user_entry.new_instance ();
                }
                user_list.append (user_entry.get_row ());
            }
            user_list.unselect_all ();

        }

        construct {

            user_select = new Gtk.MenuButton () {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
                tooltip_text = _("Select a user to authenticate as")
            };
            user_select.add_css_class ("flat");

            // load stuff into user_select

            user_list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.SINGLE,
                activate_on_single_click = true
            };

            user_list.row_activated.connect ((row) => {
                var user_entry = (UserEntry) row.get_child ();
                user_select.set_child (user_entry.new_instance ());
                // set pk_identity
                //  pk_identity = user_entry.identity;
                selected_user = user_entry;
                // deselect all
                user_list.unselect_all ();
                user_popover.popdown ();
            });


            // add dummy users to list
            //  var user1 = new Gtk.ListBoxRow ();
            //  var user_row_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            //  var user_row_icon = new Gtk.Image () {
            //      icon_name = "avatar-default-symbolic",
            //      pixel_size = 32
            //  };
            //  var user_row_label = new Gtk.Label (_("User 1"));
            //  user_row_box.append (user_row_icon);
            //  user_row_box.append (user_row_label);
            //  user1.set_child (user_row_box);
            //  user_list.append (user1);


            var userlist_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            userlist_box.append (user_list);



            user_popover = new Gtk.Popover ();
            user_popover.set_child (userlist_box);

            user_select.set_popover (user_popover);
            user_select.set_can_target (true);
            //  user_select.set_child (user_row_box);



            // var uid = Posix.getuid ();
            //// try and cast to int or 0
            // var uid_int = (int) uid;

            // var id = new Polkit.UnixUser (uid_int);
            error_label = new Gtk.Label ("") {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
                wrap = true,
                wrap_mode = Pango.WrapMode.WORD_CHAR,
                max_width_chars = 30,
                xalign = 0,
                yalign = 0.5f
            };
            error_label.add_css_class ("warning");
            // pk_identity = id;
            set_title (_("Authentication Required"));
            modal = true;
            icon = "security-high-symbolic";
            title = _("Authentication Required");
            // main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 24) {
            // margin_top = 24,
            // margin_bottom = 24,
            // margin_start = 24,
            // margin_end = 24
            // };

            //// allocate space for window
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 24);

            var box2 = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            box2.set_hexpand (true);
            //// add lock icon
            // var image = new Gtk.Image () {
            // valign = Gtk.Align.START,
            // pixel_size = 48,
            // icon_name = "security-high-symbolic"
            // };
            // box.append (image);
            // var label = new Gtk.Label (_("Authentication Required")) {
            // halign = Gtk.Align.START,
            // valign = Gtk.Align.START,
            // };
            // label.add_css_class ("view-title");
            // box2.append (label);

            // var warning_txt = new Gtk.Label (_("An application is attempting to perform an action that requires additional privileges:")) {
            // halign = Gtk.Align.START,
            // valign = Gtk.Align.START,
            // wrap = false,
            // wrap_mode = Pango.WrapMode.WORD
            // };
            // box2.append (warning_txt);
            info = _("An application is attempting to perform an action that requires additional privileges.");
            this.icon_name = "security-high";
            debug ("Message: %s", msg);
            // subtitle = msg;
            // notify["msg"].connect (() => {
            // debug ("Subtitle changed");
            // debug (subtitle);
            // debug (msg);
            // if (subtitle != msg) {
            // debug ("Subtitle changed to %s", subtitle);
            // msg = subtitle;
            // }
            // });
            debug (msg);

            // box2.append (text);
            // box.append (box2);
            //// user box
            //// get user name
            // var user = GLib.Environment.get_user_name ();
            // var user_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 24);
            // var avatar = new Gtk.Image () {
            // pixel_size = 24,
            // icon_name = "avatar-default-symbolic"
            // };
            // user_box.append (avatar);
            // var user_label = new Gtk.Label (user) {
            // halign = Gtk.Align.START,
            // valign = Gtk.Align.CENTER,
            // };
            // user_box.append (user_label);
            // box2.append (user_box);

            //// password box
            // box to contain the password entry

            //// buttons

            // var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 24) {
            // halign = Gtk.Align.END,
            // valign = Gtk.Align.END
            // };
            // button_box.append (cancel_button);
            var ok_button = new He.FillButton (_("Authenticate")) {
                halign = Gtk.Align.END,
                valign = Gtk.Align.END
            };

            cancel_button.clicked.connect (() => {
                cancel ();
            });
            primary_button = ok_button;
            ok_button.clicked.connect (() => {
                // subtitle = "Hello";
                authenticate ();
            });
            password_entry = new Gtk.Entry () {
                halign = Gtk.Align.FILL,
                valign = Gtk.Align.CENTER,
                placeholder_text = _("Password"),
                visibility = false,
            };

            password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
            password_entry.set_icon_from_icon_name (Gtk.EntryIconPosition.PRIMARY, "dialog-password-symbolic");
            password_entry.icon_release.connect (() => {
                password_entry.visibility = !password_entry.visibility;
            });
            password_entry.set_icon_activatable (Gtk.EntryIconPosition.PRIMARY, true);
            // connect to authorize button
            password_entry.activate.connect (() => {
                ok_button.clicked ();
            });
            // append error box before password entry
            box2.append (user_select);
            box2.append (error_label);
            box2.append (password_entry);

            box.append (box2);

            add (box);

            select_session ();


            // main_box.append (box);
            // var window_handle = new Gtk.WindowHandle () {
            // child = main_box
            // };

            // entry.activate.connect (() => {
            // ok_button.clicked ();
            // });

            // set_child (window_handle);

            // set_size_request (600, 200);
            // set_default_size (600, 200);
            set_resizable (false);
            // show ();

            // check if parent is a He.Application
            // if (parent is He.Application) {
            // var app = (He.Application) parent;
            // }
        }

        private void select_session () {
            if (pk_session != null) {
                deselect_session ();
            }
            // set pk_identity to current user
            // get current user
            // var user = GLib.Environment.get_user_name ();
            // get uid
            var uid = Posix.getuid ();
            // try and cast to int or 0
            var uid_int = (int) uid;

            // get UnixUser from uid
            var user = new Polkit.UnixUser (uid_int);
            // get userentry from uid
            

            if (selected_user == null) {
                selected_user = new UserEntry (user);
            }

            // get selected user from list box

            debug ("Selected user: %s", selected_user.name);
            var id = selected_user.identity;
            
            pk_identity = id;
            // pk_identity = new Polkit.UnixUser (GLib.Environment.);

            pk_session = new PolkitAgent.Session (pk_identity, cookie);
            error_signal_id = pk_session.show_error.connect (on_pk_show_error);
            complete_signal_id = pk_session.completed.connect (on_pk_session_completed);
            request_signal_id = pk_session.request.connect (on_pk_request);
            info_signal_id = pk_session.show_info.connect (on_pk_show_info);
            pk_session.initiate ();
        }

        private void on_pk_show_info (string text) {
            print (text);
        }

        private void on_pk_request (string request, bool echo_on) {
            password_entry.visibility = echo_on;
            if (!request.has_prefix ("Password:")) {
                // password_label.label = request;
                password_entry.placeholder_text = request;
            }
        }

        private void on_pk_show_error (string text) {
            error_label.label = text;
            password_entry.secondary_icon_name = "dialog-error-symbolic";
            sensitive = true;
        }

        private void on_pk_session_completed (bool authorized) {
            sensitive = true;
            if (!authorized || cancellable.is_cancelled ()) {
                if (!canceling) {
                    on_pk_show_error (_("Authentication failed. Please try again."));
                }

                deselect_session ();
                password_entry.set_text ("");
                password_entry.grab_focus ();
                select_session ();
                return;
            } else {
                done ();
            }
        }

        private void deselect_session () {
            if (pk_session != null) {
                SignalHandler.disconnect (pk_session, error_signal_id);
                SignalHandler.disconnect (pk_session, complete_signal_id);
                SignalHandler.disconnect (pk_session, request_signal_id);
                SignalHandler.disconnect (pk_session, info_signal_id);
                pk_session = null;
            }
        }

        private void authenticate () {
            if (pk_session == null) {
                select_session ();
            }

            password_entry.secondary_icon_name = "";
            // feedback_revealer.reveal_child = false;
            password_entry.visibility = false;
            // var t = pk_session.get_type ();

            sensitive = false;
            // debug (password_entry.get_text ());
            // debug (t.name ());
            pk_session.response (password_entry.get_text ());
        }
    }

    // Only for testing purposes, real usage is in Agent.vala
    public class PromptApp : He.Application {


        public He.Window window;
        public PromptApp () {
            Object (application_id: "co.tauos.polagent");
        }

        // main window
        public override void activate () {
            /*  if (window == null) {
                var win = new PromptWindow ();
                win.set_application (this);
                window = win;
               }  */
        }

        // main function
        // public static int main (string[] args) {
        // Intl.setlocale (LocaleCategory.ALL, "");
        // Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        // Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        // Intl.textdomain (GETTEXT_PACKAGE);
        // var app = new PromptApp ();
        // return app.run (args);
        // }
    }
}