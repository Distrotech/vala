/* json-glib-1.0.vapi generated by vapigen, do not modify. */

[CCode (cprefix = "Json", gir_namespace = "Json", gir_version = "1.0", lower_case_cprefix = "json_")]
namespace Json {
	[CCode (cheader_filename = "json-glib/json-glib.h", ref_function = "json_array_ref", type_id = "json_array_get_type ()", unref_function = "json_array_unref")]
	[Compact]
	public class Array {
		[CCode (has_construct_function = false)]
		public Array ();
		[Version (since = "0.8")]
		public void add_array_element (owned Json.Array? value);
		[Version (since = "0.8")]
		public void add_boolean_element (bool value);
		[Version (since = "0.8")]
		public void add_double_element (double value);
		public void add_element (owned Json.Node node);
		[Version (since = "0.8")]
		public void add_int_element (int64 value);
		[Version (since = "0.8")]
		public void add_null_element ();
		[Version (since = "0.8")]
		public void add_object_element (owned Json.Object value);
		[Version (since = "0.8")]
		public void add_string_element (string value);
		[Version (since = "0.6")]
		public Json.Node dup_element (uint index_);
		[Version (since = "0.8")]
		public void foreach_element (Json.ArrayForeach func);
		[Version (since = "0.8")]
		public unowned Json.Array get_array_element (uint index_);
		[Version (since = "0.8")]
		public bool get_boolean_element (uint index_);
		[Version (since = "0.8")]
		public double get_double_element (uint index_);
		public unowned Json.Node get_element (uint index_);
		public GLib.List<weak Json.Node> get_elements ();
		[Version (since = "0.8")]
		public int64 get_int_element (uint index_);
		public uint get_length ();
		[Version (since = "0.8")]
		public bool get_null_element (uint index_);
		[Version (since = "0.8")]
		public unowned Json.Object get_object_element (uint index_);
		[Version (since = "0.8")]
		public unowned string get_string_element (uint index_);
		public unowned Json.Array @ref ();
		public void remove_element (uint index_);
		[CCode (cname = "json_array_sized_new", has_construct_function = false)]
		public Array.sized (uint n_elements);
		public void unref ();
	}
	[CCode (cheader_filename = "json-glib/json-glib.h", type_id = "json_builder_get_type ()")]
	[Version (since = "0.12")]
	public class Builder : GLib.Object {
		[CCode (has_construct_function = false)]
		public Builder ();
		public unowned Json.Builder add_boolean_value (bool value);
		public unowned Json.Builder add_double_value (double value);
		public unowned Json.Builder add_int_value (int64 value);
		public unowned Json.Builder add_null_value ();
		public unowned Json.Builder add_string_value (string value);
		public unowned Json.Builder add_value (Json.Node node);
		public unowned Json.Builder begin_array ();
		public unowned Json.Builder begin_object ();
		public unowned Json.Builder end_array ();
		public unowned Json.Builder end_object ();
		public Json.Node? get_root ();
		public void reset ();
		public unowned Json.Builder set_member_name (string member_name);
	}
	[CCode (cheader_filename = "json-glib/json-glib.h", type_id = "json_generator_get_type ()")]
	public class Generator : GLib.Object {
		[CCode (has_construct_function = false)]
		public Generator ();
		[Version (since = "0.14")]
		public uint get_indent ();
		[Version (since = "0.14")]
		public unichar get_indent_char ();
		[Version (since = "0.14")]
		public bool get_pretty ();
		[Version (since = "0.14")]
		public unowned Json.Node? get_root ();
		[Version (since = "0.14")]
		public void set_indent (uint indent_level);
		[Version (since = "0.14")]
		public void set_indent_char (unichar indent_char);
		[Version (since = "0.14")]
		public void set_pretty (bool is_pretty);
		public void set_root (Json.Node node);
		public string to_data (out size_t length);
		public bool to_file (string filename) throws GLib.Error;
		[Version (since = "0.12")]
		public bool to_stream (GLib.OutputStream stream, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public uint indent { get; set; }
		[Version (since = "0.6")]
		public uint indent_char { get; set; }
		public bool pretty { get; set; }
		[Version (since = "0.4")]
		public Json.Node root { get; set; }
	}
	[CCode (cheader_filename = "json-glib/json-glib.h", copy_function = "g_boxed_copy", free_function = "g_boxed_free", type_id = "json_node_get_type ()")]
	[Compact]
	public class Node {
		[CCode (has_construct_function = false)]
		public Node (Json.NodeType type);
		[CCode (cname = "json_node_alloc", has_construct_function = false)]
		[Version (since = "0.16")]
		public Node.alloc ();
		public Json.Node copy ();
		public Json.Array dup_array ();
		public Json.Object dup_object ();
		public string dup_string ();
		public void free ();
		public unowned Json.Array get_array ();
		public bool get_boolean ();
		public double get_double ();
		public int64 get_int ();
		[Version (since = "0.8")]
		public Json.NodeType get_node_type ();
		public unowned Json.Object get_object ();
		public unowned Json.Node get_parent ();
		public unowned string get_string ();
		public GLib.Value get_value ();
		[Version (since = "0.4")]
		public GLib.Type get_value_type ();
		[Version (since = "0.16")]
		public unowned Json.Node init (Json.NodeType type);
		[Version (since = "0.16")]
		public unowned Json.Node init_array (Json.Array? array);
		[Version (since = "0.16")]
		public unowned Json.Node init_boolean (bool value);
		[Version (since = "0.16")]
		public unowned Json.Node init_double (double value);
		[Version (since = "0.16")]
		public unowned Json.Node init_int (int64 value);
		[Version (since = "0.16")]
		public unowned Json.Node init_null ();
		[Version (since = "0.16")]
		public unowned Json.Node init_object (Json.Object? object);
		[Version (since = "0.16")]
		public unowned Json.Node init_string (string? value);
		[Version (since = "0.8")]
		public bool is_null ();
		public void set_array (Json.Array array);
		public void set_boolean (bool value);
		public void set_double (double value);
		public void set_int (int64 value);
		public void set_object (Json.Object object);
		[Version (since = "0.8")]
		public void set_parent (Json.Node parent);
		public void set_string (string value);
		public void set_value (GLib.Value value);
		public void take_array (owned Json.Array array);
		public void take_object (owned Json.Object object);
		public unowned string type_name ();
	}
	[CCode (cheader_filename = "json-glib/json-glib.h", ref_function = "json_object_ref", type_id = "json_object_get_type ()", unref_function = "json_object_unref")]
	[Compact]
	public class Object {
		[CCode (has_construct_function = false)]
		public Object ();
		[Version (deprecated = true, deprecated_since = "0.8", replacement = "Json.Object.set_member")]
		public void add_member (string member_name, owned Json.Node node);
		[Version (since = "0.6")]
		public Json.Node dup_member (string member_name);
		[Version (since = "0.8")]
		public void foreach_member (Json.ObjectForeach func);
		[Version (since = "0.8")]
		public unowned Json.Array get_array_member (string member_name);
		[Version (since = "0.8")]
		public bool get_boolean_member (string member_name);
		[Version (since = "0.8")]
		public double get_double_member (string member_name);
		[Version (since = "0.8")]
		public int64 get_int_member (string member_name);
		public unowned Json.Node get_member (string member_name);
		public GLib.List<weak string> get_members ();
		[Version (since = "0.8")]
		public bool get_null_member (string member_name);
		[Version (since = "0.8")]
		public unowned Json.Object get_object_member (string member_name);
		public uint get_size ();
		[Version (since = "0.8")]
		public unowned string get_string_member (string member_name);
		public GLib.List<weak Json.Node> get_values ();
		public bool has_member (string member_name);
		public unowned Json.Object @ref ();
		public void remove_member (string member_name);
		[Version (since = "0.8")]
		public void set_array_member (string member_name, owned Json.Array value);
		[Version (since = "0.8")]
		public void set_boolean_member (string member_name, bool value);
		[Version (since = "0.8")]
		public void set_double_member (string member_name, double value);
		[Version (since = "0.8")]
		public void set_int_member (string member_name, int64 value);
		[Version (since = "0.8")]
		public void set_member (string member_name, owned Json.Node node);
		[Version (since = "0.8")]
		public void set_null_member (string member_name);
		[Version (since = "0.8")]
		public void set_object_member (string member_name, owned Json.Object value);
		[Version (since = "0.8")]
		public void set_string_member (string member_name, string value);
		public void unref ();
	}
	[CCode (cheader_filename = "json-glib/json-glib.h", type_id = "json_parser_get_type ()")]
	public class Parser : GLib.Object {
		[CCode (has_construct_function = false)]
		public Parser ();
		public uint get_current_line ();
		public uint get_current_pos ();
		public unowned Json.Node? get_root ();
		[Version (since = "0.4")]
		public bool has_assignment (out unowned string variable_name);
		public bool load_from_data (string data, ssize_t length = -1) throws GLib.Error;
		public bool load_from_file (string filename) throws GLib.Error;
		[Version (since = "0.12")]
		public bool load_from_stream (GLib.InputStream stream, GLib.Cancellable? cancellable = null) throws GLib.Error;
		[Version (since = "0.12")]
		public async bool load_from_stream_async (GLib.InputStream stream, GLib.Cancellable? cancellable = null) throws GLib.Error;
		public virtual signal void array_element (Json.Array array, int index_);
		public virtual signal void array_end (Json.Array array);
		public virtual signal void array_start ();
		public virtual signal void error (void* error);
		public virtual signal void object_end (Json.Object object);
		public virtual signal void object_member (Json.Object object, string member_name);
		public virtual signal void object_start ();
		public virtual signal void parse_end ();
		public virtual signal void parse_start ();
	}
	[CCode (cheader_filename = "json-glib/json-glib.h", type_id = "json_path_get_type ()")]
	[Version (since = "0.14")]
	public class Path : GLib.Object {
		[CCode (has_construct_function = false)]
		public Path ();
		public bool compile (string expression) throws GLib.Error;
		public Json.Node match (Json.Node root);
		public static Json.Node query (string expression, Json.Node root) throws GLib.Error;
	}
	[CCode (cheader_filename = "json-glib/json-glib.h", type_id = "json_reader_get_type ()")]
	[Version (since = "0.12")]
	public class Reader : GLib.Object {
		[CCode (has_construct_function = false)]
		public Reader (Json.Node? node);
		public int count_elements ();
		public int count_members ();
		public void end_element ();
		public void end_member ();
		public bool get_boolean_value ();
		public double get_double_value ();
		public unowned GLib.Error get_error ();
		public int64 get_int_value ();
		[Version (since = "0.14")]
		public unowned string get_member_name ();
		public bool get_null_value ();
		public unowned string get_string_value ();
		public unowned Json.Node get_value ();
		public bool is_array ();
		public bool is_object ();
		public bool is_value ();
		[CCode (array_length = false, array_null_terminated = true)]
		[Version (since = "0.14")]
		public string[] list_members ();
		public bool read_element (uint index_);
		public bool read_member (string member_name);
		public void set_root (Json.Node? root);
		[NoAccessorMethod]
		public Json.Node root { owned get; set construct; }
	}
	[CCode (cheader_filename = "json-glib/json-glib.h,json-glib/json-gobject.h", type_id = "json_serializable_get_type ()")]
	public interface Serializable : GLib.Object {
		[Version (since = "0.10")]
		public bool default_deserialize_property (string property_name, GLib.Value value, GLib.ParamSpec pspec, Json.Node property_node);
		[Version (since = "0.10")]
		public Json.Node default_serialize_property (string property_name, GLib.Value value, GLib.ParamSpec pspec);
		public abstract bool deserialize_property (string property_name, out GLib.Value value, GLib.ParamSpec pspec, Json.Node property_node);
		[Version (since = "0.14")]
		public abstract unowned GLib.ParamSpec find_property (string name);
		public abstract void get_property (GLib.ParamSpec pspec, GLib.Value value);
		[CCode (array_length_pos = 0.1, array_length_type = "guint")]
		[Version (since = "0.14")]
		public GLib.ParamSpec[] list_properties ();
		public abstract Json.Node serialize_property (string property_name, GLib.Value value, GLib.ParamSpec pspec);
		public abstract void set_property (GLib.ParamSpec pspec, GLib.Value value);
	}
	[CCode (cheader_filename = "json-glib/json-glib.h", cprefix = "JSON_NODE_", type_id = "json_node_type_get_type ()")]
	public enum NodeType {
		OBJECT,
		ARRAY,
		VALUE,
		NULL
	}
	[CCode (cheader_filename = "json-glib/json-glib.h", cprefix = "JSON_PARSER_ERROR_")]
	public errordomain ParserError {
		PARSE,
		TRAILING_COMMA,
		MISSING_COMMA,
		MISSING_COLON,
		INVALID_BAREWORD,
		EMPTY_MEMBER_NAME,
		INVALID_DATA,
		UNKNOWN;
		public static GLib.Quark quark ();
	}
	[CCode (cheader_filename = "json-glib/json-glib.h", cprefix = "JSON_PATH_ERROR_INVALID_")]
	[Version (since = "0.14")]
	public errordomain PathError {
		QUERY;
		public static GLib.Quark quark ();
	}
	[CCode (cheader_filename = "json-glib/json-glib.h", cprefix = "JSON_READER_ERROR_")]
	[Version (since = "0.12")]
	public errordomain ReaderError {
		NO_ARRAY,
		INVALID_INDEX,
		NO_OBJECT,
		INVALID_MEMBER,
		INVALID_NODE,
		NO_VALUE,
		INVALID_TYPE;
		public static GLib.Quark quark ();
	}
	[CCode (cheader_filename = "json-glib/json-glib.h", instance_pos = 3.9)]
	[Version (since = "0.8")]
	public delegate void ArrayForeach (Json.Array array, uint index_, Json.Node element_node);
	[CCode (cheader_filename = "json-glib/json-glib.h", has_target = false)]
	[Version (since = "0.10")]
	public delegate void* BoxedDeserializeFunc (Json.Node node);
	[CCode (cheader_filename = "json-glib/json-glib.h", has_target = false)]
	[Version (since = "0.10")]
	public delegate Json.Node BoxedSerializeFunc (void* boxed);
	[CCode (cheader_filename = "json-glib/json-glib.h", instance_pos = 3.9)]
	[Version (since = "0.8")]
	public delegate void ObjectForeach (Json.Object object, string member_name, Json.Node member_node);
	[CCode (cheader_filename = "json-glib/json-glib.h", cname = "JSON_MAJOR_VERSION")]
	public const int MAJOR_VERSION;
	[CCode (cheader_filename = "json-glib/json-glib.h", cname = "JSON_MICRO_VERSION")]
	public const int MICRO_VERSION;
	[CCode (cheader_filename = "json-glib/json-glib.h", cname = "JSON_MINOR_VERSION")]
	public const int MINOR_VERSION;
	[CCode (cheader_filename = "json-glib/json-glib.h")]
	public const int VERSION_HEX;
	[CCode (cheader_filename = "json-glib/json-glib.h", cname = "JSON_VERSION_S")]
	public const string VERSION_S;
	[CCode (cheader_filename = "json-glib/json-glib.h")]
	[Version (since = "0.10")]
	public static bool boxed_can_deserialize (GLib.Type gboxed_type, Json.NodeType node_type);
	[CCode (cheader_filename = "json-glib/json-glib.h")]
	[Version (since = "0.10")]
	public static bool boxed_can_serialize (GLib.Type gboxed_type, out Json.NodeType node_type);
	[CCode (cheader_filename = "json-glib/json-glib.h")]
	[Version (since = "0.10")]
	public static void* boxed_deserialize (GLib.Type gboxed_type, Json.Node node);
	[CCode (cheader_filename = "json-glib/json-glib.h")]
	[Version (since = "0.10")]
	public static void boxed_register_deserialize_func (GLib.Type gboxed_type, Json.NodeType node_type, Json.BoxedDeserializeFunc deserialize_func);
	[CCode (cheader_filename = "json-glib/json-glib.h")]
	[Version (since = "0.10")]
	public static void boxed_register_serialize_func (GLib.Type gboxed_type, Json.NodeType node_type, Json.BoxedSerializeFunc serialize_func);
	[CCode (cheader_filename = "json-glib/json-glib.h")]
	[Version (since = "0.10")]
	public static Json.Node boxed_serialize (GLib.Type gboxed_type, void* boxed);
	[CCode (cheader_filename = "json-glib/json-glib.h,json-glib/json-gobject.h")]
	[Version (deprecated = true, deprecated_since = "0.10", replacement = "Json.gobject_from_data", since = "0.4")]
	public static GLib.Object construct_gobject (GLib.Type gtype, string data, size_t length) throws GLib.Error;
	[CCode (cheader_filename = "json-glib/json-glib.h")]
	[Version (since = "0.10")]
	public static GLib.Object gobject_deserialize (GLib.Type gtype, Json.Node node);
	[CCode (cheader_filename = "json-glib/json-glib.h")]
	[Version (since = "0.10")]
	public static GLib.Object gobject_from_data (GLib.Type gtype, string data, ssize_t length = -1) throws GLib.Error;
	[CCode (cheader_filename = "json-glib/json-glib.h")]
	[Version (since = "0.10")]
	public static Json.Node gobject_serialize (GLib.Object gobject);
	[CCode (cheader_filename = "json-glib/json-glib.h")]
	[Version (since = "0.10")]
	public static string gobject_to_data (GLib.Object gobject, out size_t length);
	[CCode (cheader_filename = "json-glib/json-glib.h", returns_floating_reference = true)]
	[Version (since = "0.14")]
	public static GLib.Variant gvariant_deserialize (Json.Node json_node, string? signature) throws GLib.Error;
	[CCode (cheader_filename = "json-glib/json-glib.h", returns_floating_reference = true)]
	[Version (since = "0.14")]
	public static GLib.Variant gvariant_deserialize_data (string json, ssize_t length, string? signature) throws GLib.Error;
	[CCode (cheader_filename = "json-glib/json-glib.h")]
	[Version (since = "0.14")]
	public static Json.Node gvariant_serialize (GLib.Variant variant);
	[CCode (cheader_filename = "json-glib/json-glib.h")]
	[Version (since = "0.14")]
	public static string gvariant_serialize_data (GLib.Variant variant, out size_t length);
	[CCode (cheader_filename = "json-glib/json-glib.h,json-glib/json-gobject.h")]
	[Version (deprecated = true, deprecated_since = "0.10", replacement = "Json.gobject_to_data")]
	public static string serialize_gobject (GLib.Object gobject, out size_t length);
}
