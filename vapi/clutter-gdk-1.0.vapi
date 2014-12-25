/* clutter-gdk-1.0.vapi generated by vapigen, do not modify. */

[CCode (cprefix = "ClutterGdk", gir_namespace = "ClutterGdk", gir_version = "1.0", lower_case_cprefix = "clutter_gdk_")]
namespace ClutterGdk {
	[CCode (cheader_filename = "clutter/gdk/clutter-gdk.h")]
	[Version (since = "1.10")]
	public static void disable_event_retrieval ();
	[CCode (cheader_filename = "clutter/gdk/clutter-gdk.h")]
	[Version (since = "0.6")]
	public static unowned Gdk.Display get_default_display ();
	[CCode (cheader_filename = "clutter/gdk/clutter-gdk.h")]
	[Version (since = "1.10")]
	public static unowned Clutter.Stage get_stage_from_window (Gdk.Window window);
	[CCode (cheader_filename = "clutter/gdk/clutter-gdk.h")]
	[Version (since = "1.10")]
	public static unowned Gdk.Window get_stage_window (Clutter.Stage stage);
	[CCode (cheader_filename = "clutter/gdk/clutter-gdk.h")]
	public static Gdk.FilterReturn handle_event (Gdk.Event event);
	[CCode (cheader_filename = "clutter/gdk/clutter-gdk.h")]
	[Version (since = "0.8")]
	public static void set_display (Gdk.Display display);
	[CCode (cheader_filename = "clutter/gdk/clutter-gdk.h")]
	[Version (since = "1.10")]
	public static bool set_stage_foreign (Clutter.Stage stage, Gdk.Window window);
}
