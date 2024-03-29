/*-
 * Copyright (c) 2015-2016 elementary LLC.
 * Copyright (C) 2015-2016 Ikey Doherty <ikey@solus-project.com>
 * Copyright (C) 2023 Fyra Labs
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Cappy Ishihara <cappy@cappuchino.xyz>
 */

/*
 * Code based on budgie-desktop:
 * https://github.com/solus-project/budgie-desktop

 * And more shameless elementary OS code:
 * https://github.com/elementary/pantheon-agent-polkit
 */

namespace KiriPolkit {
    public class Agent : PolkitAgent.Listener {
        public Agent () {
            // app = new PromptApp ();
            register_with_session.begin ((obj, res) => {
                bool success = register_with_session.end (res);
                if (!success) {
                    warning ("Failed to register with Session manager");
                }
            });
        }

        public He.Application app;

        public override async bool initiate_authentication (string action_id,
                                                            string message,
                                                            string icon_name,
                                                            Polkit.Details details,
                                                            string cookie,
                                                            GLib.List<Polkit.Identity> identities,
                                                            GLib.Cancellable? cancellable) throws Polkit.Error {
            if (identities == null) {
                return false;
            }

            debug ("Initiating authentication for action %s", action_id);
            app = new PromptApp ();
            app.run (null);

            var dialog = new KiriPolkit.PromptWindow (message, icon_name, cookie, identities, cancellable);
            dialog.set_application (app);
            // app.startup ();
            dialog.done.connect (() => initiate_authentication.callback ());


            dialog.set_visible (true);
            yield;


            if (dialog.was_canceled) {
                warning ("Authentication dialog was dismissed by the user");
                // Oh, turns out if you throw an error it crashes the whole thing!
                // throw new Polkit.Error.CANCELLED ("Authentication dialog was dismissed by the user");
            }
            dialog.set_visible (false);
            dialog.dispose ();
            app.quit ();

            return true;
        }

        private async bool register_with_session () {
            var sclient = yield Utils.register_with_session ("com.fyralabs.KiriPolkitAgent");

            if (sclient == null) {
                return false;
            }

            sclient.query_end_session.connect ((flags) => session_respond (sclient, flags));
            sclient.end_session.connect ((flags) => session_respond (sclient, flags));
            sclient.stop.connect (session_stop);

            return true;
        }

        private void session_respond (SessionClient sclient, uint flags) {
            try {
                sclient.end_session_response (true, "");
            } catch (Error e) {
                warning ("Unable to respond to session manager: %s", e.message);
            }
        }

        private void session_stop () {
        }
    }

    public static int main (string[] args) {
        Gtk.init ();
        // prompt.set_application (app);
        // app.set_application_id ("co.tauos.polkit");
        // app.add_window (prompt);
        // prompt.show ();


        var agent = new Agent ();
        int pid = Posix.getpid ();


        Polkit.Subject? subject = null;
        try {
            subject = new Polkit.UnixSession.for_process_sync (pid, null);
        } catch (Error e) {
            critical ("Unable to initiate Polkit: %s", e.message);
            return 1;
        }

        try {
            PolkitAgent.register_listener (agent, subject, "/com/fyralabs/polkit/AuthenticationAgent");
        } catch (Error e) {
            print ("Unable to register Polkit agent: %s", e.message);
            return 1;
        }

        while (true) {
            MainContext.default ().iteration (true);
        }

        // return agent.app.run (args);
    }
}