/*
 * Copyright 2011-2018 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Maxwell Barvian
 *              Corentin Noël <corentin@elementaryos.org>
 */

public class Maya.View.EventButton : Gtk.Revealer {
    public ECal.Component comp { get; construct set; }

    private static Gtk.CssProvider css_provider;

    private Gtk.Label label;
    private Gtk.StyleContext grid_style_context;

    public EventButton (ECal.Component comp) {
        Object (
             comp: comp
         );
    }

    static construct {
        css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("/io/elementary/calendar/AgendaEventRow.css");
    }

    construct {
        transition_type = Gtk.RevealerTransitionType.CROSSFADE;

        label = new Gtk.Label (comp.get_summary ().get_value ());
        label.hexpand = true;
        label.ellipsize = Pango.EllipsizeMode.END;
        label.xalign = 0;
        label.show ();

        var internal_grid = new Gtk.Grid ();
        internal_grid.add (label);

        grid_style_context = internal_grid.get_style_context ();
        grid_style_context.add_class ("event");
        grid_style_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var event_box = new Gtk.EventBox ();
        event_box.events |= Gdk.EventMask.BUTTON_PRESS_MASK;
        event_box.events |= Gdk.EventMask.SCROLL_MASK;
        event_box.events |= Gdk.EventMask.SMOOTH_SCROLL_MASK;
        event_box.add (internal_grid);

        add (event_box);

        event_box.button_press_event.connect ((event) => {
            if (event.type == Gdk.EventType.2BUTTON_PRESS && event.button == Gdk.BUTTON_PRIMARY) {
                ((Maya.Application) GLib.Application.get_default ()).window.on_modified (comp);
            } else if (event.type == Gdk.EventType.BUTTON_PRESS && event.button == Gdk.BUTTON_SECONDARY) {
                E.Source src = comp.get_data ("source");

                bool sensitive = src.writable == true && Model.CalendarModel.get_default ().calclient_is_readonly (src) == false;

                var menu = new Maya.EventMenu (comp);
                menu.attach_to_widget (this, null);

                menu.popup_at_pointer (event);
                menu.show_all ();
            } else {
                return false;
            }

            return true;
        });

        const Gtk.TargetEntry dnd = {"text/x-io-elementary-calendar", 0, 0};
        const Gtk.TargetEntry dnd2 = {"text/uri-list", 0, 1};
        const Gtk.TargetEntry dnd3 = {"text/calendar", 0, 2};
        Gtk.drag_source_set (event_box, Gdk.ModifierType.BUTTON1_MASK, {dnd, dnd2, dnd3}, Gdk.DragAction.MOVE);

        event_box.drag_data_get.connect ( (ctx, sel, info, time) => {
            if (info == 0) {
              var comp_id = comp.get_id ();
              if (comp_id.rid != null) {
                var data = "%s\n%s".printf (comp_id.uid, comp_id.rid);
                sel.set (Gdk.Atom.intern_static_string ("text/x-io-elementary-calendar"), (int)sizeof(char), data.data);
              } else {
                sel.set (Gdk.Atom.intern_static_string ("text/x-io-elementary-calendar"), (int)sizeof(char), comp_id.uid.data);
              }
            } else if (info == 1) {
              comp.commit_sequence ();
              var ical_str = comp.get_as_string ();
              try {
                  var path = GLib.Path.build_filename (GLib.Environment.get_tmp_dir (), comp.get_summary ().value + ".ics");
                  var file = File.new_for_path (path);
                  if (file.replace_contents (ical_str.data, null, false, FileCreateFlags.PRIVATE, null))
                      sel.set_uris ({file.get_uri ()});
              } catch (Error e) {
                  critical (e.message);
              }
            } else if (info == 2) {
              comp.commit_sequence ();
              var ical_str = comp.get_as_string ();
              sel.set_text (ical_str, ical_str.length);
            }
        });

        E.Source source = comp.get_data ("source");

        var cal = (E.SourceCalendar)source.get_extension (E.SOURCE_EXTENSION_CALENDAR);

        reload_css (cal.dup_color ());

        cal.notify["color"].connect (() => {
            reload_css (cal.dup_color ());
        });
    }

    public void update (ECal.Component event) {
       this.comp = comp;
       label.label = comp.get_summary ().get_value ();
    }

    private void reload_css (string background_color) {
        var provider = new Gtk.CssProvider ();
        try {
            var colored_css = EVENT_CSS.printf (background_color);
            provider.load_from_data (colored_css, colored_css.length);

            grid_style_context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        } catch (GLib.Error e) {
            critical (e.message);
        }
    }
}
