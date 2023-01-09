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

// Dear Lains the designer: I'm sorry for the mess
// I hope that one day you will eventually clean up this code and make this app
// comply by the HIG.

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
            icon_image.add_css_class ("rounded");
            icon_image.add_css_class ("content-block-image");


            box.append (icon_image);

            string display_name = realname ?? username;
            debug ("Display name: %s", display_name);
            var name_label = new Gtk.Label (display_name) {
                halign = Gtk.Align.START,
                valign = Gtk.Align.CENTER
            };

            box.append (name_label);
            box.hexpand = true;

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

        private Gtk.Label error_label;

        public string msg { get; set; }

        private string cookie;
        private bool canceling = false;

        private Gtk.Entry password_entry;


        public PromptWindow (string message, string icon_name, string _cookie,
            List<Polkit.Identity?>? _idents, GLib.Cancellable _cancellable) {
            Object (
            );


            cookie = _cookie;
            cancellable = _cancellable;
            idents = _idents;
            msg = message;
            subtitle = msg;
            cancellable.cancelled.connect (cancel);
            load_idents ();
            password_entry.grab_focus ();

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
                // This is probably inefficient,
                // but I do not want to initiate a whole new list and
                // re-style it
                user_list.remove (row);
            });
            foreach (unowned Polkit.Identity? ident in idents) {
                if (ident == null) {
                    continue;
                }

                var user_entry = new UserEntry (ident);
                // todo: possibly use polkit identity instead of current user
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

            // the comment below breaks the styling,
            // shit still looks ugly though
            // user_select.add_css_class ("content-block");
            // user_select.add_css_class ("content-list");

            // load stuff into user_select

            user_list = new Gtk.ListBox () {
                selection_mode = Gtk.SelectionMode.NONE,
                activate_on_single_click = true
            };


            user_list.add_css_class ("flat");
            // user_list.add_css_class ("content-list");

            user_select.activate.connect (() => {
                user_popover.popup ();
                user_list.unselect_all ();
            });

            user_list.row_activated.connect ((row) => {
                var user_entry = (UserEntry) row.get_child ();
                user_select.set_child (user_entry.new_instance ());
                selected_user = user_entry;
                // deselect all
                user_list.unselect_all ();
                user_popover.popdown ();
            });



            var userlist_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            userlist_box.append (user_list);



            user_popover = new Gtk.Popover ();
            user_popover.set_child (userlist_box);
            user_popover.set_has_arrow (false);
            user_popover.add_css_class ("flat");

            user_select.set_popover (user_popover);
            user_select.set_can_target (true);
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
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 24);

            var box2 = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            box2.set_hexpand (true);
            info = _("An application is attempting to perform an action that requires additional privileges.");
            this.icon_name = "security-high";

            var ok_button = new He.FillButton (_("Authenticate")) {
                halign = Gtk.Align.END,
                valign = Gtk.Align.END
            };

            cancel_button.clicked.connect (() => {
                cancel ();
            });

            // connect closed signal
            this.close_request.connect (() => {
                cancel_button.clicked ();
            });
            primary_button = ok_button;
            ok_button.clicked.connect (() => {
                authenticate ();
            });
            password_entry = new Gtk.Entry () {
                halign = Gtk.Align.FILL,
                valign = Gtk.Align.CENTER,
                placeholder_text = _("Password"),
                visibility = false,
            };

            password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
            password_entry.set_icon_from_icon_name (Gtk.EntryIconPosition.PRIMARY, "view-conceal-symbolic");
            password_entry.icon_release.connect (() => {
                password_entry.visibility = !password_entry.visibility;
                if (password_entry.visibility) {
                    password_entry.set_icon_from_icon_name (Gtk.EntryIconPosition.PRIMARY, "view-reveal-symbolic");
                } else {
                    password_entry.set_icon_from_icon_name (Gtk.EntryIconPosition.PRIMARY, "view-conceal-symbolic");
                }
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

            // useless call that makes you do things twice

            select_session ();


            set_resizable (false);
        }

        private void select_session () {
            if (pk_session != null) {
                deselect_session ();
            }
            if (selected_user == null) {
                // compressed into inline for maximum efficiency
                selected_user = new UserEntry (new Polkit.UnixUser ((int) Posix.getuid ()));
            }

            // get selected user from list box

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
            // recolor password entry
            password_entry.add_css_class ("error");
            password_entry.secondary_icon_name = "dialog-error-symbolic";
            sensitive = true;
            shake ();
            // async
            GLib.Timeout.add (2000, () => {
                password_entry.remove_css_class ("error");
                // password_entry.secondary_icon_name = null;
                return false;
            });
        }

        private void shake () {
            int x, y;
            
            // Programmers notes:
            // This shake function does not atually work.
            // CSS magic is required for shaking.


            password_entry.grab_focus ();
            for (int n = 0; n < 10; n++) {

                // randomly change the margins
                x = (int) (Random.int_range (0, 10));
                y = (int) (Random.int_range (0, 10));
                password_entry.margin_top = y;
                password_entry.margin_bottom = y;
                Thread.usleep (10000);
            }

            password_entry.margin_top = 0;
            password_entry.margin_bottom = 0;
            password_entry.margin_start = 0;
            password_entry.margin_end = 0;
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


            // if we do not do this, the agent will freeze until the end of time
            // no im serious. polkit is very janky.
            // I seriously do not know how people continue to write polkit
            // agents and the API is locked behind a compiler flag
            if (password_entry.get_text () == "") {
                on_pk_show_error (_("Please enter a password."));
                return;
            }

            password_entry.secondary_icon_name = "";
            password_entry.visibility = false;

            sensitive = false;
            pk_session.response (password_entry.get_text ());
        }
    }

    // Gtk.Application so GTK4 can live peacefully
    public class PromptApp : He.Application {


        public He.Window window;
        public PromptApp () {
            Object (application_id: "com.fyralabs.KiriPolkitAgent");
        }

        // main window
        public override void activate () {
            /*
                Activate what?
                What do I activate?
                There's nothing in here.
                This is a blank window.
                GO AWAY. THERE'S NOTHING TO SEE HERE

                (obligatory activate implementation so GTK does not
                scream at me)
            */
            
            // do something idk
            // assert that 1 + 1 = 2, or
            // we are living in 1984
            assert (1 + 1 == 2);
            if (1 + 1 != 2) {
                // if we are not in 1984, then
                error ("Big brother has now redefined physics. Unable to continue due to legal reasons. Exiting...");
                // we are in 1984
            }
        }
    }
}