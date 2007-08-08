[CCode (cprefix = "Gtk", lower_case_cprefix = "gtk_")]
namespace Gtk {
	[CCode (cprefix = "GTK_SOURCE_SEARCH_", cheader_filename = "gtksourceview/gtksourceiter.h")]
	public enum SourceSearchFlags {
		VISIBLE_ONLY,
		TEXT_ONLY,
		CASE_INSENSITIVE,
	}
	[CCode (cprefix = "GTK_SOURCE_SMART_HOME_END_", cheader_filename = "gtksourceview/gtksourceview.h")]
	public enum SourceSmartHomeEndType {
		DISABLED,
		BEFORE,
		AFTER,
		ALWAYS,
	}
	[CCode (cheader_filename = "gtksourceview/gtksourcebuffer.h")]
	public class SourceBuffer : Gtk.TextBuffer {
		public void begin_not_undoable_action ();
		public weak Gtk.SourceMarker create_marker (string name, string type, out Gtk.TextIter where);
		public void delete_marker (Gtk.SourceMarker marker);
		public void end_not_undoable_action ();
		public bool get_check_brackets ();
		public weak Gtk.SourceMarker get_first_marker ();
		public bool get_highlight ();
		public void get_iter_at_marker (out Gtk.TextIter iter, Gtk.SourceMarker marker);
		public weak Gtk.SourceLanguage get_language ();
		public weak Gtk.SourceMarker get_last_marker ();
		public weak Gtk.SourceMarker get_marker (string name);
		public weak GLib.SList get_markers_in_region (out Gtk.TextIter begin, out Gtk.TextIter end);
		public int get_max_undo_levels ();
		public weak Gtk.SourceMarker get_next_marker (out Gtk.TextIter iter);
		public weak Gtk.SourceMarker get_prev_marker (out Gtk.TextIter iter);
		public weak Gtk.SourceStyleScheme get_style_scheme ();
		public static GLib.Type get_type ();
		public void move_marker (Gtk.SourceMarker marker, out Gtk.TextIter where);
		public SourceBuffer (Gtk.TextTagTable table);
		public SourceBuffer.with_language (Gtk.SourceLanguage language);
		public void redo ();
		public void set_check_brackets (bool check_brackets);
		public void set_highlight (bool highlight);
		public void set_language (Gtk.SourceLanguage language);
		public void set_max_undo_levels (int max_undo_levels);
		public void set_style_scheme (Gtk.SourceStyleScheme scheme);
		public void undo ();
		public weak bool check_brackets { get; set; }
		public weak bool highlight { get; set; }
		public weak int max_undo_levels { get; set; }
		public weak Gtk.SourceLanguage language { get; set; }
		[NoAccessorMethod]
		public weak bool can_undo { get; }
		[NoAccessorMethod]
		public weak bool can_redo { get; }
		public weak Gtk.SourceStyleScheme style_scheme { get; set; }
	}
	[CCode (cheader_filename = "gtksourceview/gtksourcelanguage.h")]
	public class SourceLanguage : GLib.Object {
		public weak string get_globs ();
		public weak string get_id ();
		public weak string get_metadata (string name);
		public weak string get_mime_types ();
		public weak string get_name ();
		public weak string get_section ();
		public static GLib.Type get_type ();
	}
	[CCode (cheader_filename = "gtksourceview/gtksourcelanguagemanager.h")]
	public class SourceLanguageManager : GLib.Object {
		public static weak Gtk.SourceLanguageManager get_default ();
		public weak Gtk.SourceLanguage get_language_by_id (string id);
		public weak string get_search_path ();
		public static GLib.Type get_type ();
		public weak GLib.SList list_languages ();
		public SourceLanguageManager ();
		public void set_search_path (string dirs);
		public weak string[] search_path { get; set; }
	}
	[CCode (cheader_filename = "gtksourceview/gtksourcemarker.h")]
	public class SourceMarker : GLib.Object {
		public pointer get_buffer ();
		public int get_line ();
		public weak string get_marker_type ();
		public weak string get_name ();
		public static GLib.Type get_type ();
		public weak Gtk.SourceMarker next ();
		public weak Gtk.SourceMarker prev ();
		public void set_marker_type (string type);
	}
	[CCode (cheader_filename = "gtksourceview/gtksourcestyle.h")]
	public class SourceStyle : GLib.Object {
		public weak Gtk.SourceStyle copy ();
		public static GLib.Type get_type ();
		[NoAccessorMethod]
		public weak string background { get; construct; }
		[NoAccessorMethod]
		public weak string foreground { get; construct; }
		[NoAccessorMethod]
		public weak bool bold { get; construct; }
		[NoAccessorMethod]
		public weak bool italic { get; construct; }
		[NoAccessorMethod]
		public weak bool underline { get; construct; }
		[NoAccessorMethod]
		public weak bool strikethrough { get; construct; }
		[NoAccessorMethod]
		public weak bool foreground_set { get; construct; }
		[NoAccessorMethod]
		public weak bool background_set { get; construct; }
		[NoAccessorMethod]
		public weak bool bold_set { get; construct; }
		[NoAccessorMethod]
		public weak bool italic_set { get; construct; }
		[NoAccessorMethod]
		public weak bool underline_set { get; construct; }
		[NoAccessorMethod]
		public weak bool strikethrough_set { get; construct; }
	}
	[CCode (cheader_filename = "gtksourceview/gtksourcestylemanager.h")]
	public class SourceStyleManager : GLib.Object {
		public bool add_scheme (string filename);
		public static weak Gtk.SourceStyleManager get_default ();
		public weak Gtk.SourceStyleScheme get_scheme (string scheme_id);
		public weak string get_search_path ();
		public static GLib.Type get_type ();
		public weak GLib.SList list_schemes ();
		public SourceStyleManager ();
		public void set_search_path (string path);
		public weak string[] search_path { get; set; }
		public signal void changed ();
	}
	[CCode (cheader_filename = "gtksourceview/gtksourcestylescheme.h")]
	public class SourceStyleScheme : GLib.Object {
		public bool get_current_line_color (Gdk.Color color);
		public weak string get_id ();
		public weak Gtk.SourceStyle get_matching_brackets_style ();
		public weak string get_name ();
		public weak Gtk.SourceStyle get_style (string style_name);
		public static GLib.Type get_type ();
		[NoAccessorMethod]
		public weak string id { get; construct; }
		[NoAccessorMethod]
		public weak string name { get; set; }
	}
	[CCode (cheader_filename = "gtksourceview/gtksourceview.h")]
	public class SourceView : Gtk.TextView {
		public bool get_auto_indent ();
		public bool get_highlight_current_line ();
		public bool get_indent_on_tab ();
		public bool get_insert_spaces_instead_of_tabs ();
		public uint get_margin ();
		public weak Gdk.Pixbuf get_marker_pixbuf (string marker_type);
		public bool get_show_line_markers ();
		public bool get_show_line_numbers ();
		public bool get_show_margin ();
		public Gtk.SourceSmartHomeEndType get_smart_home_end ();
		public uint get_tabs_width ();
		public static GLib.Type get_type ();
		public SourceView ();
		public SourceView.with_buffer (Gtk.SourceBuffer buffer);
		public void set_auto_indent (bool enable);
		public void set_highlight_current_line (bool show);
		public void set_indent_on_tab (bool enable);
		public void set_insert_spaces_instead_of_tabs (bool enable);
		public void set_margin (uint margin);
		public void set_marker_pixbuf (string marker_type, Gdk.Pixbuf pixbuf);
		public void set_show_line_markers (bool show);
		public void set_show_line_numbers (bool show);
		public void set_show_margin (bool show);
		public void set_smart_home_end (Gtk.SourceSmartHomeEndType smart_he);
		public void set_tabs_width (uint width);
		public weak bool show_line_numbers { get; set; }
		public weak bool show_line_markers { get; set; }
		public weak uint tabs_width { get; set; }
		public weak bool auto_indent { get; set; }
		public weak bool insert_spaces_instead_of_tabs { get; set; }
		public weak bool show_margin { get; set; }
		public weak uint margin { get; set; }
		public weak Gtk.SourceSmartHomeEndType smart_home_end { get; set; }
		public weak bool highlight_current_line { get; set; }
		public weak bool indent_on_tab { get; set; }
		public signal void undo ();
		public signal void redo ();
	}
}
