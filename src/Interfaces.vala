/*-
 * Copyright (c) 2015-2016 elementary LLC.
 * Copyright (C) 2015-2016 Ikey Doherty <ikey@solus-project.com>
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
 */

 namespace KiriPolkit {
    [DBus (name = "org.gnome.SessionManager")]
    public interface SessionManager : Object {
        public abstract async ObjectPath register_client (string app_id, string client_start_id) throws GLib.Error;
    }

    [DBus (name = "org.gnome.SessionManager.ClientPrivate")]
    public interface SessionClient : Object {
        public abstract void end_session_response (bool is_ok, string reason) throws GLib.Error;

        public signal void stop ();
        public signal void query_end_session (uint flags);
        public signal void end_session (uint flags);
        public signal void cancel_end_session ();
    }
}
