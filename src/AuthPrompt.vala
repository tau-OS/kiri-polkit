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

namespace PolAgent {
    public class AgentApp : He.Application {
        private He.ApplicationWindow window;
        private Gtk.Box main_box;
        public AgentApp () {
            Object (application_id: "co.tauos.polagent");
        }

        // main window
        public override void activate () {
            if (window == null) {

                main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 24) {
                    margin_top = 24,
                    margin_bottom = 24,
                    margin_start = 24,
                    margin_end = 24
                };
                // allocate space for window
                var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 24);

                var box2 = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
                box2.set_hexpand (true);
                // add lock icon
                var image = new Gtk.Image () {
                    valign = Gtk.Align.START,
                    pixel_size = 48,
                    icon_name = "security-high-symbolic"
                };
                box.append (image);
                var label = new Gtk.Label (_("Authentication Required")) {
                    halign = Gtk.Align.START,
                    valign = Gtk.Align.START,
                };
                label.add_css_class ("view-title");
                box2.append (label);

                var warning_txt = new Gtk.Label (_("An application is attempting to perform an action that requires additional privileges:")) {
                    halign = Gtk.Align.START,
                    valign = Gtk.Align.START,
                    wrap = false,
                    wrap_mode = Pango.WrapMode.WORD
                };
                box2.append (warning_txt);

                var text = new Gtk.Label (_("Authentication is required to install software")) {
                    halign = Gtk.Align.START,
                    valign = Gtk.Align.START,
                    wrap = true,
                    wrap_mode = Pango.WrapMode.WORD
                };

                box2.append (text);
                box.append (box2);
                // user box
                // get user name
                var user = GLib.Environment.get_user_name ();
                var user_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 24);
                var avatar = new Gtk.Image () {
                    pixel_size = 24,
                    icon_name = "avatar-default-symbolic"
                };
                user_box.append (avatar);
                var user_label = new Gtk.Label (user) {
                    halign = Gtk.Align.START,
                    valign = Gtk.Align.CENTER,
                };
                user_box.append (user_label);
                box2.append (user_box);

                // password box
                var entry = new Gtk.Entry () {
                    halign = Gtk.Align.FILL,
                    valign = Gtk.Align.CENTER,
                    placeholder_text = _("Password"),
                    visibility = false
                };
                
                entry.set_icon_from_icon_name (Gtk.EntryIconPosition.PRIMARY, "dialog-password");
                entry.set_icon_activatable (Gtk.EntryIconPosition.PRIMARY, true);
                
                box2.append (entry);

                // buttons

                var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 24) {
                    halign = Gtk.Align.END,
                    valign = Gtk.Align.END
                };
                var cancel_button = new He.TextButton (_("Cancel")) {
                    halign = Gtk.Align.END,
                    valign = Gtk.Align.END
                };
                cancel_button.clicked.connect (() => {
                    window.close ();
                });
                button_box.append (cancel_button);
                var ok_button = new He.FillButton (_("Authenticate")) {
                    halign = Gtk.Align.END,
                    valign = Gtk.Align.END
                };
                ok_button.clicked.connect (() => {
                    print ("ok");
                    window.close ();
                });

                button_box.append (ok_button);
                box2.append (button_box);


                main_box.append (box);
                var window_handle = new Gtk.WindowHandle () {
                    child = main_box
                };

                window = new He.ApplicationWindow (this) {
                    application = this,
                    child = window_handle,
                    icon_name = application_id,
                    title = _("Authentication")
                };

                window.set_size_request (600, 200);
                window.set_default_size (600, 200);
                window.set_resizable (false);
                window.show ();
            }
        }

        // main function
        public static int main (string[] args) {
            Intl.setlocale (LocaleCategory.ALL, "");
            Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
            Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
            Intl.textdomain (GETTEXT_PACKAGE);
            var app = new AgentApp ();
            return app.run (args);
        }
    }
}