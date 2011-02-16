/* valaccodebasemodule.vala
 *
 * Copyright (C) 2006-2011  Jürg Billeter
 * Copyright (C) 2006-2008  Raffaele Sandrini
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 * 	Jürg Billeter <j@bitron.ch>
 * 	Raffaele Sandrini <raffaele@sandrini.ch>
 */


/**
 * Code visitor generating C Code.
 */
public abstract class Vala.CCodeBaseModule : CodeGenerator {
	public class EmitContext {
		public Symbol? current_symbol;
		public ArrayList<Symbol> symbol_stack = new ArrayList<Symbol> ();
		public TryStatement current_try;
		public CatchClause current_catch;
		public CCodeFunction ccode;
		public ArrayList<CCodeFunction> ccode_stack = new ArrayList<CCodeFunction> ();
		public ArrayList<LocalVariable> temp_ref_vars = new ArrayList<LocalVariable> ();
		public int next_temp_var_id;
		public bool current_method_inner_error;
		public bool current_method_return;
		public Map<string,string> variable_name_map = new HashMap<string,string> (str_hash, str_equal);

		public EmitContext (Symbol? symbol = null) {
			current_symbol = symbol;
		}

		public void push_symbol (Symbol symbol) {
			symbol_stack.add (current_symbol);
			current_symbol = symbol;
		}

		public void pop_symbol () {
			current_symbol = symbol_stack[symbol_stack.size - 1];
			symbol_stack.remove_at (symbol_stack.size - 1);
		}
	}

	public CodeContext context { get; set; }

	public Symbol root_symbol;

	public EmitContext emit_context = new EmitContext ();

	List<EmitContext> emit_context_stack = new ArrayList<EmitContext> ();

	public Symbol current_symbol { get { return emit_context.current_symbol; } }

	public TryStatement current_try {
		get { return emit_context.current_try; }
		set { emit_context.current_try = value; }
	}

	public CatchClause current_catch {
		get { return emit_context.current_catch; }
		set { emit_context.current_catch = value; }
	}

	public TypeSymbol? current_type_symbol {
		get {
			var sym = current_symbol;
			while (sym != null) {
				if (sym is TypeSymbol) {
					return (TypeSymbol) sym;
				}
				sym = sym.parent_symbol;
			}
			return null;
		}
	}

	public Class? current_class {
		get { return current_type_symbol as Class; }
	}

	public Method? current_method {
		get {
			var sym = current_symbol;
			while (sym is Block) {
				sym = sym.parent_symbol;
			}
			return sym as Method;
		}
	}

	public PropertyAccessor? current_property_accessor {
		get {
			var sym = current_symbol;
			while (sym is Block) {
				sym = sym.parent_symbol;
			}
			return sym as PropertyAccessor;
		}
	}

	public DataType? current_return_type {
		get {
			var m = current_method;
			if (m != null) {
				return m.return_type;
			}

			var acc = current_property_accessor;
			if (acc != null) {
				if (acc.readable) {
					return acc.value_type;
				} else {
					return void_type;
				}
			}

			if (is_in_constructor () || is_in_destructor ()) {
				return void_type;
			}

			return null;
		}
	}

	public bool is_in_coroutine () {
		return current_method != null && current_method.coroutine;
	}

	public bool is_in_constructor () {
		if (current_method != null) {
			// make sure to not return true in lambda expression inside constructor
			return false;
		}
		var sym = current_symbol;
		while (sym != null) {
			if (sym is Constructor) {
				return true;
			}
			sym = sym.parent_symbol;
		}
		return false;
	}

	public bool is_in_destructor () {
		if (current_method != null) {
			// make sure to not return true in lambda expression inside constructor
			return false;
		}
		var sym = current_symbol;
		while (sym != null) {
			if (sym is Destructor) {
				return true;
			}
			sym = sym.parent_symbol;
		}
		return false;
	}

	public Block? current_closure_block {
		get {
			return next_closure_block (current_symbol);
		}
	}

	public unowned Block? next_closure_block (Symbol sym) {
		unowned Block block = null;
		while (true) {
			block = sym as Block;
			if (!(sym is Block || sym is Method)) {
				// no closure block
				break;
			}
			if (block != null && block.captured) {
				// closure block found
				break;
			}
			sym = sym.parent_symbol;
		}
		return block;
	}

	public CCodeFile header_file;
	public CCodeFile internal_header_file;
	public CCodeFile cfile;

	public EmitContext class_init_context;
	public EmitContext base_init_context;
	public EmitContext class_finalize_context;
	public EmitContext base_finalize_context;
	public EmitContext instance_init_context;
	public EmitContext instance_finalize_context;
	
	public CCodeStruct param_spec_struct;
	public CCodeStruct closure_struct;
	public CCodeEnum prop_enum;

	public CCodeFunction ccode { get { return emit_context.ccode; } }

	/* temporary variables that own their content */
	public ArrayList<LocalVariable> temp_ref_vars { get { return emit_context.temp_ref_vars; } }
	/* cache to check whether a certain marshaller has been created yet */
	public Set<string> user_marshal_set;
	/* (constant) hash table with all predefined marshallers */
	public Set<string> predefined_marshal_set;
	/* (constant) hash table with all reserved identifiers in the generated code */
	Set<string> reserved_identifiers;
	
	public int next_temp_var_id {
		get { return emit_context.next_temp_var_id; }
		set { emit_context.next_temp_var_id = value; }
	}

	public int next_regex_id = 0;
	public bool in_creation_method { get { return current_method is CreationMethod; } }
	public bool in_constructor = false;
	public bool in_static_or_class_context = false;

	public bool current_method_inner_error {
		get { return emit_context.current_method_inner_error; }
		set { emit_context.current_method_inner_error = value; }
	}

	public bool current_method_return {
		get { return emit_context.current_method_return; }
		set { emit_context.current_method_return = value; }
	}

	public int next_coroutine_state = 1;
	int next_block_id = 0;
	Map<Block,int> block_map = new HashMap<Block,int> ();

	public DataType void_type = new VoidType ();
	public DataType bool_type;
	public DataType char_type;
	public DataType uchar_type;
	public DataType? unichar_type;
	public DataType short_type;
	public DataType ushort_type;
	public DataType int_type;
	public DataType uint_type;
	public DataType long_type;
	public DataType ulong_type;
	public DataType int8_type;
	public DataType uint8_type;
	public DataType int16_type;
	public DataType uint16_type;
	public DataType int32_type;
	public DataType uint32_type;
	public DataType int64_type;
	public DataType uint64_type;
	public DataType string_type;
	public DataType regex_type;
	public DataType float_type;
	public DataType double_type;
	public TypeSymbol gtype_type;
	public TypeSymbol gobject_type;
	public ErrorType gerror_type;
	public Class glist_type;
	public Class gslist_type;
	public Class gnode_type;
	public Class gvaluearray_type;
	public TypeSymbol gstringbuilder_type;
	public TypeSymbol garray_type;
	public TypeSymbol gbytearray_type;
	public TypeSymbol gptrarray_type;
	public TypeSymbol gthreadpool_type;
	public DataType gdestroynotify_type;
	public DataType gquark_type;
	public Struct gvalue_type;
	public Class gvariant_type;
	public Struct mutex_type;
	public TypeSymbol type_module_type;
	public TypeSymbol dbus_proxy_type;
	public TypeSymbol dbus_object_type;

	public bool in_plugin = false;
	public string module_init_param_name;
	
	public bool gvaluecollector_h_needed;
	public bool requires_array_free;
	public bool requires_array_move;
	public bool requires_array_length;

	public Set<string> wrappers;
	Set<Symbol> generated_external_symbols;

	public Map<string,string> variable_name_map { get { return emit_context.variable_name_map; } }

	public CCodeBaseModule () {
		predefined_marshal_set = new HashSet<string> (str_hash, str_equal);
		predefined_marshal_set.add ("VOID:VOID");
		predefined_marshal_set.add ("VOID:BOOLEAN");
		predefined_marshal_set.add ("VOID:CHAR");
		predefined_marshal_set.add ("VOID:UCHAR");
		predefined_marshal_set.add ("VOID:INT");
		predefined_marshal_set.add ("VOID:UINT");
		predefined_marshal_set.add ("VOID:LONG");
		predefined_marshal_set.add ("VOID:ULONG");
		predefined_marshal_set.add ("VOID:ENUM");
		predefined_marshal_set.add ("VOID:FLAGS");
		predefined_marshal_set.add ("VOID:FLOAT");
		predefined_marshal_set.add ("VOID:DOUBLE");
		predefined_marshal_set.add ("VOID:STRING");
		predefined_marshal_set.add ("VOID:POINTER");
		predefined_marshal_set.add ("VOID:OBJECT");
		predefined_marshal_set.add ("STRING:OBJECT,POINTER");
		predefined_marshal_set.add ("VOID:UINT,POINTER");
		predefined_marshal_set.add ("BOOLEAN:FLAGS");

		reserved_identifiers = new HashSet<string> (str_hash, str_equal);

		// C99 keywords
		reserved_identifiers.add ("_Bool");
		reserved_identifiers.add ("_Complex");
		reserved_identifiers.add ("_Imaginary");
		reserved_identifiers.add ("asm");
		reserved_identifiers.add ("auto");
		reserved_identifiers.add ("break");
		reserved_identifiers.add ("case");
		reserved_identifiers.add ("char");
		reserved_identifiers.add ("const");
		reserved_identifiers.add ("continue");
		reserved_identifiers.add ("default");
		reserved_identifiers.add ("do");
		reserved_identifiers.add ("double");
		reserved_identifiers.add ("else");
		reserved_identifiers.add ("enum");
		reserved_identifiers.add ("extern");
		reserved_identifiers.add ("float");
		reserved_identifiers.add ("for");
		reserved_identifiers.add ("goto");
		reserved_identifiers.add ("if");
		reserved_identifiers.add ("inline");
		reserved_identifiers.add ("int");
		reserved_identifiers.add ("long");
		reserved_identifiers.add ("register");
		reserved_identifiers.add ("restrict");
		reserved_identifiers.add ("return");
		reserved_identifiers.add ("short");
		reserved_identifiers.add ("signed");
		reserved_identifiers.add ("sizeof");
		reserved_identifiers.add ("static");
		reserved_identifiers.add ("struct");
		reserved_identifiers.add ("switch");
		reserved_identifiers.add ("typedef");
		reserved_identifiers.add ("union");
		reserved_identifiers.add ("unsigned");
		reserved_identifiers.add ("void");
		reserved_identifiers.add ("volatile");
		reserved_identifiers.add ("while");

		// MSVC keywords
		reserved_identifiers.add ("cdecl");

		// reserved for Vala/GObject naming conventions
		reserved_identifiers.add ("error");
		reserved_identifiers.add ("result");
		reserved_identifiers.add ("self");
	}

	public override void emit (CodeContext context) {
		this.context = context;

		root_symbol = context.root;

		bool_type = new BooleanType ((Struct) root_symbol.scope.lookup ("bool"));
		char_type = new IntegerType ((Struct) root_symbol.scope.lookup ("char"));
		uchar_type = new IntegerType ((Struct) root_symbol.scope.lookup ("uchar"));
		short_type = new IntegerType ((Struct) root_symbol.scope.lookup ("short"));
		ushort_type = new IntegerType ((Struct) root_symbol.scope.lookup ("ushort"));
		int_type = new IntegerType ((Struct) root_symbol.scope.lookup ("int"));
		uint_type = new IntegerType ((Struct) root_symbol.scope.lookup ("uint"));
		long_type = new IntegerType ((Struct) root_symbol.scope.lookup ("long"));
		ulong_type = new IntegerType ((Struct) root_symbol.scope.lookup ("ulong"));
		int8_type = new IntegerType ((Struct) root_symbol.scope.lookup ("int8"));
		uint8_type = new IntegerType ((Struct) root_symbol.scope.lookup ("uint8"));
		int16_type = new IntegerType ((Struct) root_symbol.scope.lookup ("int16"));
		uint16_type = new IntegerType ((Struct) root_symbol.scope.lookup ("uint16"));
		int32_type = new IntegerType ((Struct) root_symbol.scope.lookup ("int32"));
		uint32_type = new IntegerType ((Struct) root_symbol.scope.lookup ("uint32"));
		int64_type = new IntegerType ((Struct) root_symbol.scope.lookup ("int64"));
		uint64_type = new IntegerType ((Struct) root_symbol.scope.lookup ("uint64"));
		float_type = new FloatingType ((Struct) root_symbol.scope.lookup ("float"));
		double_type = new FloatingType ((Struct) root_symbol.scope.lookup ("double"));
		string_type = new ObjectType ((Class) root_symbol.scope.lookup ("string"));
		var unichar_struct = (Struct) root_symbol.scope.lookup ("unichar");
		if (unichar_struct != null) {
			unichar_type = new IntegerType (unichar_struct);
		}

		if (context.profile == Profile.GOBJECT) {
			var glib_ns = root_symbol.scope.lookup ("GLib");

			gtype_type = (TypeSymbol) glib_ns.scope.lookup ("Type");
			gobject_type = (TypeSymbol) glib_ns.scope.lookup ("Object");
			gerror_type = new ErrorType (null, null);
			glist_type = (Class) glib_ns.scope.lookup ("List");
			gslist_type = (Class) glib_ns.scope.lookup ("SList");
			gnode_type = (Class) glib_ns.scope.lookup ("Node");
			gvaluearray_type = (Class) glib_ns.scope.lookup ("ValueArray");
			gstringbuilder_type = (TypeSymbol) glib_ns.scope.lookup ("StringBuilder");
			garray_type = (TypeSymbol) glib_ns.scope.lookup ("Array");
			gbytearray_type = (TypeSymbol) glib_ns.scope.lookup ("ByteArray");
			gptrarray_type = (TypeSymbol) glib_ns.scope.lookup ("PtrArray");
			gthreadpool_type = (TypeSymbol) glib_ns.scope.lookup ("ThreadPool");
			gdestroynotify_type = new DelegateType ((Delegate) glib_ns.scope.lookup ("DestroyNotify"));

			gquark_type = new IntegerType ((Struct) glib_ns.scope.lookup ("Quark"));
			gvalue_type = (Struct) glib_ns.scope.lookup ("Value");
			gvariant_type = (Class) glib_ns.scope.lookup ("Variant");
			mutex_type = (Struct) glib_ns.scope.lookup ("StaticRecMutex");

			type_module_type = (TypeSymbol) glib_ns.scope.lookup ("TypeModule");

			regex_type = new ObjectType ((Class) root_symbol.scope.lookup ("GLib").scope.lookup ("Regex"));

			if (context.module_init_method != null) {
				foreach (Parameter parameter in context.module_init_method.get_parameters ()) {
					if (parameter.variable_type.data_type == type_module_type) {
						in_plugin = true;
						module_init_param_name = parameter.name;
						break;
					}
				}
				if (!in_plugin) {
					Report.error (context.module_init_method.source_reference, "[ModuleInit] requires a parameter of type `GLib.TypeModule'");
				}
			}

			dbus_proxy_type = (TypeSymbol) glib_ns.scope.lookup ("DBusProxy");

			var dbus_ns = root_symbol.scope.lookup ("DBus");
			if (dbus_ns != null) {
				dbus_object_type = (TypeSymbol) dbus_ns.scope.lookup ("Object");
			}
		}

		header_file = new CCodeFile ();
		header_file.is_header = true;
		internal_header_file = new CCodeFile ();
		internal_header_file.is_header = true;

		/* we're only interested in non-pkg source files */
		var source_files = context.get_source_files ();
		foreach (SourceFile file in source_files) {
			if (file.file_type == SourceFileType.SOURCE ||
			    (context.header_filename != null && file.file_type == SourceFileType.FAST)) {
				file.accept (this);
			}
		}

		// generate symbols file for public API
		if (context.symbols_filename != null) {
			var stream = FileStream.open (context.symbols_filename, "w");
			if (stream == null) {
				Report.error (null, "unable to open `%s' for writing".printf (context.symbols_filename));
				return;
			}

			foreach (string symbol in header_file.get_symbols ()) {
				stream.puts (symbol);
				stream.putc ('\n');
			}

			stream = null;
		}

		// generate C header file for public API
		if (context.header_filename != null) {
			bool ret;
			if (context.profile == Profile.GOBJECT) {
				ret = header_file.store (context.header_filename, null, context.version_header, false, "G_BEGIN_DECLS", "G_END_DECLS");
			} else {
				ret = header_file.store (context.header_filename, null, context.version_header, false);
			}
			if (!ret) {
				Report.error (null, "unable to open `%s' for writing".printf (context.header_filename));
			}
		}

		// generate C header file for internal API
		if (context.internal_header_filename != null) {
			bool ret;
			if (context.profile == Profile.GOBJECT) {
				ret = internal_header_file.store (context.internal_header_filename, null, context.version_header, false, "G_BEGIN_DECLS", "G_END_DECLS");
			} else {
				ret = internal_header_file.store (context.internal_header_filename, null, context.version_header, false);
			}
			if (!ret) {
				Report.error (null, "unable to open `%s' for writing".printf (context.internal_header_filename));
			}
		}
	}

	public void push_context (EmitContext emit_context) {
		if (this.emit_context != null) {
			emit_context_stack.add (this.emit_context);
		}

		this.emit_context = emit_context;
	}

	public void pop_context () {
		if (emit_context_stack.size > 0) {
			this.emit_context = emit_context_stack[emit_context_stack.size - 1];
			emit_context_stack.remove_at (emit_context_stack.size - 1);
		} else {
			this.emit_context = null;
		}
	}

	public void push_function (CCodeFunction func) {
		emit_context.ccode_stack.add (ccode);
		emit_context.ccode = func;
	}

	public void pop_function () {
		emit_context.ccode = emit_context.ccode_stack[emit_context.ccode_stack.size - 1];
		emit_context.ccode_stack.remove_at (emit_context.ccode_stack.size - 1);
	}

	public bool add_symbol_declaration (CCodeFile decl_space, Symbol sym, string name) {
		if (decl_space.add_declaration (name)) {
			return true;
		}
		if (sym.source_reference != null) {
			sym.source_reference.file.used = true;
		}
		if (sym.external_package || (!decl_space.is_header && CodeContext.get ().use_header && !sym.is_internal_symbol ())) {
			// add appropriate include file
			foreach (string header_filename in sym.get_cheader_filenames ()) {
				decl_space.add_include (header_filename, !sym.external_package);
			}
			// declaration complete
			return true;
		} else {
			// require declaration
			return false;
		}
	}

	public CCodeIdentifier get_value_setter_function (DataType type_reference) {
		var array_type = type_reference as ArrayType;
		if (type_reference.data_type != null) {
			return new CCodeIdentifier (type_reference.data_type.get_set_value_function ());
		} else if (array_type != null && array_type.element_type.data_type == string_type.data_type) {
			// G_TYPE_STRV
			return new CCodeIdentifier ("g_value_set_boxed");
		} else {
			return new CCodeIdentifier ("g_value_set_pointer");
		}
	}

	public CCodeIdentifier get_value_taker_function (DataType type_reference) {
		var array_type = type_reference as ArrayType;
		if (type_reference.data_type != null) {
			return new CCodeIdentifier (type_reference.data_type.get_take_value_function ());
		} else if (array_type != null && array_type.element_type.data_type == string_type.data_type) {
			// G_TYPE_STRV
			return new CCodeIdentifier ("g_value_take_boxed");
		} else {
			return new CCodeIdentifier ("g_value_set_pointer");
		}
	}

	CCodeIdentifier get_value_getter_function (DataType type_reference) {
		var array_type = type_reference as ArrayType;
		if (type_reference.data_type != null) {
			return new CCodeIdentifier (type_reference.data_type.get_get_value_function ());
		} else if (array_type != null && array_type.element_type.data_type == string_type.data_type) {
			// G_TYPE_STRV
			return new CCodeIdentifier ("g_value_get_boxed");
		} else {
			return new CCodeIdentifier ("g_value_get_pointer");
		}
	}

	public virtual void append_vala_array_free () {
	}

	public virtual void append_vala_array_move () {
	}

	public virtual void append_vala_array_length () {
	}

	public override void visit_source_file (SourceFile source_file) {
		cfile = new CCodeFile ();
		
		user_marshal_set = new HashSet<string> (str_hash, str_equal);
		
		next_regex_id = 0;
		
		gvaluecollector_h_needed = false;
		requires_array_free = false;
		requires_array_move = false;
		requires_array_length = false;

		wrappers = new HashSet<string> (str_hash, str_equal);
		generated_external_symbols = new HashSet<Symbol> ();

		if (context.profile == Profile.GOBJECT) {
			header_file.add_include ("glib.h");
			internal_header_file.add_include ("glib.h");
			cfile.add_include ("glib.h");
			cfile.add_include ("glib-object.h");
		}

		source_file.accept_children (this);

		if (context.report.get_errors () > 0) {
			return;
		}

		/* For fast-vapi, we only wanted the header declarations
		 * to be emitted, so bail out here without writing the
		 * C code output.
		 */
		if (source_file.file_type == SourceFileType.FAST) {
			return;
		}

		if (requires_array_free) {
			append_vala_array_free ();
		}
		if (requires_array_move) {
			append_vala_array_move ();
		}
		if (requires_array_length) {
			append_vala_array_length ();
		}

		if (gvaluecollector_h_needed) {
			cfile.add_include ("gobject/gvaluecollector.h");
		}

		var comments = source_file.get_comments();
		if (comments != null) {
			foreach (Comment comment in comments) {
				var ccomment = new CCodeComment (comment.content);
				cfile.add_comment (ccomment);
			}
		}

		if (!cfile.store (source_file.get_csource_filename (), source_file.filename, context.version_header, context.debug)) {
			Report.error (null, "unable to open `%s' for writing".printf (source_file.get_csource_filename ()));
		}

		cfile = null;
	}

	public virtual bool generate_enum_declaration (Enum en, CCodeFile decl_space) {
		if (add_symbol_declaration (decl_space, en, en.get_cname ())) {
			return false;
		}

		var cenum = new CCodeEnum (en.get_cname ());

		cenum.deprecated = en.deprecated;

		int flag_shift = 0;
		foreach (EnumValue ev in en.get_values ()) {
			CCodeEnumValue c_ev;
			if (ev.value == null) {
				c_ev = new CCodeEnumValue (ev.get_cname ());
				if (en.is_flags) {
					c_ev.value = new CCodeConstant ("1 << %d".printf (flag_shift));
					flag_shift += 1;
				}
			} else {
				ev.value.emit (this);
				c_ev = new CCodeEnumValue (ev.get_cname (), get_cvalue (ev.value));
			}
			c_ev.deprecated = ev.deprecated;
			cenum.add_value (c_ev);
		}

		decl_space.add_type_definition (cenum);
		decl_space.add_type_definition (new CCodeNewline ());

		if (!en.has_type_id) {
			return true;
		}

		decl_space.add_type_declaration (new CCodeNewline ());

		var macro = "(%s_get_type ())".printf (en.get_lower_case_cname (null));
		decl_space.add_type_declaration (new CCodeMacroReplacement (en.get_type_id (), macro));

		var fun_name = "%s_get_type".printf (en.get_lower_case_cname (null));
		var regfun = new CCodeFunction (fun_name, "GType");
		regfun.attributes = "G_GNUC_CONST";

		if (en.access == SymbolAccessibility.PRIVATE) {
			regfun.modifiers = CCodeModifiers.STATIC;
			// avoid C warning as this function is not always used
			regfun.attributes = "G_GNUC_UNUSED";
		}

		decl_space.add_function_declaration (regfun);

		return true;
	}

	public override void visit_enum (Enum en) {
		en.accept_children (this);

		if (en.comment != null) {
			cfile.add_type_member_definition (new CCodeComment (en.comment.content));
		}

		generate_enum_declaration (en, cfile);

		if (!en.is_internal_symbol ()) {
			generate_enum_declaration (en, header_file);
		}
		if (!en.is_private_symbol ()) {
			generate_enum_declaration (en, internal_header_file);
		}
	}

	public void visit_member (Symbol m) {
		/* stuff meant for all lockable members */
		if (m is Lockable && ((Lockable) m).get_lock_used ()) {
			CCodeExpression l = new CCodeIdentifier ("self");
			var init_context = class_init_context;
			var finalize_context = class_finalize_context;

			if (m.is_instance_member ()) {
				l = new CCodeMemberAccess.pointer (new CCodeMemberAccess.pointer (l, "priv"), get_symbol_lock_name (m.name));
				init_context = instance_init_context;
				finalize_context = instance_finalize_context;
			} else if (m.is_class_member ()) {
				TypeSymbol parent = (TypeSymbol)m.parent_symbol;

				var get_class_private_call = new CCodeFunctionCall (new CCodeIdentifier ("%s_GET_CLASS_PRIVATE".printf(parent.get_upper_case_cname ())));
				get_class_private_call.add_argument (new CCodeIdentifier ("klass"));
				l = new CCodeMemberAccess.pointer (get_class_private_call, get_symbol_lock_name (m.name));
			} else {
				l = new CCodeIdentifier (get_symbol_lock_name ("%s_%s".printf(m.parent_symbol.get_lower_case_cname (), m.name)));
			}

			push_context (init_context);
			var initf = new CCodeFunctionCall (new CCodeIdentifier (mutex_type.default_construction_method.get_cname ()));
			initf.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, l));
			ccode.add_expression (initf);
			pop_context ();

			if (finalize_context != null) {
				push_context (finalize_context);
				var fc = new CCodeFunctionCall (new CCodeIdentifier ("g_static_rec_mutex_free"));
				fc.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, l));
				ccode.add_expression (fc);
				pop_context ();
			}
		}
	}

	public void generate_constant_declaration (Constant c, CCodeFile decl_space, bool definition = false) {
		if (c.parent_symbol is Block) {
			// local constant
			return;
		}

		if (add_symbol_declaration (decl_space, c, c.get_cname ())) {
			return;
		}

		if (!c.external) {
			generate_type_declaration (c.type_reference, decl_space);

			c.value.emit (this);

			var initializer_list = c.value as InitializerList;
			if (initializer_list != null) {
				var cdecl = new CCodeDeclaration (c.type_reference.get_const_cname ());
				var arr = "";
				if (c.type_reference is ArrayType) {
					arr = "[%d]".printf (initializer_list.size);
				}

				var cinitializer = get_cvalue (c.value);
				if (!definition) {
					// never output value in header
					// special case needed as this method combines declaration and definition
					cinitializer = null;
				}

				cdecl.add_declarator (new CCodeVariableDeclarator ("%s%s".printf (c.get_cname (), arr), cinitializer));
				if (c.is_private_symbol ()) {
					cdecl.modifiers = CCodeModifiers.STATIC;
				} else {
					cdecl.modifiers = CCodeModifiers.EXTERN;
				}

				decl_space.add_constant_declaration (cdecl);
			} else {
				var cdefine = new CCodeMacroReplacement.with_expression (c.get_cname (), get_cvalue (c.value));
				decl_space.add_type_member_declaration (cdefine);
			}
		}
	}

	public override void visit_constant (Constant c) {
		if (c.parent_symbol is Block) {
			// local constant

			generate_type_declaration (c.type_reference, cfile);

			c.value.emit (this);

			string type_name = c.type_reference.get_const_cname ();
			string arr = "";
			if (c.type_reference is ArrayType) {
				arr = "[]";
			}

			if (c.type_reference.compatible (string_type)) {
				type_name = "const char";
				arr = "[]";
			}

			var cinitializer = get_cvalue (c.value);

			ccode.add_declaration (type_name, new CCodeVariableDeclarator ("%s%s".printf (c.get_cname (), arr), cinitializer), CCodeModifiers.STATIC);

			return;
		}

		generate_constant_declaration (c, cfile, true);

		if (!c.is_internal_symbol ()) {
			generate_constant_declaration (c, header_file);
		}
		if (!c.is_private_symbol ()) {
			generate_constant_declaration (c, internal_header_file);
		}
	}

	public void generate_field_declaration (Field f, CCodeFile decl_space) {
		if (add_symbol_declaration (decl_space, f, f.get_cname ())) {
			return;
		}

		generate_type_declaration (f.variable_type, decl_space);

		string field_ctype = f.variable_type.get_cname ();
		if (f.is_volatile) {
			field_ctype = "volatile " + field_ctype;
		}

		var cdecl = new CCodeDeclaration (field_ctype);
		cdecl.add_declarator (new CCodeVariableDeclarator (f.get_cname (), null, f.variable_type.get_cdeclarator_suffix ()));
		if (f.is_private_symbol ()) {
			cdecl.modifiers = CCodeModifiers.STATIC;
		} else {
			cdecl.modifiers = CCodeModifiers.EXTERN;
		}
		if (f.deprecated) {
			cdecl.modifiers |= CCodeModifiers.DEPRECATED;
		}
		decl_space.add_type_member_declaration (cdecl);

		if (f.get_lock_used ()) {
			// Declare mutex for static member
			var flock = new CCodeDeclaration (mutex_type.get_cname ());
			var flock_decl =  new CCodeVariableDeclarator (get_symbol_lock_name (f.get_cname ()), new CCodeConstant ("{0}"));
			flock.add_declarator (flock_decl);

			if (f.is_private_symbol ()) {
				flock.modifiers = CCodeModifiers.STATIC;
			} else {
				flock.modifiers = CCodeModifiers.EXTERN;
			}
			decl_space.add_type_member_declaration (flock);
		}

		if (f.variable_type is ArrayType && !f.no_array_length) {
			var array_type = (ArrayType) f.variable_type;

			if (!array_type.fixed_length) {
				for (int dim = 1; dim <= array_type.rank; dim++) {
					var len_type = int_type.copy ();

					cdecl = new CCodeDeclaration (len_type.get_cname ());
					cdecl.add_declarator (new CCodeVariableDeclarator (get_array_length_cname (f.get_cname (), dim)));
					if (f.is_private_symbol ()) {
						cdecl.modifiers = CCodeModifiers.STATIC;
					} else {
						cdecl.modifiers = CCodeModifiers.EXTERN;
					}
					decl_space.add_type_member_declaration (cdecl);
				}
			}
		} else if (f.variable_type is DelegateType) {
			var delegate_type = (DelegateType) f.variable_type;
			if (delegate_type.delegate_symbol.has_target) {
				// create field to store delegate target

				cdecl = new CCodeDeclaration ("gpointer");
				cdecl.add_declarator (new CCodeVariableDeclarator (get_delegate_target_cname  (f.get_cname ())));
				if (f.is_private_symbol ()) {
					cdecl.modifiers = CCodeModifiers.STATIC;
				} else {
					cdecl.modifiers = CCodeModifiers.EXTERN;
				}
				decl_space.add_type_member_declaration (cdecl);

				if (delegate_type.value_owned) {
					cdecl = new CCodeDeclaration ("GDestroyNotify");
					cdecl.add_declarator (new CCodeVariableDeclarator (get_delegate_target_destroy_notify_cname  (f.get_cname ())));
					if (f.is_private_symbol ()) {
						cdecl.modifiers = CCodeModifiers.STATIC;
					} else {
						cdecl.modifiers = CCodeModifiers.EXTERN;
					}
					decl_space.add_type_member_declaration (cdecl);
				}
			}
		}
	}

	public override void visit_field (Field f) {
		visit_member (f);

		check_type (f.variable_type);

		var cl = f.parent_symbol as Class;
		bool is_gtypeinstance = (cl != null && !cl.is_compact);

		CCodeExpression lhs = null;

		string field_ctype = f.variable_type.get_cname ();
		if (f.is_volatile) {
			field_ctype = "volatile " + field_ctype;
		}

		if (f.binding == MemberBinding.INSTANCE)  {
			if (is_gtypeinstance && f.access == SymbolAccessibility.PRIVATE) {
				lhs = new CCodeMemberAccess.pointer (new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), "priv"), f.get_cname ());
			} else {
				lhs = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), f.get_cname ());
			}

			if (f.initializer != null) {
				push_context (instance_init_context);

				f.initializer.emit (this);

				var rhs = get_cvalue (f.initializer);

				ccode.add_assignment (lhs, rhs);

				if (f.variable_type is ArrayType && !f.no_array_length &&
				    f.initializer is ArrayCreationExpression) {
					var array_type = (ArrayType) f.variable_type;
					var this_access = new MemberAccess.simple ("this");
					this_access.value_type = get_data_type_for_symbol ((TypeSymbol) f.parent_symbol);
					set_cvalue (this_access, new CCodeIdentifier ("self"));
					var ma = new MemberAccess (this_access, f.name);
					ma.symbol_reference = f;
					ma.value_type = f.variable_type.copy ();
					visit_member_access (ma);

					List<Expression> sizes = ((ArrayCreationExpression) f.initializer).get_sizes ();
					for (int dim = 1; dim <= array_type.rank; dim++) {
						var array_len_lhs = get_array_length_cexpression (ma, dim);
						var size = sizes[dim - 1];
						ccode.add_assignment (array_len_lhs, get_cvalue (size));
					}

					if (array_type.rank == 1 && f.is_internal_symbol ()) {
						var lhs_array_size = get_array_size_cvalue (ma.target_value);
						var rhs_array_len = get_array_length_cexpression (ma, 1);
						ccode.add_assignment (lhs_array_size, rhs_array_len);
					}
				}

				foreach (LocalVariable local in temp_ref_vars) {
					ccode.add_expression (destroy_variable (local));
				}

				temp_ref_vars.clear ();

				pop_context ();
			}
			
			if (requires_destroy (f.variable_type) && instance_finalize_context != null) {
				push_context (instance_finalize_context);

				var this_access = new MemberAccess.simple ("this");
				this_access.value_type = get_data_type_for_symbol ((TypeSymbol) f.parent_symbol);

				var field_st = f.parent_symbol as Struct;
				if (field_st != null && !field_st.is_simple_type ()) {
					set_cvalue (this_access, new CCodeIdentifier ("(*self)"));
				} else {
					set_cvalue (this_access, new CCodeIdentifier ("self"));
				}

				var ma = new MemberAccess (this_access, f.name);
				ma.symbol_reference = f;
				ma.value_type = f.variable_type.copy ();
				visit_member_access (ma);
				ccode.add_expression (get_unref_expression (lhs, f.variable_type, ma));

				pop_context ();
			}
		} else if (f.binding == MemberBinding.CLASS)  {
			if (!is_gtypeinstance) {
				Report.error (f.source_reference, "class fields are not supported in compact classes");
				f.error = true;
				return;
			}

			if (f.access == SymbolAccessibility.PRIVATE) {
				var ccall = new CCodeFunctionCall (new CCodeIdentifier ("%s_GET_CLASS_PRIVATE".printf (cl.get_upper_case_cname ())));
				ccall.add_argument (new CCodeIdentifier ("klass"));
				lhs = new CCodeMemberAccess (ccall, f.get_cname (), true);
			} else {
				lhs = new CCodeMemberAccess (new CCodeIdentifier ("klass"), f.get_cname (), true);
			}

			if (f.initializer != null) {
				push_context (class_init_context);

				f.initializer.emit (this);

				var rhs = get_cvalue (f.initializer);

				ccode.add_assignment (lhs, rhs);

				foreach (LocalVariable local in temp_ref_vars) {
					ccode.add_expression (destroy_variable (local));
				}

				temp_ref_vars.clear ();

				pop_context ();
			}
		} else {
			generate_field_declaration (f, cfile);

			if (!f.is_internal_symbol ()) {
				generate_field_declaration (f, header_file);
			}
			if (!f.is_private_symbol ()) {
				generate_field_declaration (f, internal_header_file);
			}

			lhs = new CCodeIdentifier (f.get_cname ());

			var var_decl = new CCodeVariableDeclarator (f.get_cname (), null, f.variable_type.get_cdeclarator_suffix ());
			var_decl.initializer = default_value_for_type (f.variable_type, true);

			if (class_init_context != null) {
				push_context (class_init_context);
			} else {
				push_context (new EmitContext ());
			}

			if (f.initializer != null) {
				f.initializer.emit (this);

				var init = get_cvalue (f.initializer);
				if (is_constant_ccode_expression (init)) {
					var_decl.initializer = init;
				}
			}

			var var_def = new CCodeDeclaration (field_ctype);
			var_def.add_declarator (var_decl);
			if (!f.is_private_symbol ()) {
				var_def.modifiers = CCodeModifiers.EXTERN;
			} else {
				var_def.modifiers = CCodeModifiers.STATIC;
			}
			cfile.add_type_member_declaration (var_def);

			/* add array length fields where necessary */
			if (f.variable_type is ArrayType && !f.no_array_length) {
				var array_type = (ArrayType) f.variable_type;

				if (!array_type.fixed_length) {
					for (int dim = 1; dim <= array_type.rank; dim++) {
						var len_type = int_type.copy ();

						var len_def = new CCodeDeclaration (len_type.get_cname ());
						len_def.add_declarator (new CCodeVariableDeclarator (get_array_length_cname (f.get_cname (), dim), new CCodeConstant ("0")));
						if (!f.is_private_symbol ()) {
							len_def.modifiers = CCodeModifiers.EXTERN;
						} else {
							len_def.modifiers = CCodeModifiers.STATIC;
						}
						cfile.add_type_member_declaration (len_def);
					}

					if (array_type.rank == 1 && f.is_internal_symbol ()) {
						var len_type = int_type.copy ();

						var cdecl = new CCodeDeclaration (len_type.get_cname ());
						cdecl.add_declarator (new CCodeVariableDeclarator (get_array_size_cname (f.get_cname ()), new CCodeConstant ("0")));
						cdecl.modifiers = CCodeModifiers.STATIC;
						cfile.add_type_member_declaration (cdecl);
					}
				}
			} else if (f.variable_type is DelegateType) {
				var delegate_type = (DelegateType) f.variable_type;
				if (delegate_type.delegate_symbol.has_target) {
					// create field to store delegate target

					var target_def = new CCodeDeclaration ("gpointer");
					target_def.add_declarator (new CCodeVariableDeclarator (get_delegate_target_cname  (f.get_cname ()), new CCodeConstant ("NULL")));
					if (!f.is_private_symbol ()) {
						target_def.modifiers = CCodeModifiers.EXTERN;
					} else {
						target_def.modifiers = CCodeModifiers.STATIC;
					}
					cfile.add_type_member_declaration (target_def);

					if (delegate_type.value_owned) {
						var target_destroy_notify_def = new CCodeDeclaration ("GDestroyNotify");
						target_destroy_notify_def.add_declarator (new CCodeVariableDeclarator (get_delegate_target_destroy_notify_cname  (f.get_cname ()), new CCodeConstant ("NULL")));
						if (!f.is_private_symbol ()) {
							target_destroy_notify_def.modifiers = CCodeModifiers.EXTERN;
						} else {
							target_destroy_notify_def.modifiers = CCodeModifiers.STATIC;
						}
						cfile.add_type_member_declaration (target_destroy_notify_def);

					}
				}
			}

			if (f.initializer != null) {
				var rhs = get_cvalue (f.initializer);
				if (!is_constant_ccode_expression (rhs)) {
					if (f.parent_symbol is Class) {
						if (f.initializer is InitializerList) {
							ccode.open_block ();

							var temp_decl = get_temp_variable (f.variable_type);
							var vardecl = new CCodeVariableDeclarator.zero (temp_decl.name, rhs);
							ccode.add_declaration (temp_decl.variable_type.get_cname (), vardecl);

							var tmp = get_variable_cexpression (get_variable_cname (temp_decl.name));
							ccode.add_assignment (lhs, tmp);

							ccode.close ();
						} else {
							ccode.add_assignment (lhs, rhs);
						}

						if (f.variable_type is ArrayType && !f.no_array_length &&
						    f.initializer is ArrayCreationExpression) {
							var array_type = (ArrayType) f.variable_type;
							var ma = new MemberAccess.simple (f.name);
							ma.symbol_reference = f;
							ma.value_type = f.variable_type.copy ();
							visit_member_access (ma);

							List<Expression> sizes = ((ArrayCreationExpression) f.initializer).get_sizes ();
							for (int dim = 1; dim <= array_type.rank; dim++) {
								var array_len_lhs = get_array_length_cexpression (ma, dim);
								var size = sizes[dim - 1];
								ccode.add_assignment (array_len_lhs, get_cvalue (size));
							}
						}
					} else {
						f.error = true;
						Report.error (f.source_reference, "Non-constant field initializers not supported in this context");
						return;
					}
				}
			}

			pop_context ();
		}
	}

	public bool is_constant_ccode_expression (CCodeExpression cexpr) {
		if (cexpr is CCodeConstant) {
			return true;
		} else if (cexpr is CCodeCastExpression) {
			var ccast = (CCodeCastExpression) cexpr;
			return is_constant_ccode_expression (ccast.inner);
		} else if (cexpr is CCodeBinaryExpression) {
			var cbinary = (CCodeBinaryExpression) cexpr;
			return is_constant_ccode_expression (cbinary.left) && is_constant_ccode_expression (cbinary.right);
		}

		var cparenthesized = (cexpr as CCodeParenthesizedExpression);
		return (null != cparenthesized && is_constant_ccode_expression (cparenthesized.inner));
	}

	/**
	 * Returns whether the passed cexpr is a pure expression, i.e. an
	 * expression without side-effects.
	 */
	public bool is_pure_ccode_expression (CCodeExpression cexpr) {
		if (cexpr is CCodeConstant || cexpr is CCodeIdentifier) {
			return true;
		} else if (cexpr is CCodeBinaryExpression) {
			var cbinary = (CCodeBinaryExpression) cexpr;
			return is_pure_ccode_expression (cbinary.left) && is_constant_ccode_expression (cbinary.right);
		} else if (cexpr is CCodeUnaryExpression) {
			var cunary = (CCodeUnaryExpression) cexpr;
			switch (cunary.operator) {
			case CCodeUnaryOperator.PREFIX_INCREMENT:
			case CCodeUnaryOperator.PREFIX_DECREMENT:
			case CCodeUnaryOperator.POSTFIX_INCREMENT:
			case CCodeUnaryOperator.POSTFIX_DECREMENT:
				return false;
			default:
				return is_pure_ccode_expression (cunary.inner);
			}
		} else if (cexpr is CCodeMemberAccess) {
			var cma = (CCodeMemberAccess) cexpr;
			return is_pure_ccode_expression (cma.inner);
		} else if (cexpr is CCodeElementAccess) {
			var cea = (CCodeElementAccess) cexpr;
			return is_pure_ccode_expression (cea.container) && is_pure_ccode_expression (cea.index);
		} else if (cexpr is CCodeCastExpression) {
			var ccast = (CCodeCastExpression) cexpr;
			return is_pure_ccode_expression (ccast.inner);
		} else if (cexpr is CCodeParenthesizedExpression) {
			var cparenthesized = (CCodeParenthesizedExpression) cexpr;
			return is_pure_ccode_expression (cparenthesized.inner);
		}

		return false;
	}

	public override void visit_formal_parameter (Parameter p) {
		if (!p.ellipsis) {
			check_type (p.variable_type);
		}
	}

	public override void visit_property (Property prop) {
		visit_member (prop);

		check_type (prop.property_type);

		if (prop.get_accessor != null) {
			prop.get_accessor.accept (this);
		}
		if (prop.set_accessor != null) {
			prop.set_accessor.accept (this);
		}
	}

	public void generate_type_declaration (DataType type, CCodeFile decl_space) {
		if (type is ObjectType) {
			var object_type = (ObjectType) type;
			if (object_type.type_symbol is Class) {
				generate_class_declaration ((Class) object_type.type_symbol, decl_space);
			} else if (object_type.type_symbol is Interface) {
				generate_interface_declaration ((Interface) object_type.type_symbol, decl_space);
			}
		} else if (type is DelegateType) {
			var deleg_type = (DelegateType) type;
			var d = deleg_type.delegate_symbol;
			generate_delegate_declaration (d, decl_space);
		} else if (type.data_type is Enum) {
			var en = (Enum) type.data_type;
			generate_enum_declaration (en, decl_space);
		} else if (type is ValueType) {
			var value_type = (ValueType) type;
			generate_struct_declaration ((Struct) value_type.type_symbol, decl_space);
		} else if (type is ArrayType) {
			var array_type = (ArrayType) type;
			generate_type_declaration (array_type.element_type, decl_space);
		} else if (type is ErrorType) {
			var error_type = (ErrorType) type;
			if (error_type.error_domain != null) {
				generate_error_domain_declaration (error_type.error_domain, decl_space);
			}
		} else if (type is PointerType) {
			var pointer_type = (PointerType) type;
			generate_type_declaration (pointer_type.base_type, decl_space);
		}

		foreach (DataType type_arg in type.get_type_arguments ()) {
			generate_type_declaration (type_arg, decl_space);
		}
	}

	public virtual void generate_class_struct_declaration (Class cl, CCodeFile decl_space) {
	}

	public virtual void generate_struct_declaration (Struct st, CCodeFile decl_space) {
	}

	public virtual void generate_delegate_declaration (Delegate d, CCodeFile decl_space) {
	}

	public virtual void generate_cparameters (Method m, CCodeFile decl_space, Map<int,CCodeParameter> cparam_map, CCodeFunction func, CCodeFunctionDeclarator? vdeclarator = null, Map<int,CCodeExpression>? carg_map = null, CCodeFunctionCall? vcall = null, int direction = 3) {
	}

	public void generate_property_accessor_declaration (PropertyAccessor acc, CCodeFile decl_space) {
		if (add_symbol_declaration (decl_space, acc, acc.get_cname ())) {
			return;
		}

		var prop = (Property) acc.prop;

		bool returns_real_struct = acc.readable && prop.property_type.is_real_non_null_struct_type ();


		CCodeParameter cvalueparam;
		if (returns_real_struct) {
			cvalueparam = new CCodeParameter ("result", acc.value_type.get_cname () + "*");
		} else if (!acc.readable && prop.property_type.is_real_non_null_struct_type ()) {
			cvalueparam = new CCodeParameter ("value", acc.value_type.get_cname () + "*");
		} else {
			cvalueparam = new CCodeParameter ("value", acc.value_type.get_cname ());
		}
		generate_type_declaration (acc.value_type, decl_space);

		CCodeFunction function;
		if (acc.readable && !returns_real_struct) {
			function = new CCodeFunction (acc.get_cname (), acc.value_type.get_cname ());
		} else {
			function = new CCodeFunction (acc.get_cname (), "void");
		}

		if (prop.binding == MemberBinding.INSTANCE) {
			var t = (TypeSymbol) prop.parent_symbol;
			var this_type = get_data_type_for_symbol (t);
			generate_type_declaration (this_type, decl_space);
			var cselfparam = new CCodeParameter ("self", this_type.get_cname ());
			if (t is Struct) {
				cselfparam.type_name += "*";
			}

			function.add_parameter (cselfparam);
		}

		if (acc.writable || acc.construction || returns_real_struct) {
			function.add_parameter (cvalueparam);
		}

		if (acc.value_type is ArrayType) {
			var array_type = (ArrayType) acc.value_type;

			var length_ctype = "int";
			if (acc.readable) {
				length_ctype = "int*";
			}

			for (int dim = 1; dim <= array_type.rank; dim++) {
				function.add_parameter (new CCodeParameter (get_array_length_cname (acc.readable ? "result" : "value", dim), length_ctype));
			}
		} else if ((acc.value_type is DelegateType) && ((DelegateType) acc.value_type).delegate_symbol.has_target) {
			function.add_parameter (new CCodeParameter (get_delegate_target_cname (acc.readable ? "result" : "value"), acc.readable ? "gpointer*" : "gpointer"));
		}

		if (prop.is_private_symbol () || (!acc.readable && !acc.writable) || acc.access == SymbolAccessibility.PRIVATE) {
			function.modifiers |= CCodeModifiers.STATIC;
		}
		decl_space.add_function_declaration (function);
	}

	public override void visit_property_accessor (PropertyAccessor acc) {
		push_context (new EmitContext (acc));

		var prop = (Property) acc.prop;

		if (acc.comment != null) {
			cfile.add_type_member_definition (new CCodeComment (acc.comment.content));
		}

		bool returns_real_struct = acc.readable && prop.property_type.is_real_non_null_struct_type ();

		if (acc.result_var != null) {
			acc.result_var.accept (this);
		}

		var t = (TypeSymbol) prop.parent_symbol;

		if (acc.construction && !t.is_subtype_of (gobject_type)) {
			Report.error (acc.source_reference, "construct properties require GLib.Object");
			acc.error = true;
			return;
		} else if (acc.construction && !is_gobject_property (prop)) {
			Report.error (acc.source_reference, "construct properties not supported for specified property type");
			acc.error = true;
			return;
		}

		// do not declare overriding properties and interface implementations
		if (prop.is_abstract || prop.is_virtual
		    || (prop.base_property == null && prop.base_interface_property == null)) {
			generate_property_accessor_declaration (acc, cfile);

			// do not declare construct-only properties in header files
			if (acc.readable || acc.writable) {
				if (!prop.is_internal_symbol ()
				    && (acc.access == SymbolAccessibility.PUBLIC
					|| acc.access == SymbolAccessibility.PROTECTED)) {
					generate_property_accessor_declaration (acc, header_file);
				}
				if (!prop.is_private_symbol () && acc.access != SymbolAccessibility.PRIVATE) {
					generate_property_accessor_declaration (acc, internal_header_file);
				}
			}
		}

		if (acc.source_type == SourceFileType.FAST) {
			return;
		}

		var this_type = get_data_type_for_symbol (t);
		var cselfparam = new CCodeParameter ("self", this_type.get_cname ());
		if (t is Struct) {
			cselfparam.type_name += "*";
		}
		CCodeParameter cvalueparam;
		if (returns_real_struct) {
			cvalueparam = new CCodeParameter ("result", acc.value_type.get_cname () + "*");
		} else if (!acc.readable && prop.property_type.is_real_non_null_struct_type ()) {
			cvalueparam = new CCodeParameter ("value", acc.value_type.get_cname () + "*");
		} else {
			cvalueparam = new CCodeParameter ("value", acc.value_type.get_cname ());
		}

		if (prop.is_abstract || prop.is_virtual) {
			CCodeFunction function;
			if (acc.readable && !returns_real_struct) {
				function = new CCodeFunction (acc.get_cname (), current_return_type.get_cname ());
			} else {
				function = new CCodeFunction (acc.get_cname (), "void");
			}
			function.add_parameter (cselfparam);
			if (acc.writable || acc.construction || returns_real_struct) {
				function.add_parameter (cvalueparam);
			}

			if (acc.value_type is ArrayType) {
				var array_type = (ArrayType) acc.value_type;

				var length_ctype = "int";
				if (acc.readable) {
					length_ctype = "int*";
				}

				for (int dim = 1; dim <= array_type.rank; dim++) {
					function.add_parameter (new CCodeParameter (get_array_length_cname (acc.readable ? "result" : "value", dim), length_ctype));
				}
			} else if ((acc.value_type is DelegateType) && ((DelegateType) acc.value_type).delegate_symbol.has_target) {
				function.add_parameter (new CCodeParameter (get_delegate_target_cname (acc.readable ? "result" : "value"), acc.readable ? "gpointer*" : "gpointer"));
			}

			if (prop.is_private_symbol () || !(acc.readable || acc.writable) || acc.access == SymbolAccessibility.PRIVATE) {
				// accessor function should be private if the property is an internal symbol or it's a construct-only setter
				function.modifiers |= CCodeModifiers.STATIC;
			}

			push_function (function);

			CCodeFunctionCall vcast = null;
			if (prop.parent_symbol is Interface) {
				var iface = (Interface) prop.parent_symbol;

				vcast = new CCodeFunctionCall (new CCodeIdentifier ("%s_GET_INTERFACE".printf (iface.get_upper_case_cname (null))));
			} else {
				var cl = (Class) prop.parent_symbol;

				vcast = new CCodeFunctionCall (new CCodeIdentifier ("%s_GET_CLASS".printf (cl.get_upper_case_cname (null))));
			}
			vcast.add_argument (new CCodeIdentifier ("self"));

			if (acc.readable) {
				var vcall = new CCodeFunctionCall (new CCodeMemberAccess.pointer (vcast, "get_%s".printf (prop.name)));
				vcall.add_argument (new CCodeIdentifier ("self"));
				if (returns_real_struct) {
					vcall.add_argument (new CCodeIdentifier ("result"));
					ccode.add_expression (vcall);
				} else {
					if (acc.value_type is ArrayType) {
						var array_type = (ArrayType) acc.value_type;

						for (int dim = 1; dim <= array_type.rank; dim++) {
							var len_expr = new CCodeIdentifier (get_array_length_cname ("result", dim));
							vcall.add_argument (len_expr);
						}
					} else if ((acc.value_type is DelegateType) && ((DelegateType) acc.value_type).delegate_symbol.has_target) {
						vcall.add_argument (new CCodeIdentifier (get_delegate_target_cname ("result")));
					}

					ccode.add_return (vcall);
				}
			} else {
				var vcall = new CCodeFunctionCall (new CCodeMemberAccess.pointer (vcast, "set_%s".printf (prop.name)));
				vcall.add_argument (new CCodeIdentifier ("self"));
				vcall.add_argument (new CCodeIdentifier ("value"));

				if (acc.value_type is ArrayType) {
					var array_type = (ArrayType) acc.value_type;

					for (int dim = 1; dim <= array_type.rank; dim++) {
						var len_expr = new CCodeIdentifier (get_array_length_cname ("value", dim));
						vcall.add_argument (len_expr);
					}
				} else if ((acc.value_type is DelegateType) && ((DelegateType) acc.value_type).delegate_symbol.has_target) {
					vcall.add_argument (new CCodeIdentifier (get_delegate_target_cname ("value")));
				}

				ccode.add_expression (vcall);
			}

			pop_function ();

			cfile.add_function (function);
		}

		if (!prop.is_abstract) {
			bool is_virtual = prop.base_property != null || prop.base_interface_property != null;

			string cname;
			if (is_virtual) {
				if (acc.readable) {
					cname = "%s_real_get_%s".printf (t.get_lower_case_cname (null), prop.name);
				} else {
					cname = "%s_real_set_%s".printf (t.get_lower_case_cname (null), prop.name);
				}
			} else {
				cname = acc.get_cname ();
			}

			CCodeFunction function;
			if (acc.writable || acc.construction || returns_real_struct) {
				function = new CCodeFunction (cname, "void");
			} else {
				function = new CCodeFunction (cname, acc.value_type.get_cname ());
			}

			ObjectType base_type = null;
			if (prop.binding == MemberBinding.INSTANCE) {
				if (is_virtual) {
					if (prop.base_property != null) {
						base_type = new ObjectType ((ObjectTypeSymbol) prop.base_property.parent_symbol);
					} else if (prop.base_interface_property != null) {
						base_type = new ObjectType ((ObjectTypeSymbol) prop.base_interface_property.parent_symbol);
					}
					function.modifiers |= CCodeModifiers.STATIC;
					function.add_parameter (new CCodeParameter ("base", base_type.get_cname ()));
				} else {
					function.add_parameter (cselfparam);
				}
			}
			if (acc.writable || acc.construction || returns_real_struct) {
				function.add_parameter (cvalueparam);
			}

			if (acc.value_type is ArrayType) {
				var array_type = (ArrayType) acc.value_type;

				var length_ctype = "int";
				if (acc.readable) {
					length_ctype = "int*";
				}

				for (int dim = 1; dim <= array_type.rank; dim++) {
					function.add_parameter (new CCodeParameter (get_array_length_cname (acc.readable ? "result" : "value", dim), length_ctype));
				}
			} else if ((acc.value_type is DelegateType) && ((DelegateType) acc.value_type).delegate_symbol.has_target) {
				function.add_parameter (new CCodeParameter (get_delegate_target_cname (acc.readable ? "result" : "value"), acc.readable ? "gpointer*" : "gpointer"));
			}

			if (!is_virtual) {
				if (prop.is_private_symbol () || !(acc.readable || acc.writable) || acc.access == SymbolAccessibility.PRIVATE) {
					// accessor function should be private if the property is an internal symbol or it's a construct-only setter
					function.modifiers |= CCodeModifiers.STATIC;
				}
			}

			push_function (function);

			if (prop.binding == MemberBinding.INSTANCE && !is_virtual) {
				if (!acc.readable || returns_real_struct) {
					create_property_type_check_statement (prop, false, t, true, "self");
				} else {
					create_property_type_check_statement (prop, true, t, true, "self");
				}
			}

			if (acc.readable && !returns_real_struct) {
				// do not declare result variable if exit block is known to be unreachable
				if (acc.return_block == null || acc.return_block.get_predecessors ().size > 0) {
					ccode.add_declaration (acc.value_type.get_cname (), new CCodeVariableDeclarator ("result"));
				}
			}

			if (is_virtual) {
				ccode.add_declaration (this_type.get_cname (), new CCodeVariableDeclarator ("self"));
				ccode.add_assignment (new CCodeIdentifier ("self"), transform_expression (new CCodeIdentifier ("base"), base_type, this_type));
			}

			acc.body.emit (this);

			if (current_method_inner_error) {
				ccode.add_declaration ("GError *", new CCodeVariableDeclarator.zero ("_inner_error_", new CCodeConstant ("NULL")));
			}

			// notify on property changes
			if (is_gobject_property (prop) &&
			    prop.notify &&
			    (acc.writable || acc.construction)) {
				var notify_call = new CCodeFunctionCall (new CCodeIdentifier ("g_object_notify"));
				notify_call.add_argument (new CCodeCastExpression (new CCodeIdentifier ("self"), "GObject *"));
				notify_call.add_argument (prop.get_canonical_cconstant ());
				ccode.add_expression (notify_call);
			}

			cfile.add_function (function);
		}

		pop_context ();
	}

	public override void visit_destructor (Destructor d) {
		if (d.binding == MemberBinding.STATIC && !in_plugin) {
			Report.error (d.source_reference, "static destructors are only supported for dynamic types");
			d.error = true;
			return;
		}
	}

	public int get_block_id (Block b) {
		int result = block_map[b];
		if (result == 0) {
			result = ++next_block_id;
			block_map[b] = result;
		}
		return result;
	}

	void capture_parameter (Parameter param, CCodeStruct data, int block_id) {
		generate_type_declaration (param.variable_type, cfile);

		var param_type = param.variable_type.copy ();
		param_type.value_owned = true;
		data.add_field (param_type.get_cname (), get_variable_cname (param.name));

		bool is_unowned_delegate = param.variable_type is DelegateType && !param.variable_type.value_owned;

		// create copy if necessary as captured variables may need to be kept alive
		CCodeExpression cparam = get_variable_cexpression (param.name);
		if (param.variable_type.is_real_non_null_struct_type ()) {
			cparam = new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, cparam);
		}
		if (requires_copy (param_type) && !param.variable_type.value_owned && !is_unowned_delegate)  {
			var ma = new MemberAccess.simple (param.name);
			ma.symbol_reference = param;
			ma.value_type = param.variable_type.copy ();
			// directly access parameters in ref expressions
			param.captured = false;
			visit_member_access (ma);
			cparam = get_ref_cexpression (param.variable_type, cparam, ma, param);
			param.captured = true;
		}

		ccode.add_assignment (new CCodeMemberAccess.pointer (get_variable_cexpression ("_data%d_".printf (block_id)), get_variable_cname (param.name)), cparam);

		if (param.variable_type is ArrayType) {
			var array_type = (ArrayType) param.variable_type;
			for (int dim = 1; dim <= array_type.rank; dim++) {
				data.add_field ("gint", get_parameter_array_length_cname (param, dim));
				ccode.add_assignment (new CCodeMemberAccess.pointer (get_variable_cexpression ("_data%d_".printf (block_id)), get_array_length_cname (get_variable_cname (param.name), dim)), new CCodeIdentifier (get_array_length_cname (get_variable_cname (param.name), dim)));
			}
		} else if (param.variable_type is DelegateType) {
			CCodeExpression target_expr;
			CCodeExpression delegate_target_destroy_notify;
			if (is_in_coroutine ()) {
				target_expr = new CCodeMemberAccess.pointer (new CCodeIdentifier ("data"), get_delegate_target_cname (get_variable_cname (param.name)));
				delegate_target_destroy_notify = new CCodeMemberAccess.pointer (new CCodeIdentifier ("data"), get_delegate_target_destroy_notify_cname (get_variable_cname (param.name)));
			} else {
				target_expr = new CCodeIdentifier (get_delegate_target_cname (get_variable_cname (param.name)));
				delegate_target_destroy_notify = new CCodeIdentifier (get_delegate_target_destroy_notify_cname (get_variable_cname (param.name)));
			}

			data.add_field ("gpointer", get_delegate_target_cname (get_variable_cname (param.name)));
			ccode.add_assignment (new CCodeMemberAccess.pointer (get_variable_cexpression ("_data%d_".printf (block_id)), get_delegate_target_cname (get_variable_cname (param.name))), target_expr);
			if (param.variable_type.value_owned) {
				data.add_field ("GDestroyNotify", get_delegate_target_destroy_notify_cname (get_variable_cname (param.name)));
				ccode.add_assignment (new CCodeMemberAccess.pointer (get_variable_cexpression ("_data%d_".printf (block_id)), get_delegate_target_destroy_notify_cname (get_variable_cname (param.name))), delegate_target_destroy_notify);
			}
		}
	}

	public override void visit_block (Block b) {
		emit_context.push_symbol (b);

		var local_vars = b.get_local_variables ();

		if (b.parent_node is Block || b.parent_node is SwitchStatement) {
			ccode.open_block ();
		}

		if (b.captured) {
			var parent_block = next_closure_block (b.parent_symbol);

			int block_id = get_block_id (b);
			string struct_name = "Block%dData".printf (block_id);

			var data = new CCodeStruct ("_" + struct_name);
			data.add_field ("int", "_ref_count_");
			if (parent_block != null) {
				int parent_block_id = get_block_id (parent_block);

				data.add_field ("Block%dData *".printf (parent_block_id), "_data%d_".printf (parent_block_id));
			} else {
				if (in_constructor || (current_method != null && current_method.binding == MemberBinding.INSTANCE) ||
				           (current_property_accessor != null && current_property_accessor.prop.binding == MemberBinding.INSTANCE)) {
					data.add_field ("%s *".printf (current_class.get_cname ()), "self");
				}

				if (current_method != null) {
					// allow capturing generic type parameters
					foreach (var type_param in current_method.get_type_parameters ()) {
						string func_name;

						func_name = "%s_type".printf (type_param.name.down ());
						data.add_field ("GType", func_name);

						func_name = "%s_dup_func".printf (type_param.name.down ());
						data.add_field ("GBoxedCopyFunc", func_name);

						func_name = "%s_destroy_func".printf (type_param.name.down ());
						data.add_field ("GDestroyNotify", func_name);
					}
				}
			}
			foreach (var local in local_vars) {
				if (local.captured) {
					generate_type_declaration (local.variable_type, cfile);

					data.add_field (local.variable_type.get_cname (), get_variable_cname (local.name) + local.variable_type.get_cdeclarator_suffix ());

					if (local.variable_type is ArrayType) {
						var array_type = (ArrayType) local.variable_type;
						for (int dim = 1; dim <= array_type.rank; dim++) {
							data.add_field ("gint", get_array_length_cname (get_variable_cname (local.name), dim));
						}
						data.add_field ("gint", get_array_size_cname (get_variable_cname (local.name)));
					} else if (local.variable_type is DelegateType) {
						data.add_field ("gpointer", get_delegate_target_cname (get_variable_cname (local.name)));
						if (local.variable_type.value_owned) {
							data.add_field ("GDestroyNotify", get_delegate_target_destroy_notify_cname (get_variable_cname (local.name)));
						}
					}
				}
			}

			var data_alloc = new CCodeFunctionCall (new CCodeIdentifier ("g_slice_new0"));
			data_alloc.add_argument (new CCodeIdentifier (struct_name));

			if (is_in_coroutine ()) {
				closure_struct.add_field (struct_name + "*", "_data%d_".printf (block_id));
			} else {
				ccode.add_declaration (struct_name + "*", new CCodeVariableDeclarator ("_data%d_".printf (block_id)));
			}
			ccode.add_assignment (get_variable_cexpression ("_data%d_".printf (block_id)), data_alloc);

			// initialize ref_count
			ccode.add_assignment (new CCodeMemberAccess.pointer (get_variable_cexpression ("_data%d_".printf (block_id)), "_ref_count_"), new CCodeIdentifier ("1"));

			if (parent_block != null) {
				int parent_block_id = get_block_id (parent_block);

				var ref_call = new CCodeFunctionCall (new CCodeIdentifier ("block%d_data_ref".printf (parent_block_id)));
				ref_call.add_argument (get_variable_cexpression ("_data%d_".printf (parent_block_id)));

				ccode.add_assignment (new CCodeMemberAccess.pointer (get_variable_cexpression ("_data%d_".printf (block_id)), "_data%d_".printf (parent_block_id)), ref_call);
			} else {
				if (in_constructor || (current_method != null && current_method.binding == MemberBinding.INSTANCE &&
				                              (!(current_method is CreationMethod) || current_method.body != b)) ||
				           (current_property_accessor != null && current_property_accessor.prop.binding == MemberBinding.INSTANCE)) {
					var ref_call = new CCodeFunctionCall (get_dup_func_expression (new ObjectType (current_class), b.source_reference));
					ref_call.add_argument (get_result_cexpression ("self"));

					ccode.add_assignment (new CCodeMemberAccess.pointer (get_variable_cexpression ("_data%d_".printf (block_id)), "self"), ref_call);
				}

				if (current_method != null) {
					// allow capturing generic type parameters
					foreach (var type_param in current_method.get_type_parameters ()) {
						string func_name;

						func_name = "%s_type".printf (type_param.name.down ());
						ccode.add_assignment (new CCodeMemberAccess.pointer (get_variable_cexpression ("_data%d_".printf (block_id)), func_name), new CCodeIdentifier (func_name));

						func_name = "%s_dup_func".printf (type_param.name.down ());
						ccode.add_assignment (new CCodeMemberAccess.pointer (get_variable_cexpression ("_data%d_".printf (block_id)), func_name), new CCodeIdentifier (func_name));

						func_name = "%s_destroy_func".printf (type_param.name.down ());
						ccode.add_assignment (new CCodeMemberAccess.pointer (get_variable_cexpression ("_data%d_".printf (block_id)), func_name), new CCodeIdentifier (func_name));
					}
				}
			}

			if (b.parent_symbol is Method) {
				var m = (Method) b.parent_symbol;

				// parameters are captured with the top-level block of the method
				foreach (var param in m.get_parameters ()) {
					if (param.captured) {
						capture_parameter (param, data, block_id);
					}
				}

				if (m.coroutine) {
					// capture async data to allow invoking callback from inside closure
					data.add_field ("gpointer", "_async_data_");

					// async method is suspended while waiting for callback,
					// so we never need to care about memory management of async data
					ccode.add_assignment (new CCodeMemberAccess.pointer (get_variable_cexpression ("_data%d_".printf (block_id)), "_async_data_"), new CCodeIdentifier ("data"));
				}
			} else if (b.parent_symbol is PropertyAccessor) {
				var acc = (PropertyAccessor) b.parent_symbol;

				if (!acc.readable && acc.value_parameter.captured) {
					capture_parameter (acc.value_parameter, data, block_id);
				}
			}

			var typedef = new CCodeTypeDefinition ("struct _" + struct_name, new CCodeVariableDeclarator (struct_name));
			cfile.add_type_declaration (typedef);
			cfile.add_type_definition (data);

			// create ref/unref functions
			var ref_fun = new CCodeFunction ("block%d_data_ref".printf (block_id), struct_name + "*");
			ref_fun.add_parameter (new CCodeParameter ("_data%d_".printf (block_id), struct_name + "*"));
			ref_fun.modifiers = CCodeModifiers.STATIC;
			cfile.add_function_declaration (ref_fun);
			ref_fun.block = new CCodeBlock ();

			var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_atomic_int_inc"));
			ccall.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeMemberAccess.pointer (new CCodeIdentifier ("_data%d_".printf (block_id)), "_ref_count_")));
			ref_fun.block.add_statement (new CCodeExpressionStatement (ccall));
			ref_fun.block.add_statement (new CCodeReturnStatement (new CCodeIdentifier ("_data%d_".printf (block_id))));
			cfile.add_function (ref_fun);

			var unref_fun = new CCodeFunction ("block%d_data_unref".printf (block_id), "void");
			unref_fun.add_parameter (new CCodeParameter ("_data%d_".printf (block_id), struct_name + "*"));
			unref_fun.modifiers = CCodeModifiers.STATIC;
			cfile.add_function_declaration (unref_fun);
			
			push_function (unref_fun);

			ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_atomic_int_dec_and_test"));
			ccall.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeMemberAccess.pointer (new CCodeIdentifier ("_data%d_".printf (block_id)), "_ref_count_")));
			ccode.open_if (ccall);

			if (parent_block != null) {
				int parent_block_id = get_block_id (parent_block);

				var unref_call = new CCodeFunctionCall (new CCodeIdentifier ("block%d_data_unref".printf (parent_block_id)));
				unref_call.add_argument (new CCodeMemberAccess.pointer (new CCodeIdentifier ("_data%d_".printf (block_id)), "_data%d_".printf (parent_block_id)));
				ccode.add_expression (unref_call);
				ccode.add_assignment (new CCodeMemberAccess.pointer (new CCodeIdentifier ("_data%d_".printf (block_id)), "_data%d_".printf (parent_block_id)), new CCodeConstant ("NULL"));
			} else {
				if (in_constructor || (current_method != null && current_method.binding == MemberBinding.INSTANCE) ||
				           (current_property_accessor != null && current_property_accessor.prop.binding == MemberBinding.INSTANCE)) {
					var ma = new MemberAccess.simple ("this");
					ma.symbol_reference = current_class;
					ccode.add_expression (get_unref_expression (new CCodeMemberAccess.pointer (new CCodeIdentifier ("_data%d_".printf (block_id)), "self"), new ObjectType (current_class), ma));
				}
			}

			// free in reverse order
			for (int i = local_vars.size - 1; i >= 0; i--) {
				var local = local_vars[i];
				if (local.captured) {
					if (requires_destroy (local.variable_type)) {
						bool old_coroutine = false;
						if (current_method != null) {
							old_coroutine = current_method.coroutine;
							current_method.coroutine = false;
						}

						ccode.add_expression (destroy_variable (local));

						if (old_coroutine) {
							current_method.coroutine = true;
						}
					}
				}
			}

			if (b.parent_symbol is Method) {
				var m = (Method) b.parent_symbol;

				// parameters are captured with the top-level block of the method
				foreach (var param in m.get_parameters ()) {
					if (param.captured) {
						var param_type = param.variable_type.copy ();
						param_type.value_owned = true;

						bool is_unowned_delegate = param.variable_type is DelegateType && !param.variable_type.value_owned;

						if (requires_destroy (param_type) && !is_unowned_delegate) {
							bool old_coroutine = false;
							if (m != null) {
								old_coroutine = m.coroutine;
								m.coroutine = false;
							}

							ccode.add_expression (destroy_variable (param));

							if (old_coroutine) {
								m.coroutine = true;
							}
						}
					}
				}
			} else if (b.parent_symbol is PropertyAccessor) {
				var acc = (PropertyAccessor) b.parent_symbol;

				if (!acc.readable && acc.value_parameter.captured) {
					var param_type = acc.value_parameter.variable_type.copy ();
					param_type.value_owned = true;

					bool is_unowned_delegate = acc.value_parameter.variable_type is DelegateType && !acc.value_parameter.variable_type.value_owned;

					if (requires_destroy (param_type) && !is_unowned_delegate) {
						ccode.add_expression (destroy_variable (acc.value_parameter));
					}
				}
			}

			var data_free = new CCodeFunctionCall (new CCodeIdentifier ("g_slice_free"));
			data_free.add_argument (new CCodeIdentifier (struct_name));
			data_free.add_argument (new CCodeIdentifier ("_data%d_".printf (block_id)));
			ccode.add_expression (data_free);

			ccode.close ();

			pop_function ();

			cfile.add_function (unref_fun);
		}

		foreach (Statement stmt in b.get_statements ()) {
			stmt.emit (this);
		}

		// free in reverse order
		for (int i = local_vars.size - 1; i >= 0; i--) {
			var local = local_vars[i];
			local.active = false;
			if (!local.unreachable && !local.floating && !local.captured && requires_destroy (local.variable_type)) {
				ccode.add_expression (destroy_variable (local));
			}
		}

		if (b.parent_symbol is Method) {
			var m = (Method) b.parent_symbol;
			foreach (Parameter param in m.get_parameters ()) {
				if (!param.captured && !param.ellipsis && requires_destroy (param.variable_type) && param.direction == ParameterDirection.IN) {
					ccode.add_expression (destroy_variable (param));
				} else if (param.direction == ParameterDirection.OUT && !m.coroutine) {
					return_out_parameter (param);
				}
			}
		}

		if (b.captured) {
			int block_id = get_block_id (b);

			var data_unref = new CCodeFunctionCall (new CCodeIdentifier ("block%d_data_unref".printf (block_id)));
			data_unref.add_argument (get_variable_cexpression ("_data%d_".printf (block_id)));
			ccode.add_expression (data_unref);
			ccode.add_assignment (get_variable_cexpression ("_data%d_".printf (block_id)), new CCodeConstant ("NULL"));
		}

		if (b.parent_node is Block || b.parent_node is SwitchStatement) {
			ccode.close ();
		}

		emit_context.pop_symbol ();
	}

	public override void visit_declaration_statement (DeclarationStatement stmt) {
		stmt.declaration.accept (this);
	}

	public CCodeExpression get_variable_cexpression (string name) {
		if (is_in_coroutine ()) {
			return new CCodeMemberAccess.pointer (new CCodeIdentifier ("data"), get_variable_cname (name));
		} else {
			return new CCodeIdentifier (get_variable_cname (name));
		}
	}

	public string get_variable_cname (string name) {
		if (name[0] == '.') {
			if (name == ".result") {
				return "result";
			}
			// compiler-internal variable
			if (!variable_name_map.contains (name)) {
				variable_name_map.set (name, "_tmp%d_".printf (next_temp_var_id));
				next_temp_var_id++;
			}
			return variable_name_map.get (name);
		} else if (reserved_identifiers.contains (name)) {
			return "_%s_".printf (name);
		} else {
			return name;
		}
	}

	public CCodeExpression get_result_cexpression (string cname = "result") {
		if (is_in_coroutine ()) {
			return new CCodeMemberAccess.pointer (new CCodeIdentifier ("data"), cname);
		} else {
			return new CCodeIdentifier (cname);
		}
	}

	bool has_simple_struct_initializer (LocalVariable local) {
		var st = local.variable_type.data_type as Struct;
		var initializer = local.initializer as ObjectCreationExpression;
		if (st != null && (!st.is_simple_type () || st.get_cname () == "va_list") && !local.variable_type.nullable &&
		    initializer != null && initializer.get_object_initializer ().size == 0) {
			return true;
		} else {
			return false;
		}
	}

	public override void visit_local_variable (LocalVariable local) {
		check_type (local.variable_type);

		if (local.initializer != null) {
			local.initializer.emit (this);

			visit_end_full_expression (local.initializer);
		}

		generate_type_declaration (local.variable_type, cfile);

		CCodeExpression rhs = null;
		if (local.initializer != null && get_cvalue (local.initializer) != null) {
			rhs = get_cvalue (local.initializer);
		}

		if (!local.captured) {
			if (current_method != null && current_method.coroutine) {
				closure_struct.add_field (local.variable_type.get_cname (), get_variable_cname (local.name) + local.variable_type.get_cdeclarator_suffix ());
			} else {
				var cvar = new CCodeVariableDeclarator (get_variable_cname (local.name), null, local.variable_type.get_cdeclarator_suffix ());

				// try to initialize uninitialized variables
				// initialization not necessary for variables stored in closure
				if (rhs == null || has_simple_struct_initializer (local)) {
					cvar.initializer = default_value_for_type (local.variable_type, true);
					cvar.init0 = true;
				}

				ccode.add_declaration (local.variable_type.get_cname (), cvar);
			}

			if (local.variable_type is ArrayType) {
				// create variables to store array dimensions
				var array_type = (ArrayType) local.variable_type;

				if (!array_type.fixed_length) {
					for (int dim = 1; dim <= array_type.rank; dim++) {
						var len_var = new LocalVariable (int_type.copy (), get_array_length_cname (get_variable_cname (local.name), dim));
						emit_temp_var (len_var, local.initializer == null);
					}

					if (array_type.rank == 1) {
						var size_var = new LocalVariable (int_type.copy (), get_array_size_cname (get_variable_cname (local.name)));
						emit_temp_var (size_var, local.initializer == null);
					}
				}
			} else if (local.variable_type is DelegateType) {
				var deleg_type = (DelegateType) local.variable_type;
				var d = deleg_type.delegate_symbol;
				if (d.has_target) {
					// create variable to store delegate target
					var target_var = new LocalVariable (new PointerType (new VoidType ()), get_delegate_target_cname (get_variable_cname (local.name)));
					emit_temp_var (target_var, local.initializer == null);
					if (deleg_type.value_owned) {
						var target_destroy_notify_var = new LocalVariable (gdestroynotify_type, get_delegate_target_destroy_notify_cname (get_variable_cname (local.name)));
						emit_temp_var (target_destroy_notify_var, local.initializer == null);
					}
				}
			}
		}
	
		if (rhs != null) {
			if (!has_simple_struct_initializer (local)) {
				store_local (local, local.initializer.target_value, true);
			}
		}

		if (local.initializer != null && local.initializer.tree_can_fail) {
			add_simple_check (local.initializer);
		}

		local.active = true;
	}

	public override void visit_initializer_list (InitializerList list) {
		if (list.target_type.data_type is Struct) {
			/* initializer is used as struct initializer */
			var st = (Struct) list.target_type.data_type;

			if (list.parent_node is Constant || list.parent_node is Field || list.parent_node is InitializerList) {
				var clist = new CCodeInitializerList ();

				var field_it = st.get_fields ().iterator ();
				foreach (Expression expr in list.get_initializers ()) {
					Field field = null;
					while (field == null) {
						field_it.next ();
						field = field_it.get ();
						if (field.binding != MemberBinding.INSTANCE) {
							// we only initialize instance fields
							field = null;
						}
					}

					var cexpr = get_cvalue (expr);

					string ctype = field.get_ctype ();
					if (ctype != null) {
						cexpr = new CCodeCastExpression (cexpr, ctype);
					}

					clist.append (cexpr);
				}

				set_cvalue (list, clist);
			} else {
				// used as expression
				var temp_decl = get_temp_variable (list.target_type, false, list);
				emit_temp_var (temp_decl);

				var instance = get_variable_cexpression (get_variable_cname (temp_decl.name));

				var field_it = st.get_fields ().iterator ();
				foreach (Expression expr in list.get_initializers ()) {
					Field field = null;
					while (field == null) {
						field_it.next ();
						field = field_it.get ();
						if (field.binding != MemberBinding.INSTANCE) {
							// we only initialize instance fields
							field = null;
						}
					}

					var cexpr = get_cvalue (expr);

					string ctype = field.get_ctype ();
					if (ctype != null) {
						cexpr = new CCodeCastExpression (cexpr, ctype);
					}

					var lhs = new CCodeMemberAccess (instance, field.get_cname ());;
					ccode.add_assignment (lhs, cexpr);
				}

				set_cvalue (list, instance);
			}
		} else {
			var clist = new CCodeInitializerList ();
			foreach (Expression expr in list.get_initializers ()) {
				clist.append (get_cvalue (expr));
			}
			set_cvalue (list, clist);
		}
	}

	public override LocalVariable create_local (DataType type) {
		var result = get_temp_variable (type, type.value_owned);
		emit_temp_var (result);
		return result;
	}

	public LocalVariable get_temp_variable (DataType type, bool value_owned = true, CodeNode? node_reference = null, bool init = true) {
		var var_type = type.copy ();
		var_type.value_owned = value_owned;
		var local = new LocalVariable (var_type, "_tmp%d_".printf (next_temp_var_id));
		local.no_init = !init;

		if (node_reference != null) {
			local.source_reference = node_reference.source_reference;
		}

		next_temp_var_id++;
		
		return local;
	}

	bool is_in_generic_type (DataType type) {
		if (current_symbol != null && type.type_parameter.parent_symbol is TypeSymbol
		    && (current_method == null || current_method.binding == MemberBinding.INSTANCE)) {
			return true;
		} else {
			return false;
		}
	}

	public CCodeExpression get_type_id_expression (DataType type, bool is_chainup = false) {
		if (type is GenericType) {
			string var_name = "%s_type".printf (type.type_parameter.name.down ());
			if (is_in_generic_type (type) && !is_chainup && !in_creation_method) {
				return new CCodeMemberAccess.pointer (new CCodeMemberAccess.pointer (get_result_cexpression ("self"), "priv"), var_name);
			} else {
				return new CCodeIdentifier (var_name);
			}
		} else {
			string type_id = type.get_type_id ();
			if (type_id == null) {
				type_id = "G_TYPE_INVALID";
			} else {
				generate_type_declaration (type, cfile);
			}
			return new CCodeIdentifier (type_id);
		}
	}

	public virtual CCodeExpression? get_dup_func_expression (DataType type, SourceReference? source_reference, bool is_chainup = false) {
		if (type is ErrorType) {
			return new CCodeIdentifier ("g_error_copy");
		} else if (type.data_type != null) {
			string dup_function;
			var cl = type.data_type as Class;
			if (type.data_type.is_reference_counting ()) {
				dup_function = type.data_type.get_ref_function ();
				if (type.data_type is Interface && dup_function == null) {
					Report.error (source_reference, "missing class prerequisite for interface `%s', add GLib.Object to interface declaration if unsure".printf (type.data_type.get_full_name ()));
					return null;
				}
			} else if (cl != null && cl.is_immutable) {
				// allow duplicates of immutable instances as for example strings
				dup_function = type.data_type.get_dup_function ();
				if (dup_function == null) {
					dup_function = "";
				}
			} else if (cl != null && cl.is_gboxed) {
				// allow duplicates of gboxed instances
				dup_function = generate_dup_func_wrapper (type);
				if (dup_function == null) {
					dup_function = "";
				}
			} else if (type is ValueType) {
				dup_function = type.data_type.get_dup_function ();
				if (dup_function == null && type.nullable) {
					dup_function = generate_struct_dup_wrapper ((ValueType) type);
				} else if (dup_function == null) {
					dup_function = "";
				}
			} else {
				// duplicating non-reference counted objects may cause side-effects (and performance issues)
				Report.error (source_reference, "duplicating %s instance, use unowned variable or explicitly invoke copy method".printf (type.data_type.name));
				return null;
			}

			return new CCodeIdentifier (dup_function);
		} else if (type.type_parameter != null) {
			string func_name = "%s_dup_func".printf (type.type_parameter.name.down ());
			if (is_in_generic_type (type) && !is_chainup && !in_creation_method) {
				return new CCodeMemberAccess.pointer (new CCodeMemberAccess.pointer (get_result_cexpression ("self"), "priv"), func_name);
			} else {
				return new CCodeIdentifier (func_name);
			}
		} else if (type is PointerType) {
			var pointer_type = (PointerType) type;
			return get_dup_func_expression (pointer_type.base_type, source_reference);
		} else {
			return new CCodeConstant ("NULL");
		}
	}

	void make_comparable_cexpression (ref DataType left_type, ref CCodeExpression cleft, ref DataType right_type, ref CCodeExpression cright) {
		var left_type_as_struct = left_type.data_type as Struct;
		var right_type_as_struct = right_type.data_type as Struct;

		// GValue support
		var valuecast = try_cast_value_to_type (cleft, left_type, right_type);
		if (valuecast != null) {
			cleft = valuecast;
			left_type = right_type;
			make_comparable_cexpression (ref left_type, ref cleft, ref right_type, ref cright);
			return;
		}

		valuecast = try_cast_value_to_type (cright, right_type, left_type);
		if (valuecast != null) {
			cright = valuecast;
			right_type = left_type;
			make_comparable_cexpression (ref left_type, ref cleft, ref right_type, ref cright);
			return;
		}

		if (left_type.data_type is Class && !((Class) left_type.data_type).is_compact &&
		    right_type.data_type is Class && !((Class) right_type.data_type).is_compact) {
			var left_cl = (Class) left_type.data_type;
			var right_cl = (Class) right_type.data_type;

			if (left_cl != right_cl) {
				if (left_cl.is_subtype_of (right_cl)) {
					cleft = generate_instance_cast (cleft, right_cl);
				} else if (right_cl.is_subtype_of (left_cl)) {
					cright = generate_instance_cast (cright, left_cl);
				}
			}
		} else if (left_type_as_struct != null && right_type_as_struct != null) {
			if (left_type is StructValueType) {
				// real structs (uses compare/equal function)
				if (!left_type.nullable) {
					cleft = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cleft);
				}
				if (!right_type.nullable) {
					cright = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cright);
				}
			} else {
				// integer or floating or boolean type
				if (left_type.nullable && right_type.nullable) {
					// FIXME also compare contents, not just address
				} else if (left_type.nullable) {
					// FIXME check left value is not null
					cleft = new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, cleft);
				} else if (right_type.nullable) {
					// FIXME check right value is not null
					cright = new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, cright);
				}
			}
		}
	}

	private string generate_struct_equal_function (Struct st) {
		string equal_func = "_%sequal".printf (st.get_lower_case_cprefix ());

		if (!add_wrapper (equal_func)) {
			// wrapper already defined
			return equal_func;
		}

		var function = new CCodeFunction (equal_func, "gboolean");
		function.modifiers = CCodeModifiers.STATIC;

		function.add_parameter (new CCodeParameter ("s1", "const " + st.get_cname () + "*"));
		function.add_parameter (new CCodeParameter ("s2", "const " + st.get_cname () + "*"));

		push_function (function);

		// if (s1 == s2) return TRUE;
		{
			var cexp = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, new CCodeIdentifier ("s1"), new CCodeIdentifier ("s2"));
			ccode.open_if (cexp);
			ccode.add_return (new CCodeConstant ("TRUE"));
			ccode.close ();
		}
		// if (s1 == NULL || s2 == NULL) return FALSE;
		{
			var cexp = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, new CCodeIdentifier ("s1"), new CCodeConstant ("NULL"));
			ccode.open_if (cexp);
			ccode.add_return (new CCodeConstant ("FALSE"));
			ccode.close ();

			cexp = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, new CCodeIdentifier ("s2"), new CCodeConstant ("NULL"));
			ccode.open_if (cexp);
			ccode.add_return (new CCodeConstant ("FALSE"));
			ccode.close ();
		}

		foreach (Field f in st.get_fields ()) {
			if (f.binding != MemberBinding.INSTANCE) {
				// we only compare instance fields
				continue;
			}

			CCodeExpression cexp; // if (cexp) return FALSE;
			var s1 = (CCodeExpression) new CCodeMemberAccess.pointer (new CCodeIdentifier ("s1"), f.name); // s1->f
			var s2 = (CCodeExpression) new CCodeMemberAccess.pointer (new CCodeIdentifier ("s2"), f.name); // s2->f

			var variable_type = f.variable_type.copy ();
			make_comparable_cexpression (ref variable_type, ref s1, ref variable_type, ref s2);

			if (!(f.variable_type is NullType) && f.variable_type.compatible (string_type)) {
				var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_strcmp0"));
				ccall.add_argument (s1);
				ccall.add_argument (s2);
				cexp = ccall;
			} else if (f.variable_type is StructValueType) {
				var equalfunc = generate_struct_equal_function (f.variable_type.data_type as Struct);
				var ccall = new CCodeFunctionCall (new CCodeIdentifier (equalfunc));
				ccall.add_argument (s1);
				ccall.add_argument (s2);
				cexp = new CCodeUnaryExpression (CCodeUnaryOperator.LOGICAL_NEGATION, ccall);
			} else {
				cexp = new CCodeBinaryExpression (CCodeBinaryOperator.INEQUALITY, s1, s2);
			}

			ccode.open_if (cexp);
			ccode.add_return (new CCodeConstant ("FALSE"));
			ccode.close ();
		}

		if (st.get_fields().size == 0) {
			// either opaque structure or simple type
			if (st.is_simple_type ()) {
				var cexp = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier ("s1")), new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier ("s2")));
				ccode.add_return (cexp);
			} else {
				ccode.add_return (new CCodeConstant ("FALSE"));
			}
		} else {
			ccode.add_return (new CCodeConstant ("TRUE"));
		}

		pop_function ();

		cfile.add_function_declaration (function);
		cfile.add_function (function);

		return equal_func;
	}

	private string generate_numeric_equal_function (Struct st) {
		string equal_func = "_%sequal".printf (st.get_lower_case_cprefix ());

		if (!add_wrapper (equal_func)) {
			// wrapper already defined
			return equal_func;
		}

		var function = new CCodeFunction (equal_func, "gboolean");
		function.modifiers = CCodeModifiers.STATIC;

		function.add_parameter (new CCodeParameter ("s1", "const " + st.get_cname () + "*"));
		function.add_parameter (new CCodeParameter ("s2", "const " + st.get_cname () + "*"));

		push_function (function);

		// if (s1 == s2) return TRUE;
		{
			var cexp = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, new CCodeIdentifier ("s1"), new CCodeIdentifier ("s2"));
			ccode.open_if (cexp);
			ccode.add_return (new CCodeConstant ("TRUE"));
			ccode.close ();
		}
		// if (s1 == NULL || s2 == NULL) return FALSE;
		{
			var cexp = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, new CCodeIdentifier ("s1"), new CCodeConstant ("NULL"));
			ccode.open_if (cexp);
			ccode.add_return (new CCodeConstant ("FALSE"));
			ccode.close ();

			cexp = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, new CCodeIdentifier ("s2"), new CCodeConstant ("NULL"));
			ccode.open_if (cexp);
			ccode.add_return (new CCodeConstant ("FALSE"));
			ccode.close ();
		}
		// return (*s1 == *s2);
		{
			var cexp = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier ("s1")), new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier ("s2")));
			ccode.add_return (cexp);
		}

		pop_function ();

		cfile.add_function_declaration (function);
		cfile.add_function (function);

		return equal_func;
	}

	private string generate_struct_dup_wrapper (ValueType value_type) {
		string dup_func = "_%sdup".printf (value_type.type_symbol.get_lower_case_cprefix ());

		if (!add_wrapper (dup_func)) {
			// wrapper already defined
			return dup_func;
		}

		var function = new CCodeFunction (dup_func, value_type.get_cname ());
		function.modifiers = CCodeModifiers.STATIC;

		function.add_parameter (new CCodeParameter ("self", value_type.get_cname ()));

		push_function (function);

		if (value_type.type_symbol == gvalue_type) {
			var dup_call = new CCodeFunctionCall (new CCodeIdentifier ("g_boxed_copy"));
			dup_call.add_argument (new CCodeIdentifier ("G_TYPE_VALUE"));
			dup_call.add_argument (new CCodeIdentifier ("self"));

			ccode.add_return (dup_call);
		} else {
			ccode.add_declaration (value_type.get_cname (), new CCodeVariableDeclarator ("dup"));

			var creation_call = new CCodeFunctionCall (new CCodeIdentifier ("g_new0"));
			creation_call.add_argument (new CCodeConstant (value_type.data_type.get_cname ()));
			creation_call.add_argument (new CCodeConstant ("1"));
			ccode.add_assignment (new CCodeIdentifier ("dup"), creation_call);

			var st = value_type.data_type as Struct;
			if (st != null && st.is_disposable ()) {
				if (!st.has_copy_function) {
					generate_struct_copy_function (st);
				}

				var copy_call = new CCodeFunctionCall (new CCodeIdentifier (st.get_copy_function ()));
				copy_call.add_argument (new CCodeIdentifier ("self"));
				copy_call.add_argument (new CCodeIdentifier ("dup"));
				ccode.add_expression (copy_call);
			} else {
				cfile.add_include ("string.h");

				var sizeof_call = new CCodeFunctionCall (new CCodeIdentifier ("sizeof"));
				sizeof_call.add_argument (new CCodeConstant (value_type.data_type.get_cname ()));

				var copy_call = new CCodeFunctionCall (new CCodeIdentifier ("memcpy"));
				copy_call.add_argument (new CCodeIdentifier ("dup"));
				copy_call.add_argument (new CCodeIdentifier ("self"));
				copy_call.add_argument (sizeof_call);
				ccode.add_expression (copy_call);
			}

			ccode.add_return (new CCodeIdentifier ("dup"));
		}

		pop_function ();

		cfile.add_function_declaration (function);
		cfile.add_function (function);

		return dup_func;
	}

	protected string generate_dup_func_wrapper (DataType type) {
		string destroy_func = "_vala_%s_copy".printf (type.data_type.get_cname ());

		if (!add_wrapper (destroy_func)) {
			// wrapper already defined
			return destroy_func;
		}

		var function = new CCodeFunction (destroy_func, type.get_cname ());
		function.modifiers = CCodeModifiers.STATIC;
		function.add_parameter (new CCodeParameter ("self", type.get_cname ()));

		push_function (function);

		var cl = type.data_type as Class;
		assert (cl != null && cl.is_gboxed);

		var free_call = new CCodeFunctionCall (new CCodeIdentifier ("g_boxed_copy"));
		free_call.add_argument (new CCodeIdentifier (cl.get_type_id ()));
		free_call.add_argument (new CCodeIdentifier ("self"));

		ccode.add_return (free_call);

		pop_function ();

		cfile.add_function_declaration (function);
		cfile.add_function (function);

		return destroy_func;
	}

	protected string generate_free_func_wrapper (DataType type) {
		string destroy_func = "_vala_%s_free".printf (type.data_type.get_cname ());

		if (!add_wrapper (destroy_func)) {
			// wrapper already defined
			return destroy_func;
		}

		var function = new CCodeFunction (destroy_func, "void");
		function.modifiers = CCodeModifiers.STATIC;
		function.add_parameter (new CCodeParameter ("self", type.get_cname ()));

		push_function (function);

		var cl = type.data_type as Class;
		if (cl != null && cl.is_gboxed) {
			var free_call = new CCodeFunctionCall (new CCodeIdentifier ("g_boxed_free"));
			free_call.add_argument (new CCodeIdentifier (cl.get_type_id ()));
			free_call.add_argument (new CCodeIdentifier ("self"));

			ccode.add_expression (free_call);
		} else if (cl != null) {
			assert (cl.free_function_address_of);

			var free_call = new CCodeFunctionCall (new CCodeIdentifier (type.data_type.get_free_function ()));
			free_call.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, new CCodeIdentifier ("self")));

			ccode.add_expression (free_call);
		} else {
			var st = type.data_type as Struct;
			if (st != null && st.is_disposable ()) {
				if (!st.has_destroy_function) {
					generate_struct_destroy_function (st);
				}

				var destroy_call = new CCodeFunctionCall (new CCodeIdentifier (st.get_destroy_function ()));
				destroy_call.add_argument (new CCodeIdentifier ("self"));
				ccode.add_expression (destroy_call);
			}

			var free_call = new CCodeFunctionCall (new CCodeIdentifier ("g_free"));
			free_call.add_argument (new CCodeIdentifier ("self"));

			ccode.add_expression (free_call);
		}

		pop_function ();

		cfile.add_function_declaration (function);
		cfile.add_function (function);

		return destroy_func;
	}

	public CCodeExpression? get_destroy0_func_expression (DataType type, bool is_chainup = false) {
		var element_destroy_func_expression = get_destroy_func_expression (type, is_chainup);

		if (element_destroy_func_expression is CCodeIdentifier) {
			var freeid = (CCodeIdentifier) element_destroy_func_expression;
			string free0_func = "_%s0_".printf (freeid.name);

			if (add_wrapper (free0_func)) {
				var function = new CCodeFunction (free0_func, "void");
				function.modifiers = CCodeModifiers.STATIC;

				function.add_parameter (new CCodeParameter ("var", "gpointer"));

				push_function (function);

				ccode.add_expression (get_unref_expression (new CCodeIdentifier ("var"), type, null, true));

				pop_function ();

				cfile.add_function_declaration (function);
				cfile.add_function (function);
			}

			element_destroy_func_expression = new CCodeIdentifier (free0_func);
		}

		return element_destroy_func_expression;
	}

	public CCodeExpression? get_destroy_func_expression (DataType type, bool is_chainup = false) {
		if (context.profile == Profile.GOBJECT && (type.data_type == glist_type || type.data_type == gslist_type || type.data_type == gnode_type)) {
			// create wrapper function to free list elements if necessary

			bool elements_require_free = false;
			CCodeExpression element_destroy_func_expression = null;

			foreach (DataType type_arg in type.get_type_arguments ()) {
				elements_require_free = requires_destroy (type_arg);
				if (elements_require_free) {
					element_destroy_func_expression = get_destroy0_func_expression (type_arg);
				}
			}
			
			if (elements_require_free && element_destroy_func_expression is CCodeIdentifier) {
				return new CCodeIdentifier (generate_collection_free_wrapper (type, (CCodeIdentifier) element_destroy_func_expression));
			} else {
				return new CCodeIdentifier (type.data_type.get_free_function ());
			}
		} else if (type is ErrorType) {
			return new CCodeIdentifier ("g_error_free");
		} else if (type.data_type != null) {
			string unref_function;
			if (type is ReferenceType) {
				if (type.data_type.is_reference_counting ()) {
					unref_function = type.data_type.get_unref_function ();
					if (type.data_type is Interface && unref_function == null) {
						Report.error (type.source_reference, "missing class prerequisite for interface `%s', add GLib.Object to interface declaration if unsure".printf (type.data_type.get_full_name ()));
						return null;
					}
				} else {
					var cl = type.data_type as Class;
					if (cl != null && (cl.free_function_address_of || cl.is_gboxed)) {
						unref_function = generate_free_func_wrapper (type);
					} else {
						unref_function = type.data_type.get_free_function ();
					}
				}
			} else {
				if (type.nullable) {
					unref_function = type.data_type.get_free_function ();
					if (unref_function == null) {
						if (type.data_type is Struct && ((Struct) type.data_type).is_disposable ()) {
							unref_function = generate_free_func_wrapper (type);
						} else {
							unref_function = "g_free";
						}
					}
				} else {
					var st = (Struct) type.data_type;
					if (!st.has_destroy_function) {
						generate_struct_destroy_function (st);
					}
					unref_function = st.get_destroy_function ();
				}
			}
			if (unref_function == null) {
				return new CCodeConstant ("NULL");
			}
			return new CCodeIdentifier (unref_function);
		} else if (type.type_parameter != null && current_type_symbol is Class) {
			string func_name = "%s_destroy_func".printf (type.type_parameter.name.down ());
			if (is_in_generic_type (type) && !is_chainup && !in_creation_method) {
				return new CCodeMemberAccess.pointer (new CCodeMemberAccess.pointer (get_result_cexpression ("self"), "priv"), func_name);
			} else {
				return new CCodeIdentifier (func_name);
			}
		} else if (type is ArrayType) {
			if (context.profile == Profile.POSIX) {
				return new CCodeIdentifier ("free");
			} else {
				return new CCodeIdentifier ("g_free");
			}
		} else if (type is PointerType) {
			if (context.profile == Profile.POSIX) {
				return new CCodeIdentifier ("free");
			} else {
				return new CCodeIdentifier ("g_free");
			}
		} else {
			return new CCodeConstant ("NULL");
		}
	}

	private string generate_collection_free_wrapper (DataType collection_type, CCodeIdentifier element_destroy_func_expression) {
		string destroy_func = "_%s_%s".printf (collection_type.data_type.get_free_function (), element_destroy_func_expression.name);

		if (!add_wrapper (destroy_func)) {
			// wrapper already defined
			return destroy_func;
		}

		var function = new CCodeFunction (destroy_func, "void");
		function.modifiers = CCodeModifiers.STATIC;

		function.add_parameter (new CCodeParameter ("self", collection_type.get_cname ()));

		push_function (function);

		CCodeFunctionCall element_free_call;
		if (collection_type.data_type == gnode_type) {
			/* A wrapper which converts GNodeTraverseFunc into GDestroyNotify */
			string destroy_node_func = "%s_node".printf (destroy_func);
			var wrapper = new CCodeFunction (destroy_node_func, "gboolean");
			wrapper.modifiers = CCodeModifiers.STATIC;
			wrapper.add_parameter (new CCodeParameter ("node", collection_type.get_cname ()));
			wrapper.add_parameter (new CCodeParameter ("unused", "gpointer"));
			var wrapper_block = new CCodeBlock ();
			var free_call = new CCodeFunctionCall (element_destroy_func_expression);
			free_call.add_argument (new CCodeMemberAccess.pointer(new CCodeIdentifier("node"), "data"));
			wrapper_block.add_statement (new CCodeExpressionStatement (free_call));
			wrapper_block.add_statement (new CCodeReturnStatement (new CCodeConstant ("FALSE")));
			cfile.add_function_declaration (function);
			wrapper.block = wrapper_block;
			cfile.add_function (wrapper);

			/* Now the code to call g_traverse with the above */
			element_free_call = new CCodeFunctionCall (new CCodeIdentifier ("g_node_traverse"));
			element_free_call.add_argument (new CCodeIdentifier("self"));
			element_free_call.add_argument (new CCodeConstant ("G_POST_ORDER"));
			element_free_call.add_argument (new CCodeConstant ("G_TRAVERSE_ALL"));
			element_free_call.add_argument (new CCodeConstant ("-1"));
			element_free_call.add_argument (new CCodeIdentifier (destroy_node_func));
			element_free_call.add_argument (new CCodeConstant ("NULL"));
		} else {
			if (collection_type.data_type == glist_type) {
				element_free_call = new CCodeFunctionCall (new CCodeIdentifier ("g_list_foreach"));
			} else {
				element_free_call = new CCodeFunctionCall (new CCodeIdentifier ("g_slist_foreach"));
			}

			element_free_call.add_argument (new CCodeIdentifier ("self"));
			element_free_call.add_argument (new CCodeCastExpression (element_destroy_func_expression, "GFunc"));
			element_free_call.add_argument (new CCodeConstant ("NULL"));
		}

		ccode.add_expression (element_free_call);

		var cfreecall = new CCodeFunctionCall (new CCodeIdentifier (collection_type.data_type.get_free_function ()));
		cfreecall.add_argument (new CCodeIdentifier ("self"));
		ccode.add_expression (cfreecall);

		pop_function ();

		cfile.add_function_declaration (function);
		cfile.add_function (function);

		return destroy_func;
	}

	public virtual string? append_struct_array_free (Struct st) {
		return null;
	}

	// logic in this method is temporarily duplicated in destroy_value
	// apply changes to both methods
	public virtual CCodeExpression destroy_variable (Variable variable, CCodeExpression? inner = null) {
		var type = variable.variable_type;
		var target_lvalue = get_variable_cvalue (variable, inner);
		var cvar = get_cvalue_ (target_lvalue);

		if (type is DelegateType) {
			var delegate_target = get_delegate_target_cvalue (target_lvalue);
			var delegate_target_destroy_notify = get_delegate_target_destroy_notify_cvalue (target_lvalue);

			var ccall = new CCodeFunctionCall (delegate_target_destroy_notify);
			ccall.add_argument (delegate_target);

			var destroy_call = new CCodeCommaExpression ();
			destroy_call.append_expression (ccall);
			destroy_call.append_expression (new CCodeConstant ("NULL"));

			var cisnull = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, delegate_target_destroy_notify, new CCodeConstant ("NULL"));

			var ccomma = new CCodeCommaExpression ();
			ccomma.append_expression (new CCodeConditionalExpression (cisnull, new CCodeConstant ("NULL"), destroy_call));
			ccomma.append_expression (new CCodeAssignment (cvar, new CCodeConstant ("NULL")));
			ccomma.append_expression (new CCodeAssignment (delegate_target, new CCodeConstant ("NULL")));
			ccomma.append_expression (new CCodeAssignment (delegate_target_destroy_notify, new CCodeConstant ("NULL")));

			return ccomma;
		}

		var ccall = new CCodeFunctionCall (get_destroy_func_expression (type));

		if (type is ValueType && !type.nullable) {
			// normal value type, no null check
			var st = type.data_type as Struct;
			if (st != null && st.is_simple_type ()) {
				// used for va_list
				ccall.add_argument (cvar);
			} else {
				ccall.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cvar));
			}

			if (gvalue_type != null && type.data_type == gvalue_type) {
				// g_value_unset must not be called for already unset values
				var cisvalid = new CCodeFunctionCall (new CCodeIdentifier ("G_IS_VALUE"));
				cisvalid.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cvar));

				var ccomma = new CCodeCommaExpression ();
				ccomma.append_expression (ccall);
				ccomma.append_expression (new CCodeConstant ("NULL"));

				return new CCodeConditionalExpression (cisvalid, ccomma, new CCodeConstant ("NULL"));
			} else {
				return ccall;
			}
		}

		if (ccall.call is CCodeIdentifier && !(type is ArrayType)) {
			// generate and use NULL-aware free macro to simplify code

			var freeid = (CCodeIdentifier) ccall.call;
			string free0_func = "_%s0".printf (freeid.name);

			if (add_wrapper (free0_func)) {
				var macro = destroy_value (new GLibValue (type, new CCodeIdentifier ("var")), true);
				cfile.add_type_declaration (new CCodeMacroReplacement.with_expression ("%s(var)".printf (free0_func), macro));
			}

			ccall = new CCodeFunctionCall (new CCodeIdentifier (free0_func));
			ccall.add_argument (cvar);
			return ccall;
		}

		/* (foo == NULL ? NULL : foo = (unref (foo), NULL)) */

		/* can be simplified to
		 * foo = (unref (foo), NULL)
		 * if foo is of static type non-null
		 */

		var cisnull = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, cvar, new CCodeConstant ("NULL"));
		if (type.type_parameter != null) {
			if (!(current_type_symbol is Class) || current_class.is_compact) {
				return new CCodeConstant ("NULL");
			}

			// unref functions are optional for type parameters
			var cunrefisnull = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, get_destroy_func_expression (type), new CCodeConstant ("NULL"));
			cisnull = new CCodeBinaryExpression (CCodeBinaryOperator.OR, cisnull, cunrefisnull);
		}

		ccall.add_argument (cvar);

		/* set freed references to NULL to prevent further use */
		var ccomma = new CCodeCommaExpression ();

		if (context.profile == Profile.GOBJECT) {
			if (type.data_type != null && !type.data_type.is_reference_counting () &&
			    (type.data_type == gstringbuilder_type
			     || type.data_type == garray_type
			     || type.data_type == gbytearray_type
			     || type.data_type == gptrarray_type)) {
				ccall.add_argument (new CCodeConstant ("TRUE"));
			} else if (type.data_type == gthreadpool_type) {
				ccall.add_argument (new CCodeConstant ("FALSE"));
				ccall.add_argument (new CCodeConstant ("TRUE"));
			} else if (type is ArrayType) {
				var array_type = (ArrayType) type;
				if (requires_destroy (array_type.element_type) && !variable.no_array_length) {
					CCodeExpression csizeexpr = null;
					TargetValue access_value = null;
					if (variable is LocalVariable) {
						access_value = load_local ((LocalVariable) variable);
					} else if (variable is Parameter) {
						access_value = load_parameter ((Parameter) variable);
					}
					bool first = true;
					for (int dim = 1; dim <= array_type.rank; dim++) {
						if (first) {
							csizeexpr = get_array_length_cvalue (access_value, dim);
							first = false;
						} else {
							csizeexpr = new CCodeBinaryExpression (CCodeBinaryOperator.MUL, csizeexpr, get_array_length_cvalue (access_value, dim));
						}
					}

					var st = array_type.element_type.data_type as Struct;
					if (st != null && !array_type.element_type.nullable) {
						ccall.call = new CCodeIdentifier (append_struct_array_free (st));
						ccall.add_argument (csizeexpr);
					} else {
						requires_array_free = true;
						ccall.call = new CCodeIdentifier ("_vala_array_free");
						ccall.add_argument (csizeexpr);
						ccall.add_argument (new CCodeCastExpression (get_destroy_func_expression (array_type.element_type), "GDestroyNotify"));
					}
				}
			}
		}

		ccomma.append_expression (ccall);
		ccomma.append_expression (new CCodeConstant ("NULL"));

		var cassign = new CCodeAssignment (cvar, ccomma);

		// g_free (NULL) is allowed
		bool uses_gfree = (type.data_type != null && !type.data_type.is_reference_counting () && type.data_type.get_free_function () == "g_free");
		uses_gfree = uses_gfree || type is ArrayType;
		if (uses_gfree) {
			return cassign;
		}

		return new CCodeConditionalExpression (cisnull, new CCodeConstant ("NULL"), cassign);
	}

	public CCodeExpression get_unref_expression (CCodeExpression cvar, DataType type, Expression? expr, bool is_macro_definition = false) {
		if (expr != null && (expr.symbol_reference is LocalVariable || expr.symbol_reference is Parameter)) {
			return destroy_variable ((Variable) expr.symbol_reference);
		}
		var value = new GLibValue (type, cvar);
		if (expr != null && expr.target_value != null) {
			value.array_length_cvalues = ((GLibValue) expr.target_value).array_length_cvalues;
			value.delegate_target_cvalue = get_delegate_target_cvalue (expr.target_value);
			value.delegate_target_destroy_notify_cvalue = get_delegate_target_destroy_notify_cvalue (expr.target_value);
		}
		return destroy_value (value, is_macro_definition);
	}

	// logic in this method is temporarily duplicated in destroy_variable
	// apply changes to both methods
	public virtual CCodeExpression destroy_value (TargetValue value, bool is_macro_definition = false) {
		var type = value.value_type;
		var cvar = get_cvalue_ (value);

		if (type is DelegateType) {
			var delegate_target = get_delegate_target_cvalue (value);
			var delegate_target_destroy_notify = get_delegate_target_destroy_notify_cvalue (value);

			var ccall = new CCodeFunctionCall (delegate_target_destroy_notify);
			ccall.add_argument (delegate_target);

			var destroy_call = new CCodeCommaExpression ();
			destroy_call.append_expression (ccall);
			destroy_call.append_expression (new CCodeConstant ("NULL"));

			var cisnull = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, delegate_target_destroy_notify, new CCodeConstant ("NULL"));

			var ccomma = new CCodeCommaExpression ();
			ccomma.append_expression (new CCodeConditionalExpression (cisnull, new CCodeConstant ("NULL"), destroy_call));
			ccomma.append_expression (new CCodeAssignment (cvar, new CCodeConstant ("NULL")));
			ccomma.append_expression (new CCodeAssignment (delegate_target, new CCodeConstant ("NULL")));
			ccomma.append_expression (new CCodeAssignment (delegate_target_destroy_notify, new CCodeConstant ("NULL")));

			return ccomma;
		}

		var ccall = new CCodeFunctionCall (get_destroy_func_expression (type));

		if (type is ValueType && !type.nullable) {
			// normal value type, no null check
			var st = type.data_type as Struct;
			if (st != null && st.is_simple_type ()) {
				// used for va_list
				ccall.add_argument (cvar);
			} else {
				ccall.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cvar));
			}

			if (gvalue_type != null && type.data_type == gvalue_type) {
				// g_value_unset must not be called for already unset values
				var cisvalid = new CCodeFunctionCall (new CCodeIdentifier ("G_IS_VALUE"));
				cisvalid.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cvar));

				var ccomma = new CCodeCommaExpression ();
				ccomma.append_expression (ccall);
				ccomma.append_expression (new CCodeConstant ("NULL"));

				return new CCodeConditionalExpression (cisvalid, ccomma, new CCodeConstant ("NULL"));
			} else {
				return ccall;
			}
		}

		if (ccall.call is CCodeIdentifier && !(type is ArrayType) && !is_macro_definition) {
			// generate and use NULL-aware free macro to simplify code

			var freeid = (CCodeIdentifier) ccall.call;
			string free0_func = "_%s0".printf (freeid.name);

			if (add_wrapper (free0_func)) {
				var macro = destroy_value (new GLibValue (type, new CCodeIdentifier ("var")), true);
				cfile.add_type_declaration (new CCodeMacroReplacement.with_expression ("%s(var)".printf (free0_func), macro));
			}

			ccall = new CCodeFunctionCall (new CCodeIdentifier (free0_func));
			ccall.add_argument (cvar);
			return ccall;
		}

		/* (foo == NULL ? NULL : foo = (unref (foo), NULL)) */
		
		/* can be simplified to
		 * foo = (unref (foo), NULL)
		 * if foo is of static type non-null
		 */

		var cisnull = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, cvar, new CCodeConstant ("NULL"));
		if (type.type_parameter != null) {
			if (!(current_type_symbol is Class) || current_class.is_compact) {
				return new CCodeConstant ("NULL");
			}

			// unref functions are optional for type parameters
			var cunrefisnull = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, get_destroy_func_expression (type), new CCodeConstant ("NULL"));
			cisnull = new CCodeBinaryExpression (CCodeBinaryOperator.OR, cisnull, cunrefisnull);
		}

		ccall.add_argument (cvar);

		/* set freed references to NULL to prevent further use */
		var ccomma = new CCodeCommaExpression ();

		if (context.profile == Profile.GOBJECT) {
			if (type.data_type != null && !type.data_type.is_reference_counting () &&
			    (type.data_type == gstringbuilder_type
			     || type.data_type == garray_type
			     || type.data_type == gbytearray_type
			     || type.data_type == gptrarray_type)) {
				ccall.add_argument (new CCodeConstant ("TRUE"));
			} else if (type.data_type == gthreadpool_type) {
				ccall.add_argument (new CCodeConstant ("FALSE"));
				ccall.add_argument (new CCodeConstant ("TRUE"));
			} else if (type is ArrayType) {
				var array_type = (ArrayType) type;
				if (requires_destroy (array_type.element_type)) {
					CCodeExpression csizeexpr = null;
					bool first = true;
					for (int dim = 1; dim <= array_type.rank; dim++) {
						if (first) {
							csizeexpr = get_array_length_cvalue (value, dim);
							first = false;
						} else {
							csizeexpr = new CCodeBinaryExpression (CCodeBinaryOperator.MUL, csizeexpr, get_array_length_cvalue (value, dim));
						}
					}

					var st = array_type.element_type.data_type as Struct;
					if (st != null && !array_type.element_type.nullable) {
						ccall.call = new CCodeIdentifier (append_struct_array_free (st));
						ccall.add_argument (csizeexpr);
					} else {
						requires_array_free = true;
						ccall.call = new CCodeIdentifier ("_vala_array_free");
						ccall.add_argument (csizeexpr);
						ccall.add_argument (new CCodeCastExpression (get_destroy_func_expression (array_type.element_type), "GDestroyNotify"));
					}
				}
			}
		}
		
		ccomma.append_expression (ccall);
		ccomma.append_expression (new CCodeConstant ("NULL"));
		
		var cassign = new CCodeAssignment (cvar, ccomma);

		// g_free (NULL) is allowed
		bool uses_gfree = (type.data_type != null && !type.data_type.is_reference_counting () && type.data_type.get_free_function () == "g_free");
		uses_gfree = uses_gfree || type is ArrayType;
		if (uses_gfree) {
			return cassign;
		}

		return new CCodeConditionalExpression (cisnull, new CCodeConstant ("NULL"), cassign);
	}
	
	public override void visit_end_full_expression (Expression expr) {
		/* expr is a full expression, i.e. an initializer, the
		 * expression in an expression statement, the controlling
		 * expression in if, while, for, or foreach statements
		 *
		 * we unref temporary variables at the end of a full
		 * expression
		 */
		if (temp_ref_vars.size == 0) {
			/* nothing to do without temporary variables */
			return;
		}

		LocalVariable full_expr_var = null;

		var local_decl = expr.parent_node as LocalVariable;
		if (!(local_decl != null && has_simple_struct_initializer (local_decl))) {
			var expr_type = expr.value_type;
			if (expr.target_type != null) {
				expr_type = expr.target_type;
			}

			full_expr_var = get_temp_variable (expr_type, true, expr, false);
			emit_temp_var (full_expr_var);
		
			ccode.add_assignment (get_variable_cexpression (full_expr_var.name), get_cvalue (expr));
		}
		
		foreach (LocalVariable local in temp_ref_vars) {
			ccode.add_expression (destroy_variable (local));
		}

		if (full_expr_var != null) {
			set_cvalue (expr, get_variable_cexpression (full_expr_var.name));
		}

		temp_ref_vars.clear ();
	}
	
	public void emit_temp_var (LocalVariable local, bool always_init = false) {
		var vardecl = new CCodeVariableDeclarator (local.name, null, local.variable_type.get_cdeclarator_suffix ());

		var st = local.variable_type.data_type as Struct;
		var array_type = local.variable_type as ArrayType;

		if (local.name.has_prefix ("*")) {
			// do not dereference unintialized variable
			// initialization is not needed for these special
			// pointer temp variables
			// used to avoid side-effects in assignments
		} else if (local.no_init) {
			// no initialization necessary for this temp var
		} else if (!local.variable_type.nullable &&
		           (st != null && !st.is_simple_type ()) ||
		           (array_type != null && array_type.fixed_length)) {
			// 0-initialize struct with struct initializer { 0 }
			// necessary as they will be passed by reference
			var clist = new CCodeInitializerList ();
			clist.append (new CCodeConstant ("0"));

			vardecl.initializer = clist;
			vardecl.init0 = true;
		} else if (local.variable_type.is_reference_type_or_type_parameter () ||
		           local.variable_type.nullable ||
		           local.variable_type is DelegateType) {
			vardecl.initializer = new CCodeConstant ("NULL");
			vardecl.init0 = true;
		} else if (always_init) {
			vardecl.initializer = default_value_for_type (local.variable_type, true);
			vardecl.init0 = true;
		}

		if (is_in_coroutine ()) {
			closure_struct.add_field (local.variable_type.get_cname (), local.name);

			// even though closure struct is zerod, we need to initialize temporary variables
			// as they might be used multiple times when declared in a loop

			if (vardecl.initializer  is CCodeInitializerList) {
				// C does not support initializer lists in assignments, use memset instead
				cfile.add_include ("string.h");
				var memset_call = new CCodeFunctionCall (new CCodeIdentifier ("memset"));
				memset_call.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, get_variable_cexpression (local.name)));
				memset_call.add_argument (new CCodeConstant ("0"));
				memset_call.add_argument (new CCodeIdentifier ("sizeof (%s)".printf (local.variable_type.get_cname ())));
				ccode.add_expression (memset_call);
			} else if (vardecl.initializer != null) {
				ccode.add_assignment (get_variable_cexpression (local.name), vardecl.initializer);
			}
		} else {
			ccode.add_declaration (local.variable_type.get_cname (), vardecl);
		}
	}

	public override void visit_expression_statement (ExpressionStatement stmt) {
		if (stmt.expression.error) {
			stmt.error = true;
			return;
		}

		/* free temporary objects and handle errors */

		foreach (LocalVariable local in temp_ref_vars) {
			ccode.add_expression (destroy_variable (local));
		}

		if (stmt.tree_can_fail && stmt.expression.tree_can_fail) {
			// simple case, no node breakdown necessary
			add_simple_check (stmt.expression);
		}

		temp_ref_vars.clear ();
	}

	public virtual void append_local_free (Symbol sym, bool stop_at_loop = false, CodeNode? stop_at = null) {
		var b = (Block) sym;

		var local_vars = b.get_local_variables ();
		// free in reverse order
		for (int i = local_vars.size - 1; i >= 0; i--) {
			var local = local_vars[i];
			if (!local.unreachable && local.active && !local.floating && !local.captured && requires_destroy (local.variable_type)) {
				ccode.add_expression (destroy_variable (local));
			}
		}

		if (b.captured) {
			int block_id = get_block_id (b);

			var data_unref = new CCodeFunctionCall (new CCodeIdentifier ("block%d_data_unref".printf (block_id)));
			data_unref.add_argument (get_variable_cexpression ("_data%d_".printf (block_id)));
			ccode.add_expression (data_unref);
			ccode.add_assignment (get_variable_cexpression ("_data%d_".printf (block_id)), new CCodeConstant ("NULL"));
		}

		if (stop_at_loop) {
			if (b.parent_node is Loop ||
			    b.parent_node is ForeachStatement ||
			    b.parent_node is SwitchStatement) {
				return;
			}
		}

		if (b.parent_node == stop_at) {
			return;
		}

		if (sym.parent_symbol is Block) {
			append_local_free (sym.parent_symbol, stop_at_loop, stop_at);
		} else if (sym.parent_symbol is Method) {
			append_param_free ((Method) sym.parent_symbol);
		}
	}

	private void append_param_free (Method m) {
		foreach (Parameter param in m.get_parameters ()) {
			if (!param.ellipsis && requires_destroy (param.variable_type) && param.direction == ParameterDirection.IN) {
				ccode.add_expression (destroy_variable (param));
			}
		}
	}

	public bool variable_accessible_in_finally (LocalVariable local) {
		if (current_try == null) {
			return false;
		}

		var sym = current_symbol;

		while (!(sym is Method || sym is PropertyAccessor) && sym.scope.lookup (local.name) == null) {
			if ((sym.parent_node is TryStatement && ((TryStatement) sym.parent_node).finally_body != null) ||
				(sym.parent_node is CatchClause && ((TryStatement) sym.parent_node.parent_node).finally_body != null)) {

				return true;
			}

			sym = sym.parent_symbol;
		}

		return false;
	}

	void return_out_parameter (Parameter param) {
		var delegate_type = param.variable_type as DelegateType;

		ccode.open_if (get_variable_cexpression (param.name));
		ccode.add_assignment (new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, get_variable_cexpression (param.name)), get_variable_cexpression ("_" + param.name));

		if (delegate_type != null && delegate_type.delegate_symbol.has_target) {
			ccode.add_assignment (new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, get_variable_cexpression (get_delegate_target_cname (param.name))), new CCodeIdentifier (get_delegate_target_cname (get_variable_cname ("_" + param.name))));
			if (delegate_type.value_owned) {
				ccode.add_assignment (new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, get_variable_cexpression (get_delegate_target_destroy_notify_cname (param.name))), new CCodeIdentifier (get_delegate_target_destroy_notify_cname (get_variable_cname ("_" + param.name))));
			}
		}

		if (param.variable_type.is_disposable ()){
			ccode.add_else ();
			ccode.add_expression (destroy_variable (param));
		}
		ccode.close ();

		var array_type = param.variable_type as ArrayType;
		if (array_type != null && !array_type.fixed_length && !param.no_array_length) {
			for (int dim = 1; dim <= array_type.rank; dim++) {
				ccode.open_if (get_variable_cexpression (get_parameter_array_length_cname (param, dim)));
				ccode.add_assignment (new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, get_variable_cexpression (get_parameter_array_length_cname (param, dim))), new CCodeIdentifier (get_array_length_cname (get_variable_cname ("_" + param.name), dim)));
				ccode.close ();
			}
		}
	}

	public override void visit_return_statement (ReturnStatement stmt) {
		Symbol return_expression_symbol = null;

		if (stmt.return_expression != null) {
			// avoid unnecessary ref/unref pair
			var local = stmt.return_expression.symbol_reference as LocalVariable;
			if (current_return_type.value_owned
			    && local != null && local.variable_type.value_owned
			    && !local.captured
			    && !variable_accessible_in_finally (local)) {
				/* return expression is local variable taking ownership and
				 * current method is transferring ownership */

				return_expression_symbol = local;
			}
		}

		// return array length if appropriate
		if (((current_method != null && !current_method.no_array_length) || current_property_accessor != null) && current_return_type is ArrayType) {
			var return_expr_decl = get_temp_variable (stmt.return_expression.value_type, true, stmt, false);

			ccode.add_assignment (get_variable_cexpression (return_expr_decl.name), get_cvalue (stmt.return_expression));

			var array_type = (ArrayType) current_return_type;

			for (int dim = 1; dim <= array_type.rank; dim++) {
				var len_l = get_result_cexpression (get_array_length_cname ("result", dim));
				if (!is_in_coroutine ()) {
					len_l = new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, len_l);
				}
				var len_r = get_array_length_cexpression (stmt.return_expression, dim);
				ccode.add_assignment (len_l, len_r);
			}

			set_cvalue (stmt.return_expression, get_variable_cexpression (return_expr_decl.name));

			emit_temp_var (return_expr_decl);
		} else if ((current_method != null || current_property_accessor != null) && current_return_type is DelegateType) {
			var delegate_type = (DelegateType) current_return_type;
			if (delegate_type.delegate_symbol.has_target) {
				var return_expr_decl = get_temp_variable (stmt.return_expression.value_type, true, stmt, false);

				ccode.add_assignment (get_variable_cexpression (return_expr_decl.name), get_cvalue (stmt.return_expression));

				var target_l = get_result_cexpression (get_delegate_target_cname ("result"));
				if (!is_in_coroutine ()) {
					target_l = new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, target_l);
				}
				CCodeExpression target_r_destroy_notify;
				var target_r = get_delegate_target_cexpression (stmt.return_expression, out target_r_destroy_notify);
				ccode.add_assignment (target_l, target_r);
				if (delegate_type.value_owned) {
					var target_l_destroy_notify = get_result_cexpression (get_delegate_target_destroy_notify_cname ("result"));
					if (!is_in_coroutine ()) {
						target_l_destroy_notify = new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, target_l_destroy_notify);
					}
					ccode.add_assignment (target_l_destroy_notify, target_r_destroy_notify);
				}

				set_cvalue (stmt.return_expression, get_variable_cexpression (return_expr_decl.name));

				emit_temp_var (return_expr_decl);
			}
		}

		if (stmt.return_expression != null) {
			// assign method result to `result'
			CCodeExpression result_lhs = get_result_cexpression ();
			if (current_return_type.is_real_non_null_struct_type () && !is_in_coroutine ()) {
				result_lhs = new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, result_lhs);
			}
			ccode.add_assignment (result_lhs, get_cvalue (stmt.return_expression));
		}

		// free local variables
		append_local_free (current_symbol);

		if (current_method != null) {
			// check postconditions
			foreach (Expression postcondition in current_method.get_postconditions ()) {
				create_postcondition_statement (postcondition);
			}
		}

		if (current_method != null && !current_method.coroutine) {
			// assign values to output parameters if they are not NULL
			// otherwise, free the value if necessary
			foreach (var param in current_method.get_parameters ()) {
				if (param.direction != ParameterDirection.OUT) {
					continue;
				}

				return_out_parameter (param);
			}
		}

		if (is_in_constructor ()) {
			ccode.add_return (new CCodeIdentifier ("obj"));
		} else if (is_in_destructor ()) {
			// do not call return as member cleanup and chain up to base finalizer
			// stil need to be executed
			ccode.add_goto ("_return");
		} else if (current_method is CreationMethod) {
			ccode.add_return (new CCodeIdentifier ("self"));
		} else if (is_in_coroutine ()) {
		} else if (current_return_type is VoidType || current_return_type.is_real_non_null_struct_type ()) {
			// structs are returned via out parameter
			ccode.add_return ();
		} else {
			ccode.add_return (new CCodeIdentifier ("result"));
		}

		if (return_expression_symbol != null) {
			return_expression_symbol.active = true;
		}

		// required for destructors
		current_method_return = true;
	}

	public string get_symbol_lock_name (string symname) {
		return "__lock_%s".printf (symname);
	}

	private CCodeExpression get_lock_expression (Statement stmt, Expression resource) {
		CCodeExpression l = null;
		var inner_node = ((MemberAccess)resource).inner;
		var member = resource.symbol_reference;
		var parent = (TypeSymbol)resource.symbol_reference.parent_symbol;
		
		if (member.is_instance_member ()) {
			if (inner_node  == null) {
				l = new CCodeIdentifier ("self");
			} else if (resource.symbol_reference.parent_symbol != current_type_symbol) {
				l = generate_instance_cast (get_cvalue (inner_node), parent);
			} else {
				l = get_cvalue (inner_node);
			}

			l = new CCodeMemberAccess.pointer (new CCodeMemberAccess.pointer (l, "priv"), get_symbol_lock_name (resource.symbol_reference.name));
		} else if (member.is_class_member ()) {
			CCodeExpression klass;

			if (current_method != null && current_method.binding == MemberBinding.INSTANCE ||
			    current_property_accessor != null && current_property_accessor.prop.binding == MemberBinding.INSTANCE ||
			    (in_constructor && !in_static_or_class_context)) {
				var k = new CCodeFunctionCall (new CCodeIdentifier ("G_OBJECT_GET_CLASS"));
				k.add_argument (new CCodeIdentifier ("self"));
				klass = k;
			} else {
				klass = new CCodeIdentifier ("klass");
			}

			var get_class_private_call = new CCodeFunctionCall (new CCodeIdentifier ("%s_GET_CLASS_PRIVATE".printf(parent.get_upper_case_cname ())));
			get_class_private_call.add_argument (klass);
			l = new CCodeMemberAccess.pointer (get_class_private_call, get_symbol_lock_name (resource.symbol_reference.name));
		} else {
			string lock_name = "%s_%s".printf(parent.get_lower_case_cname (), resource.symbol_reference.name);
			l = new CCodeIdentifier (get_symbol_lock_name (lock_name));
		}
		return l;
	}
		
	public override void visit_lock_statement (LockStatement stmt) {
		var l = get_lock_expression (stmt, stmt.resource);

		var fc = new CCodeFunctionCall (new CCodeIdentifier (((Method) mutex_type.scope.lookup ("lock")).get_cname ()));
		fc.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, l));

		ccode.add_expression (fc);
	}
		
	public override void visit_unlock_statement (UnlockStatement stmt) {
		var l = get_lock_expression (stmt, stmt.resource);
		
		var fc = new CCodeFunctionCall (new CCodeIdentifier (((Method) mutex_type.scope.lookup ("unlock")).get_cname ()));
		fc.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, l));
		
		ccode.add_expression (fc);
	}

	public override void visit_delete_statement (DeleteStatement stmt) {
		var pointer_type = (PointerType) stmt.expression.value_type;
		DataType type = pointer_type;
		if (pointer_type.base_type.data_type != null && pointer_type.base_type.data_type.is_reference_type ()) {
			type = pointer_type.base_type;
		}

		var ccall = new CCodeFunctionCall (get_destroy_func_expression (type));
		ccall.add_argument (get_cvalue (stmt.expression));
		ccode.add_expression (ccall);
	}

	public override void visit_expression (Expression expr) {
		if (get_cvalue (expr) != null && !expr.lvalue) {
			if (expr.formal_value_type is GenericType && !(expr.value_type is GenericType)) {
				var st = expr.formal_value_type.type_parameter.parent_symbol.parent_symbol as Struct;
				if (expr.formal_value_type.type_parameter.parent_symbol != garray_type &&
				    (st == null || st.get_cname () != "va_list")) {
					// GArray and va_list don't use pointer-based generics
					set_cvalue (expr, convert_from_generic_pointer (get_cvalue (expr), expr.value_type));
				}
			}

			// memory management, implicit casts, and boxing/unboxing
			set_cvalue (expr, transform_expression (get_cvalue (expr), expr.value_type, expr.target_type, expr));

			if (expr.formal_target_type is GenericType && !(expr.target_type is GenericType)) {
				if (expr.formal_target_type.type_parameter.parent_symbol != garray_type) {
					// GArray doesn't use pointer-based generics
					set_cvalue (expr, convert_to_generic_pointer (get_cvalue (expr), expr.target_type));
				}
			}
		}
	}

	public override void visit_boolean_literal (BooleanLiteral expr) {
		if (context.profile == Profile.GOBJECT) {
			set_cvalue (expr, new CCodeConstant (expr.value ? "TRUE" : "FALSE"));
		} else {
			cfile.add_include ("stdbool.h");
			set_cvalue (expr, new CCodeConstant (expr.value ? "true" : "false"));
		}
	}

	public override void visit_character_literal (CharacterLiteral expr) {
		if (expr.get_char () >= 0x20 && expr.get_char () < 0x80) {
			set_cvalue (expr, new CCodeConstant (expr.value));
		} else {
			set_cvalue (expr, new CCodeConstant ("%uU".printf (expr.get_char ())));
		}
	}

	public override void visit_integer_literal (IntegerLiteral expr) {
		set_cvalue (expr, new CCodeConstant (expr.value + expr.type_suffix));
	}

	public override void visit_real_literal (RealLiteral expr) {
		string c_literal = expr.value;
		if (c_literal.has_suffix ("d") || c_literal.has_suffix ("D")) {
			// there is no suffix for double in C
			c_literal = c_literal.substring (0, c_literal.length - 1);
		}
		if (!("." in c_literal || "e" in c_literal || "E" in c_literal)) {
			// C requires period or exponent part for floating constants
			if ("f" in c_literal || "F" in c_literal) {
				c_literal = c_literal.substring (0, c_literal.length - 1) + ".f";
			} else {
				c_literal += ".";
			}
		}
		set_cvalue (expr, new CCodeConstant (c_literal));
	}

	public override void visit_string_literal (StringLiteral expr) {
		set_cvalue (expr, new CCodeConstant.string (expr.value.replace ("\n", "\\n")));

		if (expr.translate) {
			// translated string constant

			var m = (Method) root_symbol.scope.lookup ("GLib").scope.lookup ("_");
			add_symbol_declaration (cfile, m, m.get_cname ());

			var translate = new CCodeFunctionCall (new CCodeIdentifier ("_"));
			translate.add_argument (get_cvalue (expr));
			set_cvalue (expr, translate);
		}
	}

	public override void visit_regex_literal (RegexLiteral expr) {
		string[] parts = expr.value.split ("/", 3);
		string re = parts[2].escape ("");
		string flags = "0";

		if (parts[1].contains ("i")) {
			flags += " | G_REGEX_CASELESS";
		}
		if (parts[1].contains ("m")) {
			flags += " | G_REGEX_MULTILINE";
		}
		if (parts[1].contains ("s")) {
			flags += " | G_REGEX_DOTALL";
		}
		if (parts[1].contains ("x")) {
			flags += " | G_REGEX_EXTENDED";
		}

		var regex_var = get_temp_variable (regex_type, true, expr, false);
		emit_temp_var (regex_var);

		var cdecl = new CCodeDeclaration ("GRegex*");

		var cname = regex_var.name + "regex_" + next_regex_id.to_string ();
		if (this.next_regex_id == 0) {
			var fun = new CCodeFunction ("_thread_safe_regex_init", "GRegex*");
			fun.modifiers = CCodeModifiers.STATIC | CCodeModifiers.INLINE;
			fun.add_parameter (new CCodeParameter ("re", "GRegex**"));
			fun.add_parameter (new CCodeParameter ("pattern", "const gchar *"));
			fun.add_parameter (new CCodeParameter ("match_options", "GRegexMatchFlags"));

			push_function (fun);

			var once_enter_call = new CCodeFunctionCall (new CCodeIdentifier ("g_once_init_enter"));
			once_enter_call.add_argument (new CCodeConstant ("(volatile gsize*) re"));
			ccode.open_if (once_enter_call);

			var regex_new_call = new CCodeFunctionCall (new CCodeIdentifier ("g_regex_new"));
			regex_new_call.add_argument (new CCodeConstant ("pattern"));
			regex_new_call.add_argument (new CCodeConstant ("match_options"));
			regex_new_call.add_argument (new CCodeConstant ("0"));
			regex_new_call.add_argument (new CCodeConstant ("NULL"));
			ccode.add_assignment (new CCodeIdentifier ("GRegex* val"), regex_new_call);

			var once_leave_call = new CCodeFunctionCall (new CCodeIdentifier ("g_once_init_leave"));
			once_leave_call.add_argument (new CCodeConstant ("(volatile gsize*) re"));
			once_leave_call.add_argument (new CCodeConstant ("(gsize) val"));
			ccode.add_expression (once_leave_call);

			ccode.close ();

			ccode.add_return (new CCodeIdentifier ("*re"));

			pop_function ();

			cfile.add_function (fun);
		}
		this.next_regex_id++;

		cdecl.add_declarator (new CCodeVariableDeclarator (cname + " = NULL"));
		cdecl.modifiers = CCodeModifiers.STATIC;

		var regex_const = new CCodeConstant ("_thread_safe_regex_init (&%s, \"%s\", %s)".printf (cname, re, flags));

		cfile.add_constant_declaration (cdecl);
		set_cvalue (expr, regex_const);
	}

	public override void visit_null_literal (NullLiteral expr) {
		if (context.profile != Profile.GOBJECT) {
			cfile.add_include ("stddef.h");
		}
		set_cvalue (expr, new CCodeConstant ("NULL"));

		var array_type = expr.target_type as ArrayType;
		var delegate_type = expr.target_type as DelegateType;
		if (array_type != null) {
			for (int dim = 1; dim <= array_type.rank; dim++) {
				append_array_length (expr, new CCodeConstant ("0"));
			}
		} else if (delegate_type != null && delegate_type.delegate_symbol.has_target) {
			set_delegate_target (expr, new CCodeConstant ("NULL"));
			set_delegate_target_destroy_notify (expr, new CCodeConstant ("NULL"));
		}
	}

	public virtual TargetValue get_variable_cvalue (Variable variable, CCodeExpression? inner = null) {
		assert_not_reached ();
	}

	public virtual TargetValue load_parameter (Parameter param) {
		assert_not_reached ();
	}

	public virtual string get_delegate_target_cname (string delegate_cname) {
		assert_not_reached ();
	}

	public virtual CCodeExpression get_delegate_target_cexpression (Expression delegate_expr, out CCodeExpression delegate_target_destroy_notify) {
		assert_not_reached ();
	}

	public virtual CCodeExpression get_delegate_target_cvalue (TargetValue value) {
		return new CCodeInvalidExpression ();
	}

	public virtual CCodeExpression get_delegate_target_destroy_notify_cvalue (TargetValue value) {
		return new CCodeInvalidExpression ();
	}

	public virtual string get_delegate_target_destroy_notify_cname (string delegate_cname) {
		assert_not_reached ();
	}

	public override void visit_base_access (BaseAccess expr) {
		CCodeExpression this_access;
		if (is_in_coroutine ()) {
			// use closure
			this_access = new CCodeMemberAccess.pointer (new CCodeIdentifier ("data"), "self");
		} else {
			this_access = new CCodeIdentifier ("self");
		}

		set_cvalue (expr, generate_instance_cast (this_access, expr.value_type.data_type));
	}

	public override void visit_postfix_expression (PostfixExpression expr) {
		MemberAccess ma = find_property_access (expr.inner);
		if (ma != null) {
			// property postfix expression
			var prop = (Property) ma.symbol_reference;
			
			// assign current value to temp variable
			var temp_decl = get_temp_variable (prop.property_type, true, expr, false);
			emit_temp_var (temp_decl);
			ccode.add_assignment (get_variable_cexpression (temp_decl.name), get_cvalue (expr.inner));
			
			// increment/decrement property
			var op = expr.increment ? CCodeBinaryOperator.PLUS : CCodeBinaryOperator.MINUS;
			var cexpr = new CCodeBinaryExpression (op, get_variable_cexpression (temp_decl.name), new CCodeConstant ("1"));
			store_property (prop, ma.inner, new GLibValue (expr.value_type, cexpr));
			
			// return previous value
			set_cvalue (expr, get_variable_cexpression (temp_decl.name));
			return;
		}

		if (expr.parent_node is ExpressionStatement) {
			var op = expr.increment ? CCodeUnaryOperator.POSTFIX_INCREMENT : CCodeUnaryOperator.POSTFIX_DECREMENT;

			ccode.add_expression (new CCodeUnaryExpression (op, get_cvalue (expr.inner)));
		} else {
			// assign current value to temp variable
			var temp_decl = get_temp_variable (expr.inner.value_type, true, expr, false);
			emit_temp_var (temp_decl);
			ccode.add_assignment (get_variable_cexpression (temp_decl.name), get_cvalue (expr.inner));

			// increment/decrement variable
			var op = expr.increment ? CCodeBinaryOperator.PLUS : CCodeBinaryOperator.MINUS;
			var cexpr = new CCodeBinaryExpression (op, get_variable_cexpression (temp_decl.name), new CCodeConstant ("1"));
			ccode.add_assignment (get_cvalue (expr.inner), cexpr);

			// return previous value
			set_cvalue (expr, get_variable_cexpression (temp_decl.name));
		}
	}
	
	private MemberAccess? find_property_access (Expression expr) {
		if (!(expr is MemberAccess)) {
			return null;
		}
		
		var ma = (MemberAccess) expr;
		if (ma.symbol_reference is Property) {
			return ma;
		}
		
		return null;
	}

	bool is_limited_generic_type (DataType type) {
		var cl = type.type_parameter.parent_symbol as Class;
		var st = type.type_parameter.parent_symbol as Struct;
		if ((cl != null && cl.is_compact) || st != null) {
			// compact classes and structs only
			// have very limited generics support
			return true;
		}
		return false;
	}

	public bool requires_copy (DataType type) {
		if (!type.is_disposable ()) {
			return false;
		}

		var cl = type.data_type as Class;
		if (cl != null && cl.is_reference_counting ()
		    && cl.get_ref_function () == "") {
			// empty ref_function => no ref necessary
			return false;
		}

		if (type.type_parameter != null) {
			if (is_limited_generic_type (type)) {
				return false;
			}
		}

		return true;
	}

	public bool requires_destroy (DataType type) {
		if (!type.is_disposable ()) {
			return false;
		}

		var array_type = type as ArrayType;
		if (array_type != null && array_type.fixed_length) {
			return requires_destroy (array_type.element_type);
		}

		var cl = type.data_type as Class;
		if (cl != null && cl.is_reference_counting ()
		    && cl.get_unref_function () == "") {
			// empty unref_function => no unref necessary
			return false;
		}

		if (type.type_parameter != null) {
			if (is_limited_generic_type (type)) {
				return false;
			}
		}

		return true;
	}

	bool is_ref_function_void (DataType type) {
		var cl = type.data_type as Class;
		if (cl != null && cl.ref_function_void) {
			return true;
		} else {
			return false;
		}
	}

	public virtual CCodeExpression? get_ref_cexpression (DataType expression_type, CCodeExpression cexpr, Expression? expr, CodeNode node) {
		if (expression_type is DelegateType) {
			return cexpr;
		}

		if (expression_type is ValueType && !expression_type.nullable) {
			// normal value type, no null check
			// (copy (&expr, &temp), temp)

			var decl = get_temp_variable (expression_type, false, node);
			emit_temp_var (decl);

			var ctemp = get_variable_cexpression (decl.name);
			
			var vt = (ValueType) expression_type;
			var st = (Struct) vt.type_symbol;
			var copy_call = new CCodeFunctionCall (new CCodeIdentifier (st.get_copy_function ()));
			copy_call.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cexpr));
			copy_call.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, ctemp));

			if (!st.has_copy_function) {
				generate_struct_copy_function (st);
			}

			var ccomma = new CCodeCommaExpression ();

			if (st.get_copy_function () == "g_value_copy") {
				// GValue requires g_value_init in addition to g_value_copy

				var value_type_call = new CCodeFunctionCall (new CCodeIdentifier ("G_VALUE_TYPE"));
				value_type_call.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cexpr));

				var init_call = new CCodeFunctionCall (new CCodeIdentifier ("g_value_init"));
				init_call.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, ctemp));
				init_call.add_argument (value_type_call);

				ccomma.append_expression (init_call);
			}

			ccomma.append_expression (copy_call);
			ccomma.append_expression (ctemp);

			if (gvalue_type != null && expression_type.data_type == gvalue_type) {
				// g_value_init/copy must not be called for uninitialized values
				var cisvalid = new CCodeFunctionCall (new CCodeIdentifier ("G_IS_VALUE"));
				cisvalid.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cexpr));

				return new CCodeConditionalExpression (cisvalid, ccomma, cexpr);
			} else {
				return ccomma;
			}
		}

		/* (temp = expr, temp == NULL ? NULL : ref (temp))
		 *
		 * can be simplified to
		 * ref (expr)
		 * if static type of expr is non-null
		 */
		 
		var dupexpr = get_dup_func_expression (expression_type, node.source_reference);

		if (dupexpr == null) {
			node.error = true;
			return null;
		}

		if (dupexpr is CCodeIdentifier && !(expression_type is ArrayType) && !(expression_type is GenericType) && !is_ref_function_void (expression_type)) {
			// generate and call NULL-aware ref function to reduce number
			// of temporary variables and simplify code

			var dupid = (CCodeIdentifier) dupexpr;
			string dup0_func = "_%s0".printf (dupid.name);

			// g_strdup is already NULL-safe
			if (dupid.name == "g_strdup") {
				dup0_func = dupid.name;
			} else if (add_wrapper (dup0_func)) {
				string pointer_cname = "gpointer";
				if (context.profile == Profile.POSIX) {
					pointer_cname = "void*";
				}
				var dup0_fun = new CCodeFunction (dup0_func, pointer_cname);
				dup0_fun.add_parameter (new CCodeParameter ("self", pointer_cname));
				dup0_fun.modifiers = CCodeModifiers.STATIC;

				push_function (dup0_fun);

				var dup_call = new CCodeFunctionCall (dupexpr);
				dup_call.add_argument (new CCodeIdentifier ("self"));

				ccode.add_return (new CCodeConditionalExpression (new CCodeIdentifier ("self"), dup_call, new CCodeConstant ("NULL")));

				pop_function ();

				cfile.add_function (dup0_fun);
			}

			var ccall = new CCodeFunctionCall (new CCodeIdentifier (dup0_func));
			ccall.add_argument (cexpr);
			return ccall;
		}

		var ccall = new CCodeFunctionCall (dupexpr);

		if (!(expression_type is ArrayType) && expr != null && expr.is_non_null ()
		    && !is_ref_function_void (expression_type)) {
			// expression is non-null
			ccall.add_argument (get_cvalue (expr));
			
			return ccall;
		} else {
			var decl = get_temp_variable (expression_type, false, node, false);
			emit_temp_var (decl);

			var ctemp = get_variable_cexpression (decl.name);
			
			var cisnull = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, ctemp, new CCodeConstant ("NULL"));
			if (expression_type.type_parameter != null) {
				// dup functions are optional for type parameters
				var cdupisnull = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, get_dup_func_expression (expression_type, node.source_reference), new CCodeConstant ("NULL"));
				cisnull = new CCodeBinaryExpression (CCodeBinaryOperator.OR, cisnull, cdupisnull);
			}

			if (expression_type.type_parameter != null) {
				// cast from gconstpointer to gpointer as GBoxedCopyFunc expects gpointer
				ccall.add_argument (new CCodeCastExpression (ctemp, "gpointer"));
			} else {
				ccall.add_argument (ctemp);
			}

			if (expression_type is ArrayType) {
				var array_type = (ArrayType) expression_type;
				bool first = true;
				CCodeExpression csizeexpr = null;
				for (int dim = 1; dim <= array_type.rank; dim++) {
					if (first) {
						csizeexpr = get_array_length_cexpression (expr, dim);
						first = false;
					} else {
						csizeexpr = new CCodeBinaryExpression (CCodeBinaryOperator.MUL, csizeexpr, get_array_length_cexpression (expr, dim));
					}
				}

				ccall.add_argument (csizeexpr);

				if (array_type.element_type is GenericType) {
					var elem_dupexpr = get_dup_func_expression (array_type.element_type, node.source_reference);
					if (elem_dupexpr == null) {
						elem_dupexpr = new CCodeConstant ("NULL");
					}
					ccall.add_argument (elem_dupexpr);
				}
			}

			var ccomma = new CCodeCommaExpression ();
			ccomma.append_expression (new CCodeAssignment (ctemp, cexpr));

			CCodeExpression cifnull;
			if (expression_type.data_type != null) {
				cifnull = new CCodeConstant ("NULL");
			} else {
				// the value might be non-null even when the dup function is null,
				// so we may not just use NULL for type parameters

				// cast from gconstpointer to gpointer as methods in
				// generic classes may not return gconstpointer
				cifnull = new CCodeCastExpression (ctemp, "gpointer");
			}
			ccomma.append_expression (new CCodeConditionalExpression (cisnull, cifnull, ccall));

			// repeat temp variable at the end of the comma expression
			// if the ref function returns void
			if (is_ref_function_void (expression_type)) {
				ccomma.append_expression (ctemp);
			}

			return ccomma;
		}
	}

	bool is_reference_type_argument (DataType type_arg) {
		if (type_arg is ErrorType || (type_arg.data_type != null && type_arg.data_type.is_reference_type ())) {
			return true;
		} else {
			return false;
		}
	}

	bool is_nullable_value_type_argument (DataType type_arg) {
		if (type_arg is ValueType && type_arg.nullable) {
			return true;
		} else {
			return false;
		}
	}

	bool is_signed_integer_type_argument (DataType type_arg) {
		var st = type_arg.data_type as Struct;
		if (type_arg.nullable) {
			return false;
		} else if (st == bool_type.data_type) {
			return true;
		} else if (st == char_type.data_type) {
			return true;
		} else if (unichar_type != null && st == unichar_type.data_type) {
			return true;
		} else if (st == short_type.data_type) {
			return true;
		} else if (st == int_type.data_type) {
			return true;
		} else if (st == long_type.data_type) {
			return true;
		} else if (st == int8_type.data_type) {
			return true;
		} else if (st == int16_type.data_type) {
			return true;
		} else if (st == int32_type.data_type) {
			return true;
		} else if (st == gtype_type) {
			return true;
		} else if (type_arg is EnumValueType) {
			return true;
		} else {
			return false;
		}
	}

	bool is_unsigned_integer_type_argument (DataType type_arg) {
		var st = type_arg.data_type as Struct;
		if (type_arg.nullable) {
			return false;
		} else if (st == uchar_type.data_type) {
			return true;
		} else if (st == ushort_type.data_type) {
			return true;
		} else if (st == uint_type.data_type) {
			return true;
		} else if (st == ulong_type.data_type) {
			return true;
		} else if (st == uint8_type.data_type) {
			return true;
		} else if (st == uint16_type.data_type) {
			return true;
		} else if (st == uint32_type.data_type) {
			return true;
		} else {
			return false;
		}
	}

	public void check_type (DataType type) {
		var array_type = type as ArrayType;
		if (array_type != null) {
			check_type (array_type.element_type);
			if (array_type.element_type is ArrayType) {
				Report.error (type.source_reference, "Stacked arrays are not supported");
			} else if (array_type.element_type is DelegateType) {
				var delegate_type = (DelegateType) array_type.element_type;
				if (delegate_type.delegate_symbol.has_target) {
					Report.error (type.source_reference, "Delegates with target are not supported as array element type");
				}
			}
		}
		foreach (var type_arg in type.get_type_arguments ()) {
			check_type (type_arg);
			check_type_argument (type_arg);
		}
	}

	void check_type_argument (DataType type_arg) {
		if (type_arg is GenericType
		    || type_arg is PointerType
		    || is_reference_type_argument (type_arg)
		    || is_nullable_value_type_argument (type_arg)
		    || is_signed_integer_type_argument (type_arg)
		    || is_unsigned_integer_type_argument (type_arg)) {
			// no error
		} else if (type_arg is DelegateType) {
			var delegate_type = (DelegateType) type_arg;
			if (delegate_type.delegate_symbol.has_target) {
				Report.error (type_arg.source_reference, "Delegates with target are not supported as generic type arguments");
			}
		} else {
			Report.error (type_arg.source_reference, "`%s' is not a supported generic type argument, use `?' to box value types".printf (type_arg.to_string ()));
		}
	}

	public virtual void generate_class_declaration (Class cl, CCodeFile decl_space) {
		if (add_symbol_declaration (decl_space, cl, cl.get_cname ())) {
			return;
		}
	}

	public virtual void generate_interface_declaration (Interface iface, CCodeFile decl_space) {
	}

	public virtual void generate_method_declaration (Method m, CCodeFile decl_space) {
	}

	public virtual void generate_error_domain_declaration (ErrorDomain edomain, CCodeFile decl_space) {
	}

	public void add_generic_type_arguments (Map<int,CCodeExpression> arg_map, List<DataType> type_args, CodeNode expr, bool is_chainup = false) {
		int type_param_index = 0;
		foreach (var type_arg in type_args) {
			arg_map.set (get_param_pos (0.1 * type_param_index + 0.01), get_type_id_expression (type_arg, is_chainup));
			if (requires_copy (type_arg)) {
				var dup_func = get_dup_func_expression (type_arg, type_arg.source_reference, is_chainup);
				if (dup_func == null) {
					// type doesn't contain a copy function
					expr.error = true;
					return;
				}
				arg_map.set (get_param_pos (0.1 * type_param_index + 0.02), new CCodeCastExpression (dup_func, "GBoxedCopyFunc"));
				arg_map.set (get_param_pos (0.1 * type_param_index + 0.03), get_destroy_func_expression (type_arg, is_chainup));
			} else {
				arg_map.set (get_param_pos (0.1 * type_param_index + 0.02), new CCodeConstant ("NULL"));
				arg_map.set (get_param_pos (0.1 * type_param_index + 0.03), new CCodeConstant ("NULL"));
			}
			type_param_index++;
		}
	}

	public override void visit_object_creation_expression (ObjectCreationExpression expr) {
		CCodeExpression instance = null;
		CCodeExpression creation_expr = null;

		check_type (expr.type_reference);

		var st = expr.type_reference.data_type as Struct;
		if ((st != null && (!st.is_simple_type () || st.get_cname () == "va_list")) || expr.get_object_initializer ().size > 0) {
			// value-type initialization or object creation expression with object initializer

			var local = expr.parent_node as LocalVariable;
			if (local != null && has_simple_struct_initializer (local)) {
				if (local.captured) {
					var block = (Block) local.parent_symbol;
					instance = new CCodeMemberAccess.pointer (get_variable_cexpression ("_data%d_".printf (get_block_id (block))), get_variable_cname (local.name));
				} else {
					instance = get_variable_cexpression (get_variable_cname (local.name));
				}
			} else {
				var temp_decl = get_temp_variable (expr.type_reference, false, expr);
				emit_temp_var (temp_decl);

				instance = get_variable_cexpression (get_variable_cname (temp_decl.name));
			}
		}

		if (expr.symbol_reference == null) {
			// no creation method
			if (expr.type_reference.data_type is Struct) {
				// memset needs string.h
				cfile.add_include ("string.h");
				var creation_call = new CCodeFunctionCall (new CCodeIdentifier ("memset"));
				creation_call.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, instance));
				creation_call.add_argument (new CCodeConstant ("0"));
				creation_call.add_argument (new CCodeIdentifier ("sizeof (%s)".printf (expr.type_reference.get_cname ())));

				creation_expr = creation_call;
			}
		} else if (expr.type_reference.data_type == glist_type ||
		           expr.type_reference.data_type == gslist_type) {
			// NULL is an empty list
			set_cvalue (expr, new CCodeConstant ("NULL"));
		} else if (expr.symbol_reference is Method) {
			// use creation method
			var m = (Method) expr.symbol_reference;
			var params = m.get_parameters ();
			CCodeFunctionCall creation_call;

			generate_method_declaration (m, cfile);

			var cl = expr.type_reference.data_type as Class;

			if (!m.has_new_function) {
				// use construct function directly
				creation_call = new CCodeFunctionCall (new CCodeIdentifier (m.get_real_cname ()));
				creation_call.add_argument (new CCodeIdentifier (cl.get_type_id ()));
			} else {
				creation_call = new CCodeFunctionCall (new CCodeIdentifier (m.get_cname ()));
			}

			if ((st != null && !st.is_simple_type ()) && !(m.cinstance_parameter_position < 0)) {
				creation_call.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, instance));
			} else if (st != null && st.get_cname () == "va_list") {
				creation_call.add_argument (instance);
				if (m.get_cname () == "va_start") {
					Parameter last_param = null;
					foreach (var param in current_method.get_parameters ()) {
						if (param.ellipsis) {
							break;
						}
						last_param = param;
					}
					creation_call.add_argument (new CCodeIdentifier (get_variable_cname (last_param.name)));
				}
			}

			generate_type_declaration (expr.type_reference, cfile);

			var carg_map = new HashMap<int,CCodeExpression> (direct_hash, direct_equal);

			if (cl != null && !cl.is_compact) {
				add_generic_type_arguments (carg_map, expr.type_reference.get_type_arguments (), expr);
			} else if (cl != null && m.simple_generics) {
				int type_param_index = 0;
				foreach (var type_arg in expr.type_reference.get_type_arguments ()) {
					if (requires_copy (type_arg)) {
						carg_map.set (get_param_pos (-1 + 0.1 * type_param_index + 0.03), get_destroy0_func_expression (type_arg));
					} else {
						carg_map.set (get_param_pos (-1 + 0.1 * type_param_index + 0.03), new CCodeConstant ("NULL"));
					}
					type_param_index++;
				}
			}

			bool ellipsis = false;

			int i = 1;
			int arg_pos;
			Iterator<Parameter> params_it = params.iterator ();
			foreach (Expression arg in expr.get_argument_list ()) {
				CCodeExpression cexpr = get_cvalue (arg);
				Parameter param = null;
				if (params_it.next ()) {
					param = params_it.get ();
					ellipsis = param.ellipsis;
					if (!ellipsis) {
						if (!param.no_array_length && param.variable_type is ArrayType) {
							var array_type = (ArrayType) param.variable_type;
							for (int dim = 1; dim <= array_type.rank; dim++) {
								carg_map.set (get_param_pos (param.carray_length_parameter_position + 0.01 * dim), get_array_length_cexpression (arg, dim));
							}
						} else if (param.variable_type is DelegateType) {
							var deleg_type = (DelegateType) param.variable_type;
							var d = deleg_type.delegate_symbol;
							if (d.has_target) {
								CCodeExpression delegate_target_destroy_notify;
								var delegate_target = get_delegate_target_cexpression (arg, out delegate_target_destroy_notify);
								carg_map.set (get_param_pos (param.cdelegate_target_parameter_position), delegate_target);
								if (deleg_type.value_owned) {
									carg_map.set (get_param_pos (param.cdelegate_target_parameter_position + 0.01), delegate_target_destroy_notify);
								}
							}
						}

						cexpr = handle_struct_argument (param, arg, cexpr);

						if (param.ctype != null) {
							cexpr = new CCodeCastExpression (cexpr, param.ctype);
						}
					} else {
						cexpr = handle_struct_argument (null, arg, cexpr);
					}

					arg_pos = get_param_pos (param.cparameter_position, ellipsis);
				} else {
					// default argument position
					cexpr = handle_struct_argument (null, arg, cexpr);
					arg_pos = get_param_pos (i, ellipsis);
				}
			
				carg_map.set (arg_pos, cexpr);

				i++;
			}
			while (params_it.next ()) {
				var param = params_it.get ();
				
				if (param.ellipsis) {
					ellipsis = true;
					break;
				}
				
				if (param.initializer == null) {
					Report.error (expr.source_reference, "no default expression for argument %d".printf (i));
					return;
				}
				
				/* evaluate default expression here as the code
				 * generator might not have visited the formal
				 * parameter yet */
				param.initializer.emit (this);
			
				carg_map.set (get_param_pos (param.cparameter_position), get_cvalue (param.initializer));
				i++;
			}

			// append C arguments in the right order
			int last_pos = -1;
			int min_pos;
			while (true) {
				min_pos = -1;
				foreach (int pos in carg_map.get_keys ()) {
					if (pos > last_pos && (min_pos == -1 || pos < min_pos)) {
						min_pos = pos;
					}
				}
				if (min_pos == -1) {
					break;
				}
				creation_call.add_argument (carg_map.get (min_pos));
				last_pos = min_pos;
			}

			if ((st != null && !st.is_simple_type ()) && m.cinstance_parameter_position < 0) {
				// instance parameter is at the end in a struct creation method
				creation_call.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, instance));
			}

			if (expr.tree_can_fail) {
				// method can fail
				current_method_inner_error = true;
				creation_call.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, get_variable_cexpression ("_inner_error_")));
			}

			if (ellipsis) {
				/* ensure variable argument list ends with NULL
				 * except when using printf-style arguments */
				if (!m.printf_format && !m.scanf_format && m.sentinel != "") {
					creation_call.add_argument (new CCodeConstant (m.sentinel));
				}
			}

			creation_expr = creation_call;

			// cast the return value of the creation method back to the intended type if
			// it requested a special C return type
			if (get_custom_creturn_type (m) != null) {
				creation_expr = new CCodeCastExpression (creation_expr, expr.type_reference.get_cname ());
			}
		} else if (expr.symbol_reference is ErrorCode) {
			var ecode = (ErrorCode) expr.symbol_reference;
			var edomain = (ErrorDomain) ecode.parent_symbol;
			CCodeFunctionCall creation_call;

			generate_error_domain_declaration (edomain, cfile);

			if (expr.get_argument_list ().size == 1) {
				// must not be a format argument
				creation_call = new CCodeFunctionCall (new CCodeIdentifier ("g_error_new_literal"));
			} else {
				creation_call = new CCodeFunctionCall (new CCodeIdentifier ("g_error_new"));
			}
			creation_call.add_argument (new CCodeIdentifier (edomain.get_upper_case_cname ()));
			creation_call.add_argument (new CCodeIdentifier (ecode.get_cname ()));

			foreach (Expression arg in expr.get_argument_list ()) {
				creation_call.add_argument (get_cvalue (arg));
			}

			creation_expr = creation_call;
		} else {
			assert (false);
		}

		var local = expr.parent_node as LocalVariable;
		if (local != null && has_simple_struct_initializer (local)) {
			// no temporary variable necessary
			ccode.add_expression (creation_expr);
			set_cvalue (expr, instance);
			return;
		} else if (instance != null) {
			if (expr.type_reference.data_type is Struct) {
				ccode.add_expression (creation_expr);
			} else {
				ccode.add_assignment (instance, creation_expr);
			}

			foreach (MemberInitializer init in expr.get_object_initializer ()) {
				if (init.symbol_reference is Field) {
					var f = (Field) init.symbol_reference;
					var instance_target_type = get_data_type_for_symbol ((TypeSymbol) f.parent_symbol);
					var typed_inst = transform_expression (instance, expr.type_reference, instance_target_type);
					CCodeExpression lhs;
					if (expr.type_reference.data_type is Struct) {
						lhs = new CCodeMemberAccess (typed_inst, f.get_cname ());
					} else {
						lhs = new CCodeMemberAccess.pointer (typed_inst, f.get_cname ());
					}
					ccode.add_assignment (lhs, get_cvalue (init.initializer));

					if (f.variable_type is ArrayType && !f.no_array_length) {
						var array_type = (ArrayType) f.variable_type;
						for (int dim = 1; dim <= array_type.rank; dim++) {
							if (expr.type_reference.data_type is Struct) {
								lhs = new CCodeMemberAccess (typed_inst, get_array_length_cname (f.get_cname (), dim));
							} else {
								lhs = new CCodeMemberAccess.pointer (typed_inst, get_array_length_cname (f.get_cname (), dim));
							}
							var rhs_array_len = get_array_length_cexpression (init.initializer, dim);
							ccode.add_assignment (lhs, rhs_array_len);
						}
					} else if (f.variable_type is DelegateType && (f.variable_type as DelegateType).delegate_symbol.has_target && !f.no_delegate_target) {
						if (expr.type_reference.data_type is Struct) {
							lhs = new CCodeMemberAccess (typed_inst, get_delegate_target_cname (f.get_cname ()));
						} else {
							lhs = new CCodeMemberAccess.pointer (typed_inst, get_delegate_target_cname (f.get_cname ()));
						}
						CCodeExpression rhs_delegate_target_destroy_notify;
						var rhs_delegate_target = get_delegate_target_cexpression (init.initializer, out rhs_delegate_target_destroy_notify);
						ccode.add_assignment (lhs, rhs_delegate_target);
					}

					var cl = f.parent_symbol as Class;
					if (cl != null) {
						generate_class_struct_declaration (cl, cfile);
					}
				} else if (init.symbol_reference is Property) {
					var inst_ma = new MemberAccess.simple ("new");
					inst_ma.value_type = expr.type_reference;
					set_cvalue (inst_ma, instance);
					store_property ((Property) init.symbol_reference, inst_ma, init.initializer.target_value);
				}
			}

			creation_expr = instance;
		}

		if (creation_expr != null) {
			var temp_var = get_temp_variable (expr.value_type);
			var temp_ref = get_variable_cexpression (temp_var.name);

			emit_temp_var (temp_var);

			ccode.add_assignment (temp_ref, creation_expr);
			set_cvalue (expr, temp_ref);
		}
	}

	public CCodeExpression? handle_struct_argument (Parameter? param, Expression arg, CCodeExpression? cexpr) {
		DataType type;
		if (param != null) {
			type = param.variable_type;
		} else {
			// varargs
			type = arg.value_type;
		}

		// pass non-simple struct instances always by reference
		if (!(arg.value_type is NullType) && type.is_real_struct_type ()) {
			// we already use a reference for arguments of ref, out, and nullable parameters
			if ((param == null || param.direction == ParameterDirection.IN) && !type.nullable) {
				var unary = cexpr as CCodeUnaryExpression;
				if (unary != null && unary.operator == CCodeUnaryOperator.POINTER_INDIRECTION) {
					// *expr => expr
					return unary.inner;
				} else if (cexpr is CCodeIdentifier || cexpr is CCodeMemberAccess) {
					return new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cexpr);
				} else {
					// if cexpr is e.g. a function call, we can't take the address of the expression
					// (tmp = expr, &tmp)
					var ccomma = new CCodeCommaExpression ();

					var temp_var = get_temp_variable (type, true, null, false);
					emit_temp_var (temp_var);
					ccomma.append_expression (new CCodeAssignment (get_variable_cexpression (temp_var.name), cexpr));
					ccomma.append_expression (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, get_variable_cexpression (temp_var.name)));

					return ccomma;
				}
			}
		}

		return cexpr;
	}

	public override void visit_sizeof_expression (SizeofExpression expr) {
		generate_type_declaration (expr.type_reference, cfile);

		var csizeof = new CCodeFunctionCall (new CCodeIdentifier ("sizeof"));
		csizeof.add_argument (new CCodeIdentifier (expr.type_reference.get_cname ()));
		set_cvalue (expr, csizeof);
	}

	public override void visit_typeof_expression (TypeofExpression expr) {
		set_cvalue (expr, get_type_id_expression (expr.type_reference));
	}

	public override void visit_unary_expression (UnaryExpression expr) {
		if (expr.operator == UnaryOperator.REF || expr.operator == UnaryOperator.OUT) {
			var glib_value = (GLibValue) expr.inner.target_value;

			var ref_value = new GLibValue (glib_value.value_type);
			ref_value.cvalue = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, glib_value.cvalue);

			if (glib_value.array_length_cvalues != null) {
				for (int i = 0; i < glib_value.array_length_cvalues.size; i++) {
					ref_value.append_array_length_cvalue (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, glib_value.array_length_cvalues[i]));
				}
			}

			if (glib_value.delegate_target_cvalue != null) {
				ref_value.delegate_target_cvalue = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, glib_value.delegate_target_cvalue);
			}
			if (glib_value.delegate_target_destroy_notify_cvalue != null) {
				ref_value.delegate_target_destroy_notify_cvalue = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, glib_value.delegate_target_destroy_notify_cvalue);
			}

			expr.target_value = ref_value;
			return;
		}

		CCodeUnaryOperator op;
		if (expr.operator == UnaryOperator.PLUS) {
			op = CCodeUnaryOperator.PLUS;
		} else if (expr.operator == UnaryOperator.MINUS) {
			op = CCodeUnaryOperator.MINUS;
		} else if (expr.operator == UnaryOperator.LOGICAL_NEGATION) {
			op = CCodeUnaryOperator.LOGICAL_NEGATION;
		} else if (expr.operator == UnaryOperator.BITWISE_COMPLEMENT) {
			op = CCodeUnaryOperator.BITWISE_COMPLEMENT;
		} else if (expr.operator == UnaryOperator.INCREMENT) {
			op = CCodeUnaryOperator.PREFIX_INCREMENT;
		} else if (expr.operator == UnaryOperator.DECREMENT) {
			op = CCodeUnaryOperator.PREFIX_DECREMENT;
		} else {
			assert_not_reached ();
		}
		set_cvalue (expr, new CCodeUnaryExpression (op, get_cvalue (expr.inner)));
	}

	public CCodeExpression? try_cast_value_to_type (CCodeExpression ccodeexpr, DataType from, DataType to, Expression? expr = null) {
		if (from == null || gvalue_type == null || from.data_type != gvalue_type || to.get_type_id () == null) {
			return null;
		}

		// explicit conversion from GValue
		var ccall = new CCodeFunctionCall (get_value_getter_function (to));
		CCodeExpression gvalue;
		if (from.nullable) {
			gvalue = ccodeexpr;
		} else {
			gvalue = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, ccodeexpr);
		}
		ccall.add_argument (gvalue);

		CCodeExpression rv = ccall;

		if (expr != null && to is ArrayType) {
			// null-terminated string array
			var len_call = new CCodeFunctionCall (new CCodeIdentifier ("g_strv_length"));
			len_call.add_argument (rv);
			append_array_length (expr, len_call);
		} else if (to is StructValueType) {
			var temp_decl = get_temp_variable (to, true, null, true);
			emit_temp_var (temp_decl);
			var ctemp = get_variable_cexpression (temp_decl.name);

			rv = new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeCastExpression (rv, (new PointerType(to)).get_cname ()));
			var holds = new CCodeFunctionCall (new CCodeIdentifier ("G_VALUE_HOLDS"));
			holds.add_argument (gvalue);
			holds.add_argument (new CCodeIdentifier (to.get_type_id ()));
			var cond = new CCodeBinaryExpression (CCodeBinaryOperator.AND, holds, ccall);
			var warn = new CCodeFunctionCall (new CCodeIdentifier ("g_warning"));
			warn.add_argument (new CCodeConstant ("\"Invalid GValue unboxing (wrong type or NULL)\""));
			var fail = new CCodeCommaExpression ();
			fail.append_expression (warn);
			fail.append_expression (ctemp);
			rv = new CCodeConditionalExpression (cond, rv,  fail);
		}

		return rv;
	}

	int next_variant_function_id = 0;

	public CCodeExpression? try_cast_variant_to_type (CCodeExpression ccodeexpr, DataType from, DataType to, Expression? expr = null) {
		if (from == null || gvariant_type == null || from.data_type != gvariant_type) {
			return null;
		}

		string variant_func = "_variant_get%d".printf (++next_variant_function_id);

		var ccall = new CCodeFunctionCall (new CCodeIdentifier (variant_func));
		ccall.add_argument (ccodeexpr);

		var cfunc = new CCodeFunction (variant_func);
		cfunc.modifiers = CCodeModifiers.STATIC;
		cfunc.add_parameter (new CCodeParameter ("value", "GVariant*"));

		if (!to.is_real_non_null_struct_type ()) {
			cfunc.return_type = to.get_cname ();
		}

		if (to.is_real_non_null_struct_type ()) {
			// structs are returned via out parameter
			cfunc.add_parameter (new CCodeParameter ("result", to.get_cname () + "*"));
		} else if (to is ArrayType) {
			// return array length if appropriate
			var array_type = (ArrayType) to;

			for (int dim = 1; dim <= array_type.rank; dim++) {
				var temp_decl = get_temp_variable (int_type, false, expr);
				emit_temp_var (temp_decl);

				ccall.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, get_variable_cexpression (temp_decl.name)));
				cfunc.add_parameter (new CCodeParameter (get_array_length_cname ("result", dim), "int*"));
				append_array_length (expr, get_variable_cexpression (temp_decl.name));
			}
		}

		push_function (cfunc);

		var result = deserialize_expression (to, new CCodeIdentifier ("value"), new CCodeIdentifier ("*result"));
		ccode.add_return (result);

		pop_function ();

		cfile.add_function_declaration (cfunc);
		cfile.add_function (cfunc);

		return ccall;
	}

	public virtual CCodeExpression? deserialize_expression (DataType type, CCodeExpression variant_expr, CCodeExpression? expr, CCodeExpression? error_expr = null, out bool may_fail = null) {
		return null;
	}

	public virtual CCodeExpression? serialize_expression (DataType type, CCodeExpression expr) {
		return null;
	}

	public override void visit_cast_expression (CastExpression expr) {
		var valuecast = try_cast_value_to_type (get_cvalue (expr.inner), expr.inner.value_type, expr.type_reference, expr);
		if (valuecast != null) {
			set_cvalue (expr, valuecast);
			return;
		}

		var variantcast = try_cast_variant_to_type (get_cvalue (expr.inner), expr.inner.value_type, expr.type_reference, expr);
		if (variantcast != null) {
			set_cvalue (expr, variantcast);
			return;
		}

		generate_type_declaration (expr.type_reference, cfile);

		var cl = expr.type_reference.data_type as Class;
		var iface = expr.type_reference.data_type as Interface;
		if (context.profile == Profile.GOBJECT && (iface != null || (cl != null && !cl.is_compact))) {
			// checked cast for strict subtypes of GTypeInstance
			if (expr.is_silent_cast) {
				var temp_decl = get_temp_variable (expr.inner.value_type, expr.inner.value_type.value_owned, expr, false);
				emit_temp_var (temp_decl);
				var ctemp = get_variable_cexpression (temp_decl.name);

				ccode.add_assignment (ctemp, get_cvalue (expr.inner));
				var ccheck = create_type_check (ctemp, expr.type_reference);
				var ccast = new CCodeCastExpression (ctemp, expr.type_reference.get_cname ());
				var cnull = new CCodeConstant ("NULL");
	
				set_cvalue (expr, new CCodeConditionalExpression (ccheck, ccast, cnull));
			} else {
				set_cvalue (expr, generate_instance_cast (get_cvalue (expr.inner), expr.type_reference.data_type));
			}
		} else {
			if (expr.is_silent_cast) {
				expr.error = true;
				Report.error (expr.source_reference, "Operation not supported for this type");
				return;
			}

			// retain array length
			var array_type = expr.type_reference as ArrayType;
			if (array_type != null && expr.inner.value_type is ArrayType) {
				for (int dim = 1; dim <= array_type.rank; dim++) {
					append_array_length (expr, get_array_length_cexpression (expr.inner, dim));
				}
			} else if (array_type != null) {
				// cast from non-array to array, set invalid length
				// required by string.data, e.g.
				for (int dim = 1; dim <= array_type.rank; dim++) {
					append_array_length (expr, new CCodeConstant ("-1"));
				}
			}

			var innercexpr = get_cvalue (expr.inner);
			if (expr.type_reference.data_type is Struct && !expr.type_reference.nullable &&
				expr.inner.value_type.data_type is Struct && expr.inner.value_type.nullable) {
				// nullable integer or float or boolean or struct cast to non-nullable
				innercexpr = new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, innercexpr);
			}
			set_cvalue (expr, new CCodeCastExpression (innercexpr, expr.type_reference.get_cname ()));

			if (expr.type_reference is DelegateType) {
				if (get_delegate_target (expr.inner) != null) {
					set_delegate_target (expr, get_delegate_target (expr.inner));
				} else {
					set_delegate_target (expr, new CCodeConstant ("NULL"));
				}
				if (get_delegate_target_destroy_notify (expr.inner) != null) {
					set_delegate_target_destroy_notify (expr, get_delegate_target_destroy_notify (expr.inner));
				} else {
					set_delegate_target_destroy_notify (expr, new CCodeConstant ("NULL"));
				}
			}
		}
	}
	
	public override void visit_named_argument (NamedArgument expr) {
		set_cvalue (expr, get_cvalue (expr.inner));
	}

	public override void visit_pointer_indirection (PointerIndirection expr) {
		set_cvalue (expr, new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, get_cvalue (expr.inner)));
	}

	public override void visit_addressof_expression (AddressofExpression expr) {
		if (get_cvalue (expr.inner) is CCodeCommaExpression) {
			var ccomma = get_cvalue (expr.inner) as CCodeCommaExpression;
			var inner = ccomma.get_inner ();
			var last = inner.get (inner.size - 1);
			ccomma.set_expression (inner.size - 1, new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, (CCodeExpression) last));
			set_cvalue (expr, ccomma);
		} else {
			set_cvalue (expr, new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, get_cvalue (expr.inner)));
		}
	}

	public override void visit_reference_transfer_expression (ReferenceTransferExpression expr) {
		/* (tmp = var, var = null, tmp) */
		var temp_decl = get_temp_variable (expr.value_type, true, expr, false);
		emit_temp_var (temp_decl);
		var cvar = get_variable_cexpression (temp_decl.name);

		ccode.add_assignment (cvar, get_cvalue (expr.inner));
		if (!(expr.value_type is DelegateType)) {
			ccode.add_assignment (get_cvalue (expr.inner), new CCodeConstant ("NULL"));
		}

		set_cvalue (expr, cvar);

		var array_type = expr.value_type as ArrayType;
		if (array_type != null) {
			for (int dim = 1; dim <= array_type.rank; dim++) {
				append_array_length (expr, get_array_length_cexpression (expr.inner, dim));
			}
		}

		var delegate_type = expr.value_type as DelegateType;
		if (delegate_type != null && delegate_type.delegate_symbol.has_target) {
			var temp_target_decl = get_temp_variable (new PointerType (new VoidType ()), true, expr, false);
			emit_temp_var (temp_target_decl);
			var target_cvar = get_variable_cexpression (temp_target_decl.name);
			CCodeExpression target_destroy_notify;
			var target = get_delegate_target_cexpression (expr.inner, out target_destroy_notify);
			ccode.add_assignment (target_cvar, target);
			set_delegate_target (expr, target_cvar);
			if (target_destroy_notify != null) {
				var temp_target_destroy_notify_decl = get_temp_variable (gdestroynotify_type, true, expr, false);
				emit_temp_var (temp_target_destroy_notify_decl);
				var target_destroy_notify_cvar = get_variable_cexpression (temp_target_destroy_notify_decl.name);
				ccode.add_assignment (target_destroy_notify_cvar, target_destroy_notify);
				ccode.add_assignment (target_destroy_notify, new CCodeConstant ("NULL"));
				set_delegate_target_destroy_notify (expr, target_destroy_notify_cvar);
			}
		}
	}

	public override void visit_binary_expression (BinaryExpression expr) {
		var cleft = get_cvalue (expr.left);
		var cright = get_cvalue (expr.right);

		CCodeExpression? left_chain = null;
		if (expr.chained) {
			var lbe = (BinaryExpression) expr.left;

			var temp_decl = get_temp_variable (lbe.right.value_type, true, null, false);
			emit_temp_var (temp_decl);
			var cvar = get_variable_cexpression (temp_decl.name);
			var ccomma = new CCodeCommaExpression ();
			var clbe = (CCodeBinaryExpression) get_cvalue (lbe);
			if (lbe.chained) {
				clbe = (CCodeBinaryExpression) clbe.right;
			}
			ccomma.append_expression (new CCodeAssignment (cvar, get_cvalue (lbe.right)));
			clbe.right = get_variable_cexpression (temp_decl.name);
			ccomma.append_expression (cleft);
			cleft = cvar;
			left_chain = ccomma;
		}

		CCodeBinaryOperator op;
		if (expr.operator == BinaryOperator.PLUS) {
			op = CCodeBinaryOperator.PLUS;
		} else if (expr.operator == BinaryOperator.MINUS) {
			op = CCodeBinaryOperator.MINUS;
		} else if (expr.operator == BinaryOperator.MUL) {
			op = CCodeBinaryOperator.MUL;
		} else if (expr.operator == BinaryOperator.DIV) {
			op = CCodeBinaryOperator.DIV;
		} else if (expr.operator == BinaryOperator.MOD) {
			if (expr.value_type.equals (double_type)) {
				cfile.add_include ("math.h");
				var ccall = new CCodeFunctionCall (new CCodeIdentifier ("fmod"));
				ccall.add_argument (cleft);
				ccall.add_argument (cright);
				set_cvalue (expr, ccall);
				return;
			} else if (expr.value_type.equals (float_type)) {
				cfile.add_include ("math.h");
				var ccall = new CCodeFunctionCall (new CCodeIdentifier ("fmodf"));
				ccall.add_argument (cleft);
				ccall.add_argument (cright);
				set_cvalue (expr, ccall);
				return;
			} else {
				op = CCodeBinaryOperator.MOD;
			}
		} else if (expr.operator == BinaryOperator.SHIFT_LEFT) {
			op = CCodeBinaryOperator.SHIFT_LEFT;
		} else if (expr.operator == BinaryOperator.SHIFT_RIGHT) {
			op = CCodeBinaryOperator.SHIFT_RIGHT;
		} else if (expr.operator == BinaryOperator.LESS_THAN) {
			op = CCodeBinaryOperator.LESS_THAN;
		} else if (expr.operator == BinaryOperator.GREATER_THAN) {
			op = CCodeBinaryOperator.GREATER_THAN;
		} else if (expr.operator == BinaryOperator.LESS_THAN_OR_EQUAL) {
			op = CCodeBinaryOperator.LESS_THAN_OR_EQUAL;
		} else if (expr.operator == BinaryOperator.GREATER_THAN_OR_EQUAL) {
			op = CCodeBinaryOperator.GREATER_THAN_OR_EQUAL;
		} else if (expr.operator == BinaryOperator.EQUALITY) {
			op = CCodeBinaryOperator.EQUALITY;
		} else if (expr.operator == BinaryOperator.INEQUALITY) {
			op = CCodeBinaryOperator.INEQUALITY;
		} else if (expr.operator == BinaryOperator.BITWISE_AND) {
			op = CCodeBinaryOperator.BITWISE_AND;
		} else if (expr.operator == BinaryOperator.BITWISE_OR) {
			op = CCodeBinaryOperator.BITWISE_OR;
		} else if (expr.operator == BinaryOperator.BITWISE_XOR) {
			op = CCodeBinaryOperator.BITWISE_XOR;
		} else if (expr.operator == BinaryOperator.AND) {
			op = CCodeBinaryOperator.AND;
		} else if (expr.operator == BinaryOperator.OR) {
			op = CCodeBinaryOperator.OR;
		} else if (expr.operator == BinaryOperator.IN) {
			if (expr.right.value_type is ArrayType) {
				var array_type = (ArrayType) expr.right.value_type;
				var node = new CCodeFunctionCall (new CCodeIdentifier (generate_array_contains_wrapper (array_type)));
				node.add_argument (cright);
				node.add_argument (get_array_length_cexpression (expr.right));
				if (array_type.element_type is StructValueType) {
					node.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cleft));
				} else {
					node.add_argument (cleft);
				}
				set_cvalue (expr, node);
			} else {
				set_cvalue (expr, new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, new CCodeBinaryExpression (CCodeBinaryOperator.BITWISE_AND, cright, cleft), cleft));
			}
			return;
		} else {
			assert_not_reached ();
		}
		
		if (expr.operator == BinaryOperator.EQUALITY ||
		    expr.operator == BinaryOperator.INEQUALITY) {
			var left_type = expr.left.target_type;
			var right_type = expr.right.target_type;
			make_comparable_cexpression (ref left_type, ref cleft, ref right_type, ref cright);

			if (left_type is StructValueType && right_type is StructValueType) {
				var equalfunc = generate_struct_equal_function ((Struct) left_type.data_type as Struct);
				var ccall = new CCodeFunctionCall (new CCodeIdentifier (equalfunc));
				ccall.add_argument (cleft);
				ccall.add_argument (cright);
				cleft = ccall;
				cright = new CCodeConstant ("TRUE");
			} else if ((left_type is IntegerType || left_type is FloatingType || left_type is BooleanType) && left_type.nullable &&
			           (right_type is IntegerType || right_type is FloatingType || right_type is BooleanType) && right_type.nullable) {
				var equalfunc = generate_numeric_equal_function ((Struct) left_type.data_type as Struct);
				var ccall = new CCodeFunctionCall (new CCodeIdentifier (equalfunc));
				ccall.add_argument (cleft);
				ccall.add_argument (cright);
				cleft = ccall;
				cright = new CCodeConstant ("TRUE");
			}
		}

		if (!(expr.left.value_type is NullType)
		    && expr.left.value_type.compatible (string_type)
		    && !(expr.right.value_type is NullType)
		    && expr.right.value_type.compatible (string_type)) {
			if (expr.operator == BinaryOperator.PLUS) {
				// string concatenation
				if (expr.left.is_constant () && expr.right.is_constant ()) {
					string left, right;

					if (cleft is CCodeIdentifier) {
						left = ((CCodeIdentifier) cleft).name;
					} else if (cleft is CCodeConstant) {
						left = ((CCodeConstant) cleft).name;
					} else {
						assert_not_reached ();
					}
					if (cright is CCodeIdentifier) {
						right = ((CCodeIdentifier) cright).name;
					} else if (cright is CCodeConstant) {
						right = ((CCodeConstant) cright).name;
					} else {
						assert_not_reached ();
					}

					set_cvalue (expr, new CCodeConstant ("%s %s".printf (left, right)));
					return;
				} else {
					if (context.profile == Profile.POSIX) {
						// convert to strcat(strcpy(malloc(1+strlen(a)+strlen(b)),a),b)
						var strcat = new CCodeFunctionCall (new CCodeIdentifier ("strcat"));
						var strcpy = new CCodeFunctionCall (new CCodeIdentifier ("strcpy"));
						var malloc = new CCodeFunctionCall (new CCodeIdentifier ("malloc"));

						var strlen_a = new CCodeFunctionCall (new CCodeIdentifier ("strlen"));
						strlen_a.add_argument(cleft);
						var strlen_b = new CCodeFunctionCall (new CCodeIdentifier ("strlen"));
						strlen_b.add_argument(cright);
						var newlength = new CCodeBinaryExpression (CCodeBinaryOperator.PLUS, new CCodeIdentifier("1"),
							new CCodeBinaryExpression (CCodeBinaryOperator.PLUS, strlen_a, strlen_b));
						malloc.add_argument(newlength);

						strcpy.add_argument(malloc);
						strcpy.add_argument(cleft);

						strcat.add_argument(strcpy);
						strcat.add_argument(cright);
						set_cvalue (expr, strcat);
					} else {
						// convert to g_strconcat (a, b, NULL)
						var temp_var = get_temp_variable (expr.value_type, true, null, false);
						var temp_ref = get_variable_cexpression (temp_var.name);
						emit_temp_var (temp_var);

						var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_strconcat"));
						ccall.add_argument (cleft);
						ccall.add_argument (cright);
						ccall.add_argument (new CCodeConstant("NULL"));

						ccode.add_assignment (temp_ref, ccall);
						set_cvalue (expr, temp_ref);
					}
					return;
				}
			} else if (expr.operator == BinaryOperator.EQUALITY
			           || expr.operator == BinaryOperator.INEQUALITY
			           || expr.operator == BinaryOperator.LESS_THAN
			           || expr.operator == BinaryOperator.GREATER_THAN
			           || expr.operator == BinaryOperator.LESS_THAN_OR_EQUAL
			           || expr.operator == BinaryOperator.GREATER_THAN_OR_EQUAL) {
				var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_strcmp0"));
				ccall.add_argument (cleft);
				ccall.add_argument (cright);
				cleft = ccall;
				cright = new CCodeConstant ("0");
			}
		}

		set_cvalue (expr, new CCodeBinaryExpression (op, cleft, cright));
		if (left_chain != null) {
			set_cvalue (expr, new CCodeBinaryExpression (CCodeBinaryOperator.AND, left_chain, get_cvalue (expr)));
		}
	}

	public string? get_type_check_function (TypeSymbol type) {
		var cl = type as Class;
		if (cl != null && cl.type_check_function != null) {
			return cl.type_check_function;
		} else if ((cl != null && cl.is_compact) || type is Struct || type is Enum || type is Delegate) {
			return null;
		} else {
			return type.get_upper_case_cname ("IS_");
		}
	}

	CCodeExpression? create_type_check (CCodeNode ccodenode, DataType type) {
		var et = type as ErrorType;
		if (et != null && et.error_code != null) {
			var matches_call = new CCodeFunctionCall (new CCodeIdentifier ("g_error_matches"));
			matches_call.add_argument ((CCodeExpression) ccodenode);
			matches_call.add_argument (new CCodeIdentifier (et.error_domain.get_upper_case_cname ()));
			matches_call.add_argument (new CCodeIdentifier (et.error_code.get_cname ()));
			return matches_call;
		} else if (et != null && et.error_domain != null) {
			var instance_domain = new CCodeMemberAccess.pointer ((CCodeExpression) ccodenode, "domain");
			var type_domain = new CCodeIdentifier (et.error_domain.get_upper_case_cname ());
			return new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, instance_domain, type_domain);
		} else {
			string type_check_func = get_type_check_function (type.data_type);
			if (type_check_func == null) {
				return new CCodeInvalidExpression ();
			}
			var ccheck = new CCodeFunctionCall (new CCodeIdentifier (type_check_func));
			ccheck.add_argument ((CCodeExpression) ccodenode);
			return ccheck;
		}
	}

	string generate_array_contains_wrapper (ArrayType array_type) {
		string array_contains_func = "_vala_%s_array_contains".printf (array_type.element_type.get_lower_case_cname ());

		if (!add_wrapper (array_contains_func)) {
			return array_contains_func;
		}

		var function = new CCodeFunction (array_contains_func, "gboolean");
		function.modifiers = CCodeModifiers.STATIC;

		function.add_parameter (new CCodeParameter ("stack", array_type.get_cname ()));
		function.add_parameter (new CCodeParameter ("stack_length", "int"));
		if (array_type.element_type is StructValueType) {
			function.add_parameter (new CCodeParameter ("needle", array_type.element_type.get_cname () + "*"));
		} else {
			function.add_parameter (new CCodeParameter ("needle", array_type.element_type.get_cname ()));
		}

		push_function (function);

		ccode.add_declaration ("int", new CCodeVariableDeclarator ("i"));

		var cloop_initializer = new CCodeAssignment (new CCodeIdentifier ("i"), new CCodeConstant ("0"));
		var cloop_condition = new CCodeBinaryExpression (CCodeBinaryOperator.LESS_THAN, new CCodeIdentifier ("i"), new CCodeIdentifier ("stack_length"));
		var cloop_iterator = new CCodeUnaryExpression (CCodeUnaryOperator.POSTFIX_INCREMENT, new CCodeIdentifier ("i"));
		ccode.open_for (cloop_initializer, cloop_condition, cloop_iterator);

		var celement = new CCodeElementAccess (new CCodeIdentifier ("stack"), new CCodeIdentifier ("i"));
		var cneedle = new CCodeIdentifier ("needle");
		CCodeBinaryExpression cif_condition;
		if (array_type.element_type.compatible (string_type)) {
			var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_strcmp0"));
			ccall.add_argument (celement);
			ccall.add_argument (cneedle);
			cif_condition = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, ccall, new CCodeConstant ("0"));
		} else if (array_type.element_type is StructValueType) {
			var equalfunc = generate_struct_equal_function ((Struct) array_type.element_type.data_type as Struct);
			var ccall = new CCodeFunctionCall (new CCodeIdentifier (equalfunc));
			ccall.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, celement));
			ccall.add_argument (cneedle);
			cif_condition = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, ccall, new CCodeConstant ("TRUE"));
		} else {
			cif_condition = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, cneedle, celement);
		}

		ccode.open_if (cif_condition);
		ccode.add_return (new CCodeConstant ("TRUE"));
		ccode.close ();

		ccode.close ();

		ccode.add_return (new CCodeConstant ("FALSE"));

		pop_function ();

		cfile.add_function_declaration (function);
		cfile.add_function (function);

		return array_contains_func;
	}

	public override void visit_type_check (TypeCheck expr) {
		generate_type_declaration (expr.type_reference, cfile);

		set_cvalue (expr, create_type_check (get_cvalue (expr.expression), expr.type_reference));
		if (get_cvalue (expr) is CCodeInvalidExpression) {
			Report.error (expr.source_reference, "type check expressions not supported for compact classes, structs, and enums");
		}
	}

	public override void visit_lambda_expression (LambdaExpression lambda) {
		// use instance position from delegate
		var dt = (DelegateType) lambda.target_type;
		lambda.method.cinstance_parameter_position = dt.delegate_symbol.cinstance_parameter_position;

		lambda.accept_children (this);

		bool expr_owned = lambda.value_type.value_owned;

		set_cvalue (lambda, new CCodeIdentifier (lambda.method.get_cname ()));

		var delegate_type = (DelegateType) lambda.target_type;
		if (lambda.method.closure) {
			int block_id = get_block_id (current_closure_block);
			var delegate_target = get_variable_cexpression ("_data%d_".printf (block_id));
			if (expr_owned || delegate_type.is_called_once) {
				var ref_call = new CCodeFunctionCall (new CCodeIdentifier ("block%d_data_ref".printf (block_id)));
				ref_call.add_argument (delegate_target);
				delegate_target = ref_call;
				set_delegate_target_destroy_notify (lambda, new CCodeIdentifier ("block%d_data_unref".printf (block_id)));
			} else {
				set_delegate_target_destroy_notify (lambda, new CCodeConstant ("NULL"));
			}
			set_delegate_target (lambda, delegate_target);
		} else if (get_this_type () != null || in_constructor) {
			CCodeExpression delegate_target = get_result_cexpression ("self");
			if (expr_owned || delegate_type.is_called_once) {
				if (get_this_type () != null) {
					var ref_call = new CCodeFunctionCall (get_dup_func_expression (get_this_type (), lambda.source_reference));
					ref_call.add_argument (delegate_target);
					delegate_target = ref_call;
					set_delegate_target_destroy_notify (lambda, get_destroy_func_expression (get_this_type ()));
				} else {
					// in constructor
					var ref_call = new CCodeFunctionCall (new CCodeIdentifier ("g_object_ref"));
					ref_call.add_argument (delegate_target);
					delegate_target = ref_call;
					set_delegate_target_destroy_notify (lambda, new CCodeIdentifier ("g_object_unref"));
				}
			} else {
				set_delegate_target_destroy_notify (lambda, new CCodeConstant ("NULL"));
			}
			set_delegate_target (lambda, delegate_target);
		} else {
			set_delegate_target (lambda, new CCodeConstant ("NULL"));
			set_delegate_target_destroy_notify (lambda, new CCodeConstant ("NULL"));
		}
	}

	public CCodeExpression convert_from_generic_pointer (CCodeExpression cexpr, DataType actual_type) {
		var result = cexpr;
		if (is_reference_type_argument (actual_type) || is_nullable_value_type_argument (actual_type)) {
			result = new CCodeCastExpression (cexpr, actual_type.get_cname ());
		} else if (is_signed_integer_type_argument (actual_type)) {
			var cconv = new CCodeFunctionCall (new CCodeIdentifier ("GPOINTER_TO_INT"));
			cconv.add_argument (cexpr);
			result = cconv;
		} else if (is_unsigned_integer_type_argument (actual_type)) {
			var cconv = new CCodeFunctionCall (new CCodeIdentifier ("GPOINTER_TO_UINT"));
			cconv.add_argument (cexpr);
			result = cconv;
		}
		return result;
	}

	public CCodeExpression convert_to_generic_pointer (CCodeExpression cexpr, DataType actual_type) {
		var result = cexpr;
		if (is_signed_integer_type_argument (actual_type)) {
			var cconv = new CCodeFunctionCall (new CCodeIdentifier ("GINT_TO_POINTER"));
			cconv.add_argument (cexpr);
			result = cconv;
		} else if (is_unsigned_integer_type_argument (actual_type)) {
			var cconv = new CCodeFunctionCall (new CCodeIdentifier ("GUINT_TO_POINTER"));
			cconv.add_argument (cexpr);
			result = cconv;
		}
		return result;
	}

	// manage memory and implicit casts
	public CCodeExpression transform_expression (CCodeExpression source_cexpr, DataType? expression_type, DataType? target_type, Expression? expr = null) {
		var cexpr = source_cexpr;
		if (expression_type == null) {
			return cexpr;
		}


		if (expression_type.value_owned
		    && expression_type.floating_reference) {
			/* floating reference, sink it.
			 */
			var cl = expression_type.data_type as ObjectTypeSymbol;
			var sink_func = (cl != null) ? cl.get_ref_sink_function () : null;

			if (sink_func != null) {
				var csink = new CCodeFunctionCall (new CCodeIdentifier (sink_func));
				csink.add_argument (cexpr);
				
				cexpr = csink;
			} else {
				Report.error (null, "type `%s' does not support floating references".printf (expression_type.data_type.name));
			}
		}

		bool boxing = (expression_type is ValueType && !expression_type.nullable
		               && target_type is ValueType && target_type.nullable);
		bool unboxing = (expression_type is ValueType && expression_type.nullable
		                 && target_type is ValueType && !target_type.nullable);

		bool gvalue_boxing = (context.profile == Profile.GOBJECT
		                      && target_type != null
		                      && target_type.data_type == gvalue_type
		                      && !(expression_type is NullType)
		                      && expression_type.get_type_id () != "G_TYPE_VALUE");
		bool gvariant_boxing = (context.profile == Profile.GOBJECT
		                        && target_type != null
		                        && target_type.data_type == gvariant_type
		                        && !(expression_type is NullType)
		                        && expression_type.data_type != gvariant_type);

		if (expression_type.value_owned
		    && (target_type == null || !target_type.value_owned || boxing || unboxing)
		    && !gvalue_boxing /* gvalue can assume ownership of value, no need to free it */) {
			// value leaked, destroy it
			var pointer_type = target_type as PointerType;
			if (pointer_type != null && !(pointer_type.base_type is VoidType)) {
				// manual memory management for non-void pointers
				// treat void* special to not leak memory with void* method parameters
			} else if (requires_destroy (expression_type)) {
				var decl = get_temp_variable (expression_type, true, expression_type, false);
				emit_temp_var (decl);
				temp_ref_vars.insert (0, decl);
				ccode.add_assignment (get_variable_cexpression (decl.name), cexpr);
				cexpr = get_variable_cexpression (decl.name);

				if (expression_type is ArrayType && expr != null) {
					var array_type = (ArrayType) expression_type;
					for (int dim = 1; dim <= array_type.rank; dim++) {
						var len_decl = new LocalVariable (int_type.copy (), get_array_length_cname (decl.name, dim));
						emit_temp_var (len_decl);
						ccode.add_assignment (get_variable_cexpression (len_decl.name), get_array_length_cexpression (expr, dim));
					}
				} else if (expression_type is DelegateType && expr != null) {
					var target_decl = new LocalVariable (new PointerType (new VoidType ()), get_delegate_target_cname (decl.name));
					emit_temp_var (target_decl);
					var target_destroy_notify_decl = new LocalVariable (gdestroynotify_type, get_delegate_target_destroy_notify_cname (decl.name));
					emit_temp_var (target_destroy_notify_decl);
					CCodeExpression target_destroy_notify;
					ccode.add_assignment (get_variable_cexpression (target_decl.name), get_delegate_target_cexpression (expr, out target_destroy_notify));
					ccode.add_assignment (get_variable_cexpression (target_destroy_notify_decl.name), target_destroy_notify);

				}
			}
		}

		if (target_type == null) {
			// value will be destroyed, no need for implicit casts
			return cexpr;
		}

		if (gvalue_boxing) {
			// implicit conversion to GValue
			var decl = get_temp_variable (target_type, true, target_type);
			emit_temp_var (decl);

			if (!target_type.value_owned) {
				// boxed GValue leaked, destroy it
				temp_ref_vars.insert (0, decl);
			}

			if (target_type.nullable) {
				var newcall = new CCodeFunctionCall (new CCodeIdentifier ("g_new0"));
				newcall.add_argument (new CCodeConstant ("GValue"));
				newcall.add_argument (new CCodeConstant ("1"));
				var newassignment = new CCodeAssignment (get_variable_cexpression (decl.name), newcall);
				ccode.add_expression (newassignment);
			}

			var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_value_init"));
			if (target_type.nullable) {
				ccall.add_argument (get_variable_cexpression (decl.name));
			} else {
				ccall.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, get_variable_cexpression (decl.name)));
			}
			ccall.add_argument (new CCodeIdentifier (expression_type.get_type_id ()));
			ccode.add_expression (ccall);

			if (requires_destroy (expression_type)) {
				ccall = new CCodeFunctionCall (get_value_taker_function (expression_type));
			} else {
				ccall = new CCodeFunctionCall (get_value_setter_function (expression_type));
			}
			if (target_type.nullable) {
				ccall.add_argument (get_variable_cexpression (decl.name));
			} else {
				ccall.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, get_variable_cexpression (decl.name)));
			}
			if (expression_type.is_real_non_null_struct_type ()) {
				ccall.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cexpr));
			} else {
				ccall.add_argument (cexpr);
			}

			ccode.add_expression (ccall);

			cexpr = get_variable_cexpression (decl.name);

			return cexpr;
		} else if (gvariant_boxing) {
			// implicit conversion to GVariant
			string variant_func = "_variant_new%d".printf (++next_variant_function_id);

			var ccall = new CCodeFunctionCall (new CCodeIdentifier (variant_func));
			ccall.add_argument (cexpr);

			var cfunc = new CCodeFunction (variant_func, "GVariant*");
			cfunc.modifiers = CCodeModifiers.STATIC;
			cfunc.add_parameter (new CCodeParameter ("value", expression_type.get_cname ()));

			if (expression_type is ArrayType) {
				// return array length if appropriate
				var array_type = (ArrayType) expression_type;

				for (int dim = 1; dim <= array_type.rank; dim++) {
					ccall.add_argument (get_array_length_cexpression (expr, dim));
					cfunc.add_parameter (new CCodeParameter (get_array_length_cname ("value", dim), "gint"));
				}
			}

			push_function (cfunc);

			var result = serialize_expression (expression_type, new CCodeIdentifier ("value"));

			// sink floating reference
			var sink = new CCodeFunctionCall (new CCodeIdentifier ("g_variant_ref_sink"));
			sink.add_argument (result);
			ccode.add_return (sink);

			pop_function ();

			cfile.add_function_declaration (cfunc);
			cfile.add_function (cfunc);

			return ccall;
		} else if (boxing) {
			// value needs to be boxed

			var unary = cexpr as CCodeUnaryExpression;
			if (unary != null && unary.operator == CCodeUnaryOperator.POINTER_INDIRECTION) {
				// *expr => expr
				cexpr = unary.inner;
			} else if (cexpr is CCodeIdentifier || cexpr is CCodeMemberAccess) {
				cexpr = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cexpr);
			} else {
				var decl = get_temp_variable (expression_type, expression_type.value_owned, expression_type, false);
				emit_temp_var (decl);

				ccode.add_assignment (get_variable_cexpression (decl.name), cexpr);
				cexpr = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, get_variable_cexpression (decl.name));
			}
		} else if (unboxing) {
			// unbox value

			cexpr = new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, cexpr);
		} else {
			cexpr = get_implicit_cast_expression (cexpr, expression_type, target_type, expr);
		}

		if (target_type.value_owned && (!expression_type.value_owned || boxing || unboxing)) {
			// need to copy value
			if (requires_copy (target_type) && !(expression_type is NullType)) {
				CodeNode node = expr;
				if (node == null) {
					node = expression_type;
				}

				var decl = get_temp_variable (target_type, true, node, false);
				emit_temp_var (decl);
				ccode.add_assignment (get_variable_cexpression (decl.name), get_ref_cexpression (target_type, cexpr, expr, node));
				cexpr = get_variable_cexpression (decl.name);
			}
		}

		return cexpr;
	}

	public virtual CCodeExpression get_implicit_cast_expression (CCodeExpression source_cexpr, DataType? expression_type, DataType? target_type, Expression? expr = null) {
		var cexpr = source_cexpr;

		if (expression_type.data_type != null && expression_type.data_type == target_type.data_type) {
			// same type, no cast required
			return cexpr;
		}

		if (expression_type is NullType) {
			// null literal, no cast required when not converting to generic type pointer
			return cexpr;
		}

		generate_type_declaration (target_type, cfile);

		var cl = target_type.data_type as Class;
		var iface = target_type.data_type as Interface;
		if (context.checking && (iface != null || (cl != null && !cl.is_compact))) {
			// checked cast for strict subtypes of GTypeInstance
			return generate_instance_cast (cexpr, target_type.data_type);
		} else if (target_type.data_type != null && expression_type.get_cname () != target_type.get_cname ()) {
			var st = target_type.data_type as Struct;
			if (target_type.data_type.is_reference_type () || (st != null && st.is_simple_type ())) {
				// don't cast non-simple structs
				return new CCodeCastExpression (cexpr, target_type.get_cname ());
			} else {
				return cexpr;
			}
		} else {
			return cexpr;
		}
	}

	public void store_property (Property prop, Expression? instance, TargetValue value) {
		if (instance is BaseAccess) {
			if (prop.base_property != null) {
				var base_class = (Class) prop.base_property.parent_symbol;
				var vcast = new CCodeFunctionCall (new CCodeIdentifier ("%s_CLASS".printf (base_class.get_upper_case_cname (null))));
				vcast.add_argument (new CCodeIdentifier ("%s_parent_class".printf (current_class.get_lower_case_cname (null))));
				
				var ccall = new CCodeFunctionCall (new CCodeMemberAccess.pointer (vcast, "set_%s".printf (prop.name)));
				ccall.add_argument ((CCodeExpression) get_ccodenode (instance));
				ccall.add_argument (get_cvalue_ (value));

				ccode.add_expression (ccall);
			} else if (prop.base_interface_property != null) {
				var base_iface = (Interface) prop.base_interface_property.parent_symbol;
				string parent_iface_var = "%s_%s_parent_iface".printf (current_class.get_lower_case_cname (null), base_iface.get_lower_case_cname (null));

				var ccall = new CCodeFunctionCall (new CCodeMemberAccess.pointer (new CCodeIdentifier (parent_iface_var), "set_%s".printf (prop.name)));
				ccall.add_argument ((CCodeExpression) get_ccodenode (instance));
				ccall.add_argument (get_cvalue_ (value));

				ccode.add_expression (ccall);
			}
			return;
		}

		var set_func = "g_object_set";
		
		var base_property = prop;
		if (!prop.no_accessor_method) {
			if (prop.base_property != null) {
				base_property = prop.base_property;
			} else if (prop.base_interface_property != null) {
				base_property = prop.base_interface_property;
			}

			if (prop is DynamicProperty) {
				set_func = get_dynamic_property_setter_cname ((DynamicProperty) prop);
			} else {
				generate_property_accessor_declaration (base_property.set_accessor, cfile);
				set_func = base_property.set_accessor.get_cname ();

				if (!prop.external && prop.external_package) {
					// internal VAPI properties
					// only add them once per source file
					if (add_generated_external_symbol (prop)) {
						visit_property (prop);
					}
				}
			}
		}
		
		var ccall = new CCodeFunctionCall (new CCodeIdentifier (set_func));

		if (prop.binding == MemberBinding.INSTANCE) {
			/* target instance is first argument */
			var cinstance = (CCodeExpression) get_ccodenode (instance);

			if (prop.parent_symbol is Struct) {
				// we need to pass struct instance by reference
				var unary = cinstance as CCodeUnaryExpression;
				if (unary != null && unary.operator == CCodeUnaryOperator.POINTER_INDIRECTION) {
					// *expr => expr
					cinstance = unary.inner;
				} else if (cinstance is CCodeIdentifier || cinstance is CCodeMemberAccess) {
					cinstance = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cinstance);
				} else {
					// if instance is e.g. a function call, we can't take the address of the expression
					// (tmp = expr, &tmp)

					var temp_var = get_temp_variable (instance.target_type, true, null, false);
					emit_temp_var (temp_var);
					ccode.add_assignment (get_variable_cexpression (temp_var.name), cinstance);

					cinstance = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, get_variable_cexpression (temp_var.name));
				}
			}

			ccall.add_argument (cinstance);
		}

		if (prop.no_accessor_method) {
			/* property name is second argument of g_object_set */
			ccall.add_argument (prop.get_canonical_cconstant ());
		}

		var cexpr = get_cvalue_ (value);

		if (prop.property_type.is_real_non_null_struct_type ()) {
			cexpr = new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, cexpr);
		}

		var array_type = prop.property_type as ArrayType;

		if (array_type != null && !prop.no_array_length) {
			var temp_var = get_temp_variable (prop.property_type, true, null, false);
			emit_temp_var (temp_var);
			ccode.add_assignment (get_variable_cexpression (temp_var.name), cexpr);
			ccall.add_argument (get_variable_cexpression (temp_var.name));
		} else {
			ccall.add_argument (cexpr);
		}

		if (array_type != null && !prop.no_array_length) {
			for (int dim = 1; dim <= array_type.rank; dim++) {
				ccall.add_argument (get_array_length_cvalue (value, dim));
			}
		} else if (prop.property_type is DelegateType) {
			var delegate_type = (DelegateType) prop.property_type;
			if (delegate_type.delegate_symbol.has_target) {
				ccall.add_argument (get_delegate_target_cvalue (value));
			}
		}

		if (prop.no_accessor_method) {
			ccall.add_argument (new CCodeConstant ("NULL"));
		}

		ccode.add_expression (ccall);
	}

	/* indicates whether a given Expression eligable for an ADDRESS_OF operator
	 * from a vala to C point of view all expressions denoting locals, fields and
	 * parameters are eligable to an ADDRESS_OF operator */
	public bool is_address_of_possible (Expression e) {
		if (gvalue_type != null && e.target_type.data_type == gvalue_type && e.value_type.data_type != gvalue_type) {
			// implicit conversion to GValue is not addressable
			return false;
		}

		var ma = e as MemberAccess;

		if (ma == null) {
			return false;
		}

		return (ma.symbol_reference is Variable);
	}

	/* retrieve the correct address_of expression for a give expression, creates temporary variables
	 * where necessary, ce is the corresponding ccode expression for e */
	public CCodeExpression get_address_of_expression (Expression e, CCodeExpression ce) {
		// is address of trivially possible?
		if (is_address_of_possible (e)) {
			return new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, ce);
		}

		var ccomma = new CCodeCommaExpression ();
		DataType address_of_type;
		if (gvalue_type != null && e.target_type != null && e.target_type.data_type == gvalue_type) {
			// implicit conversion to GValue
			address_of_type = e.target_type;
		} else {
			address_of_type = e.value_type;
		}
		var temp_decl = get_temp_variable (address_of_type, true, null, false);
		var ctemp = get_variable_cexpression (temp_decl.name);
		emit_temp_var (temp_decl);
		ccomma.append_expression (new CCodeAssignment (ctemp, ce));
		ccomma.append_expression (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, ctemp));
		return ccomma;
	}

	public bool add_wrapper (string wrapper_name) {
		return wrappers.add (wrapper_name);
	}

	public bool add_generated_external_symbol (Symbol external_symbol) {
		return generated_external_symbols.add (external_symbol);
	}

	public static DataType get_data_type_for_symbol (TypeSymbol sym) {
		DataType type = null;

		if (sym is Class) {
			type = new ObjectType ((Class) sym);
		} else if (sym is Interface) {
			type = new ObjectType ((Interface) sym);
		} else if (sym is Struct) {
			var st = (Struct) sym;
			if (st.is_boolean_type ()) {
				type = new BooleanType (st);
			} else if (st.is_integer_type ()) {
				type = new IntegerType (st);
			} else if (st.is_floating_type ()) {
				type = new FloatingType (st);
			} else {
				type = new StructValueType (st);
			}
		} else if (sym is Enum) {
			type = new EnumValueType ((Enum) sym);
		} else if (sym is ErrorDomain) {
			type = new ErrorType ((ErrorDomain) sym, null);
		} else if (sym is ErrorCode) {
			type = new ErrorType ((ErrorDomain) sym.parent_symbol, (ErrorCode) sym);
		} else {
			Report.error (null, "internal error: `%s' is not a supported type".printf (sym.get_full_name ()));
			return new InvalidType ();
		}

		return type;
	}

	public CCodeExpression? default_value_for_type (DataType type, bool initializer_expression) {
		var st = type.data_type as Struct;
		var array_type = type as ArrayType;
		if (initializer_expression && !type.nullable &&
		    ((st != null && !st.is_simple_type ()) ||
		     (array_type != null && array_type.fixed_length))) {
			// 0-initialize struct with struct initializer { 0 }
			// only allowed as initializer expression in C
			var clist = new CCodeInitializerList ();
			clist.append (new CCodeConstant ("0"));
			return clist;
		} else if ((type.data_type != null && type.data_type.is_reference_type ())
		           || type.nullable
		           || type is PointerType || type is DelegateType
		           || (array_type != null && !array_type.fixed_length)) {
			return new CCodeConstant ("NULL");
		} else if (type.data_type != null && type.data_type.get_default_value () != null) {
			return new CCodeConstant (type.data_type.get_default_value ());
		} else if (type.type_parameter != null) {
			return new CCodeConstant ("NULL");
		} else if (type is ErrorType) {
			return new CCodeConstant ("NULL");
		}
		return null;
	}
	
	private void create_property_type_check_statement (Property prop, bool check_return_type, TypeSymbol t, bool non_null, string var_name) {
		if (check_return_type) {
			create_type_check_statement (prop, prop.property_type, t, non_null, var_name);
		} else {
			create_type_check_statement (prop, new VoidType (), t, non_null, var_name);
		}
	}

	public void create_type_check_statement (CodeNode method_node, DataType ret_type, TypeSymbol t, bool non_null, string var_name) {
		var ccheck = new CCodeFunctionCall ();

		if (!context.assert) {
			return;
		} else if (context.checking && ((t is Class && !((Class) t).is_compact) || t is Interface)) {
			var ctype_check = new CCodeFunctionCall (new CCodeIdentifier (get_type_check_function (t)));
			ctype_check.add_argument (new CCodeIdentifier (var_name));
			
			CCodeExpression cexpr = ctype_check;
			if (!non_null) {
				var cnull = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, new CCodeIdentifier (var_name), new CCodeConstant ("NULL"));
			
				cexpr = new CCodeBinaryExpression (CCodeBinaryOperator.OR, cnull, ctype_check);
			}
			ccheck.add_argument (cexpr);
		} else if (!non_null) {
			return;
		} else if (t == glist_type || t == gslist_type) {
			// NULL is empty list
			return;
		} else {
			var cnonnull = new CCodeBinaryExpression (CCodeBinaryOperator.INEQUALITY, new CCodeIdentifier (var_name), new CCodeConstant ("NULL"));
			ccheck.add_argument (cnonnull);
		}

		var cm = method_node as CreationMethod;
		if (cm != null && cm.parent_symbol is ObjectTypeSymbol) {
			ccheck.call = new CCodeIdentifier ("g_return_val_if_fail");
			ccheck.add_argument (new CCodeConstant ("NULL"));
		} else if (ret_type is VoidType) {
			/* void function */
			ccheck.call = new CCodeIdentifier ("g_return_if_fail");
		} else {
			ccheck.call = new CCodeIdentifier ("g_return_val_if_fail");

			var cdefault = default_value_for_type (ret_type, false);
			if (cdefault != null) {
				ccheck.add_argument (cdefault);
			} else {
				return;
			}
		}
		
		ccode.add_expression (ccheck);
	}

	public int get_param_pos (double param_pos, bool ellipsis = false) {
		if (!ellipsis) {
			if (param_pos >= 0) {
				return (int) (param_pos * 1000);
			} else {
				return (int) ((100 + param_pos) * 1000);
			}
		} else {
			if (param_pos >= 0) {
				return (int) ((100 + param_pos) * 1000);
			} else {
				return (int) ((200 + param_pos) * 1000);
			}
		}
	}

	public CCodeExpression? get_ccodenode (Expression node) {
		if (get_cvalue (node) == null) {
			node.emit (this);
		}
		return get_cvalue (node);
	}

	public override void visit_class (Class cl) {
	}

	public void create_postcondition_statement (Expression postcondition) {
		var cassert = new CCodeFunctionCall (new CCodeIdentifier ("g_warn_if_fail"));

		postcondition.emit (this);

		cassert.add_argument (get_cvalue (postcondition));

		ccode.add_expression (cassert);
	}

	public virtual bool is_gobject_property (Property prop) {
		return false;
	}

	public DataType? get_this_type () {
		if (current_method != null && current_method.binding == MemberBinding.INSTANCE) {
			return current_method.this_parameter.variable_type;
		} else if (current_property_accessor != null && current_property_accessor.prop.binding == MemberBinding.INSTANCE) {
			return current_property_accessor.prop.this_parameter.variable_type;
		}
		return null;
	}

	public CCodeFunctionCall generate_instance_cast (CCodeExpression expr, TypeSymbol type) {
		var result = new CCodeFunctionCall (new CCodeIdentifier (type.get_upper_case_cname (null)));
		result.add_argument (expr);
		return result;
	}

	void generate_struct_destroy_function (Struct st) {
		if (cfile.add_declaration (st.get_destroy_function ())) {
			// only generate function once per source file
			return;
		}

		var function = new CCodeFunction (st.get_destroy_function (), "void");
		function.modifiers = CCodeModifiers.STATIC;
		function.add_parameter (new CCodeParameter ("self", st.get_cname () + "*"));

		push_function (function);

		foreach (Field f in st.get_fields ()) {
			if (f.binding == MemberBinding.INSTANCE) {
				if (requires_destroy (f.variable_type)) {
					var lhs = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), f.get_cname ());

					var this_access = new MemberAccess.simple ("this");
					this_access.value_type = get_data_type_for_symbol ((TypeSymbol) f.parent_symbol);
					set_cvalue (this_access, new CCodeIdentifier ("(*self)"));

					var ma = new MemberAccess (this_access, f.name);
					ma.symbol_reference = f;
					ma.value_type = f.variable_type.copy ();
					visit_member_access (ma);
					ccode.add_expression (get_unref_expression (lhs, f.variable_type, ma));
				}
			}
		}

		pop_function ();

		cfile.add_function_declaration (function);
		cfile.add_function (function);
	}

	void generate_struct_copy_function (Struct st) {
		if (cfile.add_declaration (st.get_copy_function ())) {
			// only generate function once per source file
			return;
		}

		var function = new CCodeFunction (st.get_copy_function (), "void");
		function.modifiers = CCodeModifiers.STATIC;
		function.add_parameter (new CCodeParameter ("self", "const " + st.get_cname () + "*"));
		function.add_parameter (new CCodeParameter ("dest", st.get_cname () + "*"));

		push_context (new EmitContext ());
		push_function (function);

		foreach (Field f in st.get_fields ()) {
			if (f.binding == MemberBinding.INSTANCE) {
				CCodeExpression copy = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), f.name);
				if (requires_copy (f.variable_type))  {
					var this_access = new MemberAccess.simple ("this");
					this_access.value_type = get_data_type_for_symbol ((TypeSymbol) f.parent_symbol);
					set_cvalue (this_access, new CCodeIdentifier ("(*self)"));
					var ma = new MemberAccess (this_access, f.name);
					ma.symbol_reference = f;
					ma.value_type = f.variable_type.copy ();
					visit_member_access (ma);
					copy = get_ref_cexpression (f.variable_type, copy, ma, f);
				}
				var dest = new CCodeMemberAccess.pointer (new CCodeIdentifier ("dest"), f.name);

				var array_type = f.variable_type as ArrayType;
				if (array_type != null && array_type.fixed_length) {
					// fixed-length (stack-allocated) arrays
					cfile.add_include ("string.h");

					var sizeof_call = new CCodeFunctionCall (new CCodeIdentifier ("sizeof"));
					sizeof_call.add_argument (new CCodeIdentifier (array_type.element_type.get_cname ()));
					var size = new CCodeBinaryExpression (CCodeBinaryOperator.MUL, new CCodeConstant ("%d".printf (array_type.length)), sizeof_call);

					var array_copy_call = new CCodeFunctionCall (new CCodeIdentifier ("memcpy"));
					array_copy_call.add_argument (dest);
					array_copy_call.add_argument (copy);
					array_copy_call.add_argument (size);
					ccode.add_expression (array_copy_call);
				} else {
					ccode.add_assignment (dest, copy);

					if (array_type != null && !f.no_array_length) {
						for (int dim = 1; dim <= array_type.rank; dim++) {
							var len_src = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), get_array_length_cname (f.name, dim));
							var len_dest = new CCodeMemberAccess.pointer (new CCodeIdentifier ("dest"), get_array_length_cname (f.name, dim));
							ccode.add_assignment (len_dest, len_src);
						}
					}
				}
			}
		}

		pop_function ();
		pop_context ();

		cfile.add_function_declaration (function);
		cfile.add_function (function);
	}

	public void return_default_value (DataType return_type) {
		ccode.add_return (default_value_for_type (return_type, false));
	}

	public virtual string? get_custom_creturn_type (Method m) {
		return null;
	}

	public virtual void generate_dynamic_method_wrapper (DynamicMethod method) {
	}

	public virtual bool method_has_wrapper (Method method) {
		return false;
	}

	public virtual CCodeFunctionCall get_param_spec (Property prop) {
		return new CCodeFunctionCall (new CCodeIdentifier (""));
	}

	public virtual CCodeFunctionCall get_signal_creation (Signal sig, TypeSymbol type) {
		return new CCodeFunctionCall (new CCodeIdentifier (""));
	}

	public virtual void register_dbus_info (CCodeBlock block, ObjectTypeSymbol bindable) {
	}

	public virtual string get_dynamic_property_getter_cname (DynamicProperty node) {
		Report.error (node.source_reference, "dynamic properties are not supported for %s".printf (node.dynamic_type.to_string ()));
		return "";
	}

	public virtual string get_dynamic_property_setter_cname (DynamicProperty node) {
		Report.error (node.source_reference, "dynamic properties are not supported for %s".printf (node.dynamic_type.to_string ()));
		return "";
	}

	public virtual string get_dynamic_signal_cname (DynamicSignal node) {
		return "";
	}

	public virtual string get_dynamic_signal_connect_wrapper_name (DynamicSignal node) {
		return "";
	}

	public virtual string get_dynamic_signal_connect_after_wrapper_name (DynamicSignal node) {
		return "";
	}

	public virtual string get_dynamic_signal_disconnect_wrapper_name (DynamicSignal node) {
		return "";
	}

	public virtual void generate_marshaller (List<Parameter> params, DataType return_type, bool dbus = false) {
	}

	public virtual string get_marshaller_function (List<Parameter> params, DataType return_type, string? prefix = null, bool dbus = false) {
		return "";
	}

	public virtual string get_array_length_cname (string array_cname, int dim) {
		return "";
	}

	public virtual string get_parameter_array_length_cname (Parameter param, int dim) {
		return "";
	}

	public virtual CCodeExpression get_array_length_cexpression (Expression array_expr, int dim = -1) {
		return new CCodeConstant ("");
	}

	public virtual CCodeExpression get_array_length_cvalue (TargetValue value, int dim = -1) {
		return new CCodeInvalidExpression ();
	}

	public virtual string get_array_size_cname (string array_cname) {
		return "";
	}

	public virtual void add_simple_check (CodeNode node, bool always_fails = false) {
	}

	public virtual string generate_ready_function (Method m) {
		return "";
	}

	public CCodeExpression? get_cvalue (Expression expr) {
		if (expr.target_value == null) {
			return null;
		}
		var glib_value = (GLibValue) expr.target_value;
		return glib_value.cvalue;
	}

	public CCodeExpression? get_cvalue_ (TargetValue value) {
		var glib_value = (GLibValue) value;
		return glib_value.cvalue;
	}

	public void set_cvalue (Expression expr, CCodeExpression? cvalue) {
		var glib_value = (GLibValue) expr.target_value;
		if (glib_value == null) {
			glib_value = new GLibValue (expr.value_type);
			expr.target_value = glib_value;
		}
		glib_value.cvalue = cvalue;
	}

	public CCodeExpression? get_array_size_cvalue (TargetValue value) {
		var glib_value = (GLibValue) value;
		return glib_value.array_size_cvalue;
	}

	public void set_array_size_cvalue (TargetValue value, CCodeExpression? cvalue) {
		var glib_value = (GLibValue) value;
		glib_value.array_size_cvalue = cvalue;
	}

	public CCodeExpression? get_delegate_target (Expression expr) {
		if (expr.target_value == null) {
			return null;
		}
		var glib_value = (GLibValue) expr.target_value;
		return glib_value.delegate_target_cvalue;
	}

	public void set_delegate_target (Expression expr, CCodeExpression? delegate_target) {
		var glib_value = (GLibValue) expr.target_value;
		if (glib_value == null) {
			glib_value = new GLibValue (expr.value_type);
			expr.target_value = glib_value;
		}
		glib_value.delegate_target_cvalue = delegate_target;
	}

	public CCodeExpression? get_delegate_target_destroy_notify (Expression expr) {
		if (expr.target_value == null) {
			return null;
		}
		var glib_value = (GLibValue) expr.target_value;
		return glib_value.delegate_target_destroy_notify_cvalue;
	}

	public void set_delegate_target_destroy_notify (Expression expr, CCodeExpression? destroy_notify) {
		var glib_value = (GLibValue) expr.target_value;
		if (glib_value == null) {
			glib_value = new GLibValue (expr.value_type);
			expr.target_value = glib_value;
		}
		glib_value.delegate_target_destroy_notify_cvalue = destroy_notify;
	}

	public void append_array_length (Expression expr, CCodeExpression size) {
		var glib_value = (GLibValue) expr.target_value;
		if (glib_value == null) {
			glib_value = new GLibValue (expr.value_type);
			expr.target_value = glib_value;
		}
		glib_value.append_array_length_cvalue (size);
	}

	public List<CCodeExpression>? get_array_lengths (Expression expr) {
		var glib_value = (GLibValue) expr.target_value;
		if (glib_value == null) {
			glib_value = new GLibValue (expr.value_type);
			expr.target_value = glib_value;
		}
		return glib_value.array_length_cvalues;
	}
}

public class Vala.GLibValue : TargetValue {
	public CCodeExpression cvalue;

	public List<CCodeExpression> array_length_cvalues;
	public CCodeExpression? array_size_cvalue;

	public CCodeExpression? delegate_target_cvalue;
	public CCodeExpression? delegate_target_destroy_notify_cvalue;

	public GLibValue (DataType? value_type = null, CCodeExpression? cvalue = null) {
		base (value_type);
		this.cvalue = cvalue;
	}

	public void append_array_length_cvalue (CCodeExpression length_cvalue) {
		if (array_length_cvalues == null) {
			array_length_cvalues = new ArrayList<CCodeExpression> ();
		}
		array_length_cvalues.add (length_cvalue);
	}
}
