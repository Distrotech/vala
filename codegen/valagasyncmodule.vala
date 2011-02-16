/* valagasyncmodule.vala
 *
 * Copyright (C) 2008-2010  Jürg Billeter
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
 */

using GLib;

public class Vala.GAsyncModule : GSignalModule {
	CCodeStruct generate_data_struct (Method m) {
		string dataname = Symbol.lower_case_to_camel_case (m.get_cname ()) + "Data";
		var data = new CCodeStruct ("_" + dataname);

		data.add_field ("int", "_state_");
		data.add_field ("GObject*", "_source_object_");
		data.add_field ("GAsyncResult*", "_res_");
		data.add_field ("GSimpleAsyncResult*", "_async_result");

		if (m.binding == MemberBinding.INSTANCE) {
			var type_sym = (TypeSymbol) m.parent_symbol;
			if (type_sym is ObjectTypeSymbol) {
				data.add_field (type_sym.get_cname () + "*", "self");
			} else {
				data.add_field (type_sym.get_cname (), "self");
			}
		}

		foreach (Parameter param in m.get_parameters ()) {
			var param_type = param.variable_type.copy ();
			param_type.value_owned = true;
			data.add_field (param_type.get_cname (), get_variable_cname (param.name));

			if (param.variable_type is ArrayType) {
				var array_type = (ArrayType) param.variable_type;
				if (!param.no_array_length) {
					for (int dim = 1; dim <= array_type.rank; dim++) {
						data.add_field ("gint", get_parameter_array_length_cname (param, dim));
					}
				}
			} else if (param.variable_type is DelegateType) {
				var deleg_type = (DelegateType) param.variable_type;
				if (deleg_type.delegate_symbol.has_target) {
					data.add_field ("gpointer", get_delegate_target_cname (get_variable_cname (param.name)));
					data.add_field ("GDestroyNotify", get_delegate_target_destroy_notify_cname (get_variable_cname (param.name)));
				}
			}
		}

		if (!(m.return_type is VoidType)) {
			data.add_field (m.return_type.get_cname (), "result");
			if (m.return_type is ArrayType) {
				var array_type = (ArrayType) m.return_type;
				if (!m.no_array_length) {
					for (int dim = 1; dim <= array_type.rank; dim++) {
						data.add_field ("gint", get_array_length_cname ("result", dim));
					}
				}
			} else if (m.return_type is DelegateType) {
				var deleg_type = (DelegateType) m.return_type;
				if (deleg_type.delegate_symbol.has_target) {
					data.add_field ("gpointer", get_delegate_target_cname ("result"));
					data.add_field ("GDestroyNotify", get_delegate_target_destroy_notify_cname ("result"));
				}
			}
		}

		return data;
	}

	CCodeFunction generate_free_function (Method m) {
		var dataname = Symbol.lower_case_to_camel_case (m.get_cname ()) + "Data";

		var freefunc = new CCodeFunction (m.get_real_cname () + "_data_free", "void");
		freefunc.modifiers = CCodeModifiers.STATIC;
		freefunc.add_parameter (new CCodeParameter ("_data", "gpointer"));

		var freeblock = new CCodeBlock ();
		freefunc.block = freeblock;

		var datadecl = new CCodeDeclaration (dataname + "*");
		datadecl.add_declarator (new CCodeVariableDeclarator ("data", new CCodeIdentifier ("_data")));
		freeblock.add_statement (datadecl);

		push_context (new EmitContext (m));

		foreach (Parameter param in m.get_parameters ()) {
			if (param.direction != ParameterDirection.OUT) {
				bool is_unowned_delegate = param.variable_type is DelegateType && !param.variable_type.value_owned;

				var param_type = param.variable_type.copy ();
				param_type.value_owned = true;

				if (requires_destroy (param_type) && !is_unowned_delegate) {
					// do not try to access closure blocks
					bool old_captured = param.captured;
					param.captured = false;

					freeblock.add_statement (new CCodeExpressionStatement (destroy_parameter (param)));

					param.captured = old_captured;
				}
			}
		}

		if (requires_destroy (m.return_type)) {
			/* this is very evil. */
			var v = new LocalVariable (m.return_type, ".result");
			var ma = new MemberAccess.simple (".result");
			ma.symbol_reference = v;
			ma.value_type = v.variable_type.copy ();
			visit_member_access (ma);
			var unref_expr = get_unref_expression (new CCodeMemberAccess.pointer (new CCodeIdentifier ("data"), "result"), m.return_type, ma);
			freeblock.add_statement (new CCodeExpressionStatement (unref_expr));
		}

		if (m.binding == MemberBinding.INSTANCE) {
			var this_type = m.this_parameter.variable_type.copy ();
			this_type.value_owned = true;

			if (requires_destroy (this_type)) {
				var ma = new MemberAccess.simple ("this");
				ma.symbol_reference = m.this_parameter;
				ma.value_type = m.this_parameter.variable_type.copy ();
				visit_member_access (ma);
				freeblock.add_statement (new CCodeExpressionStatement (get_unref_expression (new CCodeMemberAccess.pointer (new CCodeIdentifier ("data"), "self"), m.this_parameter.variable_type, ma)));
			}
		}

		pop_context ();

		var freecall = new CCodeFunctionCall (new CCodeIdentifier ("g_slice_free"));
		freecall.add_argument (new CCodeIdentifier (dataname));
		freecall.add_argument (new CCodeIdentifier ("data"));
		freeblock.add_statement (new CCodeExpressionStatement (freecall));

		return freefunc;
	}

	void generate_async_function (Method m) {
		push_context (new EmitContext ());

		var dataname = Symbol.lower_case_to_camel_case (m.get_cname ()) + "Data";
		var asyncfunc = new CCodeFunction (m.get_real_cname (), "void");
		var cparam_map = new HashMap<int,CCodeParameter> (direct_hash, direct_equal);

		cparam_map.set (get_param_pos (-1), new CCodeParameter ("_callback_", "GAsyncReadyCallback"));
		cparam_map.set (get_param_pos (-0.9), new CCodeParameter ("_user_data_", "gpointer"));

		generate_cparameters (m, cfile, cparam_map, asyncfunc, null, null, null, 1);

		if (m.base_method != null || m.base_interface_method != null) {
			// declare *_real_* function
			asyncfunc.modifiers |= CCodeModifiers.STATIC;
			cfile.add_function_declaration (asyncfunc);
		} else if (m.is_private_symbol ()) {
			asyncfunc.modifiers |= CCodeModifiers.STATIC;
		}

		push_function (asyncfunc);

		// logic copied from valaccodemethodmodule
		if (m.overrides || (m.base_interface_method != null && !m.is_abstract && !m.is_virtual)) {
			Method base_method;

			if (m.overrides) {
				base_method = m.base_method;
			} else {
				base_method = m.base_interface_method;
			}

			var base_expression_type = new ObjectType ((ObjectTypeSymbol) base_method.parent_symbol);
			var type_symbol = m.parent_symbol as ObjectTypeSymbol;

			var self_target_type = new ObjectType (type_symbol);
			var cself = transform_expression (new CCodeIdentifier ("base"), base_expression_type, self_target_type);
			ccode.add_declaration ("%s *".printf (type_symbol.get_cname ()), new CCodeVariableDeclarator ("self"));
			ccode.add_assignment (new CCodeIdentifier ("self"), cself);
		}

		var dataalloc = new CCodeFunctionCall (new CCodeIdentifier ("g_slice_new0"));
		dataalloc.add_argument (new CCodeIdentifier (dataname));

		var data_var = new CCodeIdentifier ("_data_");

		ccode.add_declaration (dataname + "*", new CCodeVariableDeclarator ("_data_"));
		ccode.add_assignment (data_var, dataalloc);

		var create_result = new CCodeFunctionCall (new CCodeIdentifier ("g_simple_async_result_new"));

		var cl = m.parent_symbol as Class;
		if (m.binding == MemberBinding.INSTANCE &&
		    cl != null && cl.is_subtype_of (gobject_type)) {
			var gobject_cast = new CCodeFunctionCall (new CCodeIdentifier ("G_OBJECT"));
			gobject_cast.add_argument (new CCodeIdentifier ("self"));

			create_result.add_argument (gobject_cast);
		} else {
			if (context.require_glib_version (2, 20)) {
				create_result.add_argument (new CCodeConstant ("NULL"));
			} else {
				var object_creation = new CCodeFunctionCall (new CCodeIdentifier ("g_object_newv"));
				object_creation.add_argument (new CCodeConstant ("G_TYPE_OBJECT"));
				object_creation.add_argument (new CCodeConstant ("0"));
				object_creation.add_argument (new CCodeConstant ("NULL"));

				create_result.add_argument (object_creation);
			}
		}

		create_result.add_argument (new CCodeIdentifier ("_callback_"));
		create_result.add_argument (new CCodeIdentifier ("_user_data_"));
		create_result.add_argument (new CCodeIdentifier (m.get_real_cname ()));

		ccode.add_assignment (new CCodeMemberAccess.pointer (data_var, "_async_result"), create_result);

		var set_op_res_call = new CCodeFunctionCall (new CCodeIdentifier ("g_simple_async_result_set_op_res_gpointer"));
		set_op_res_call.add_argument (new CCodeMemberAccess.pointer (data_var, "_async_result"));
		set_op_res_call.add_argument (data_var);
		set_op_res_call.add_argument (new CCodeIdentifier (m.get_real_cname () + "_data_free"));
		ccode.add_expression (set_op_res_call);

		if (m.binding == MemberBinding.INSTANCE) {
			var this_type = m.this_parameter.variable_type.copy ();
			this_type.value_owned = true;

			// create copy if necessary as variables in async methods may need to be kept alive
			CCodeExpression cself = new CCodeIdentifier ("self");
			if (this_type.is_real_non_null_struct_type ()) {
				cself = new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, cself);
			}
			if (requires_copy (this_type))  {
				var ma = new MemberAccess.simple ("this");
				ma.symbol_reference = m.this_parameter;
				ma.value_type = m.this_parameter.variable_type.copy ();
				visit_member_access (ma);
				cself = get_ref_cexpression (m.this_parameter.variable_type, cself, ma, m.this_parameter);
			}

			ccode.add_assignment (new CCodeMemberAccess.pointer (data_var, "self"), cself);
		}

		foreach (Parameter param in m.get_parameters ()) {
			if (param.direction != ParameterDirection.OUT) {
				var param_type = param.variable_type.copy ();
				param_type.value_owned = true;

				// create copy if necessary as variables in async methods may need to be kept alive
				CCodeExpression cparam = new CCodeIdentifier (get_variable_cname (param.name));
				if (param.variable_type.is_real_non_null_struct_type ()) {
					cparam = new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, cparam);
				}
				if (requires_copy (param_type) && !param.variable_type.value_owned)  {
					var ma = new MemberAccess.simple (param.name);
					ma.symbol_reference = param;
					ma.value_type = param.variable_type.copy ();
					visit_member_access (ma);
					cparam = get_ref_cexpression (param.variable_type, cparam, ma, param);
				}

				ccode.add_assignment (new CCodeMemberAccess.pointer (data_var, get_variable_cname (param.name)), cparam);
				if (param.variable_type is ArrayType) {
					var array_type = (ArrayType) param.variable_type;
					if (!param.no_array_length) {
						for (int dim = 1; dim <= array_type.rank; dim++) {
							ccode.add_assignment (new CCodeMemberAccess.pointer (data_var, get_parameter_array_length_cname (param, dim)), new CCodeIdentifier (get_parameter_array_length_cname (param, dim)));
						}
					}
				} else if (param.variable_type is DelegateType) {
					var deleg_type = (DelegateType) param.variable_type;
					if (deleg_type.delegate_symbol.has_target) {
						ccode.add_assignment (new CCodeMemberAccess.pointer (data_var, get_delegate_target_cname (get_variable_cname (param.name))), new CCodeIdentifier (get_delegate_target_cname (get_variable_cname (param.name))));
						if (deleg_type.value_owned) {
							ccode.add_assignment (new CCodeMemberAccess.pointer (data_var, get_delegate_target_destroy_notify_cname (get_variable_cname (param.name))), new CCodeIdentifier (get_delegate_target_destroy_notify_cname (get_variable_cname (param.name))));
						}
					}
				}
			}
		}

		var ccall = new CCodeFunctionCall (new CCodeIdentifier (m.get_real_cname () + "_co"));
		ccall.add_argument (data_var);
		ccode.add_expression (ccall);

		cfile.add_function (asyncfunc);

		pop_context ();
	}

	void append_struct (CCodeStruct structure) {
		var typename = new CCodeVariableDeclarator (structure.name.substring (1));
		var typedef = new CCodeTypeDefinition ("struct " + structure.name, typename);
		cfile.add_type_declaration (typedef);
		cfile.add_type_definition (structure);
	}

	void append_function (CCodeFunction function) {
		cfile.add_function_declaration (function);
		cfile.add_function (function);
	}

	public override void generate_method_declaration (Method m, CCodeFile decl_space) {
		if (m.coroutine) {
			if (add_symbol_declaration (decl_space, m, m.get_cname ())) {
				return;
			}

			var asyncfunc = new CCodeFunction (m.get_cname (), "void");
			var cparam_map = new HashMap<int,CCodeParameter> (direct_hash, direct_equal);
			cparam_map.set (get_param_pos (-1), new CCodeParameter ("_callback_", "GAsyncReadyCallback"));
			cparam_map.set (get_param_pos (-0.9), new CCodeParameter ("_user_data_", "gpointer"));

			generate_cparameters (m, decl_space, cparam_map, asyncfunc, null, null, null, 1);

			if (m.is_private_symbol ()) {
				asyncfunc.modifiers |= CCodeModifiers.STATIC;
			}

			decl_space.add_function_declaration (asyncfunc);

			var finishfunc = new CCodeFunction (m.get_finish_cname ());
			cparam_map = new HashMap<int,CCodeParameter> (direct_hash, direct_equal);
			cparam_map.set (get_param_pos (0.1), new CCodeParameter ("_res_", "GAsyncResult*"));

			generate_cparameters (m, decl_space, cparam_map, finishfunc, null, null, null, 2);

			if (m.is_private_symbol ()) {
				finishfunc.modifiers |= CCodeModifiers.STATIC;
			}

			decl_space.add_function_declaration (finishfunc);
		} else {
			base.generate_method_declaration (m, decl_space);
		}
	}

	public override void visit_method (Method m) {
		if (m.coroutine) {
			cfile.add_include ("gio/gio.h");
			if (!m.is_internal_symbol ()) {
				header_file.add_include ("gio/gio.h");
			}

			if (!m.is_abstract && m.body != null) {
				var data = generate_data_struct (m);

				closure_struct = data;

				append_function (generate_free_function (m));
				generate_async_function (m);
				generate_finish_function (m);

				// append the _co function
				base.visit_method (m);
				closure_struct = null;

				// only append data struct here to make sure all struct member
				// types are declared before the struct definition
				append_struct (data);
			} else {
				generate_method_declaration (m, cfile);

				if (!m.is_internal_symbol ()) {
					generate_method_declaration (m, header_file);
				}
				if (!m.is_private_symbol ()) {
					generate_method_declaration (m, internal_header_file);
				}
			}

			if (m.is_abstract || m.is_virtual) {
				// generate virtual function wrappers
				var cparam_map = new HashMap<int,CCodeParameter> (direct_hash, direct_equal);
				var carg_map = new HashMap<int,CCodeExpression> (direct_hash, direct_equal);
				generate_vfunc (m, new VoidType (), cparam_map, carg_map, "", 1);

				cparam_map = new HashMap<int,CCodeParameter> (direct_hash, direct_equal);
				carg_map = new HashMap<int,CCodeExpression> (direct_hash, direct_equal);
				generate_vfunc (m, m.return_type, cparam_map, carg_map, "_finish", 2);
			}
		} else {
			base.visit_method (m);
		}
	}


	void generate_finish_function (Method m) {
		push_context (new EmitContext ());

		string dataname = Symbol.lower_case_to_camel_case (m.get_cname ()) + "Data";

		var finishfunc = new CCodeFunction (m.get_finish_real_cname ());

		var cparam_map = new HashMap<int,CCodeParameter> (direct_hash, direct_equal);

		cparam_map.set (get_param_pos (0.1), new CCodeParameter ("_res_", "GAsyncResult*"));

		generate_cparameters (m, cfile, cparam_map, finishfunc, null, null, null, 2);

		if (m.is_private_symbol () || m.base_method != null || m.base_interface_method != null) {
			finishfunc.modifiers |= CCodeModifiers.STATIC;
		}

		push_function (finishfunc);

		var return_type = m.return_type;
		if (!(return_type is VoidType) && !return_type.is_real_non_null_struct_type ()) {
			ccode.add_declaration (m.return_type.get_cname (), new CCodeVariableDeclarator ("result"));
		}

		var data_var = new CCodeIdentifier ("_data_");

		ccode.add_declaration (dataname + "*", new CCodeVariableDeclarator ("_data_"));

		var simple_async_result_cast = new CCodeFunctionCall (new CCodeIdentifier ("G_SIMPLE_ASYNC_RESULT"));
		simple_async_result_cast.add_argument (new CCodeIdentifier ("_res_"));

		if (m.get_error_types ().size > 0) {
			// propagate error from async method
			var propagate_error = new CCodeFunctionCall (new CCodeIdentifier ("g_simple_async_result_propagate_error"));
			propagate_error.add_argument (simple_async_result_cast);
			propagate_error.add_argument (new CCodeIdentifier ("error"));

			ccode.open_if (propagate_error);
			return_default_value (return_type);
			ccode.close ();
		}

		var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_simple_async_result_get_op_res_gpointer"));
		ccall.add_argument (simple_async_result_cast);
		ccode.add_assignment (data_var, ccall);

		foreach (Parameter param in m.get_parameters ()) {
			if (param.direction != ParameterDirection.IN) {
				ccode.add_assignment (new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier (param.name)), new CCodeMemberAccess.pointer (data_var, get_variable_cname (param.name)));
				if (!(param.variable_type is ValueType) || param.variable_type.nullable) {
					ccode.add_assignment (new CCodeMemberAccess.pointer (data_var, get_variable_cname (param.name)), new CCodeConstant ("NULL"));
				}
			}
		}

		if (return_type.is_real_non_null_struct_type ()) {
			// structs are returned via out parameter
			CCodeExpression cexpr = new CCodeMemberAccess.pointer (data_var, "result");
			if (requires_copy (return_type)) {
				cexpr = get_ref_cexpression (return_type, cexpr, null, return_type);
			}
			ccode.add_assignment (new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier ("result")), cexpr);
		} else if (!(return_type is VoidType)) {
			ccode.add_assignment (new CCodeIdentifier ("result"), new CCodeMemberAccess.pointer (data_var, "result"));
			if (return_type is ArrayType) {
				var array_type = (ArrayType) return_type;
				if (!m.no_array_length) {
					for (int dim = 1; dim <= array_type.rank; dim++) {
						ccode.add_assignment (new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier (get_array_length_cname ("result", dim))), new CCodeMemberAccess.pointer (data_var, get_array_length_cname ("result", dim)));
					}
				}
			} else if (return_type is DelegateType && ((DelegateType) return_type).delegate_symbol.has_target) {
				ccode.add_assignment (new CCodeUnaryExpression (CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier (get_delegate_target_cname ("result"))), new CCodeMemberAccess.pointer (data_var, get_delegate_target_cname ("result")));
			}
			if (!(return_type is ValueType) || return_type.nullable) {
				ccode.add_assignment (new CCodeMemberAccess.pointer (data_var, "result"), new CCodeConstant ("NULL"));
			}
			ccode.add_return (new CCodeIdentifier ("result"));
		}

		pop_function ();

		cfile.add_function (finishfunc);

		pop_context ();
	}

	public override string generate_ready_function (Method m) {
		// generate ready callback handler

		var dataname = Symbol.lower_case_to_camel_case (m.get_cname ()) + "Data";

		var readyfunc = new CCodeFunction (m.get_cname () + "_ready", "void");

		if (!add_wrapper (readyfunc.name)) {
			// wrapper already defined
			return readyfunc.name;
		}

		readyfunc.add_parameter (new CCodeParameter ("source_object", "GObject*"));
		readyfunc.add_parameter (new CCodeParameter ("_res_", "GAsyncResult*"));
		readyfunc.add_parameter (new CCodeParameter ("_user_data_", "gpointer"));

		var readyblock = new CCodeBlock ();

		var datadecl = new CCodeDeclaration (dataname + "*");
		datadecl.add_declarator (new CCodeVariableDeclarator ("data"));
		readyblock.add_statement (datadecl);
		readyblock.add_statement (new CCodeExpressionStatement (new CCodeAssignment (new CCodeIdentifier ("data"), new CCodeIdentifier ("_user_data_"))));
		readyblock.add_statement (new CCodeExpressionStatement (new CCodeAssignment (new CCodeMemberAccess.pointer (new CCodeIdentifier ("data"), "_source_object_"), new CCodeIdentifier ("source_object"))));
		readyblock.add_statement (new CCodeExpressionStatement (new CCodeAssignment (new CCodeMemberAccess.pointer (new CCodeIdentifier ("data"), "_res_"), new CCodeIdentifier ("_res_"))));

		var ccall = new CCodeFunctionCall (new CCodeIdentifier (m.get_real_cname () + "_co"));
		ccall.add_argument (new CCodeIdentifier ("data"));
		readyblock.add_statement (new CCodeExpressionStatement (ccall));

		readyfunc.modifiers |= CCodeModifiers.STATIC;

		readyfunc.block = readyblock;

		append_function (readyfunc);

		return readyfunc.name;
	}

	public override void generate_virtual_method_declaration (Method m, CCodeFile decl_space, CCodeStruct type_struct) {
		if (!m.coroutine) {
			base.generate_virtual_method_declaration (m, decl_space, type_struct);
			return;
		}

		if (!m.is_abstract && !m.is_virtual) {
			return;
		}

		var creturn_type = m.return_type;
		if (m.return_type.is_real_non_null_struct_type ()) {
			// structs are returned via out parameter
			creturn_type = new VoidType ();
		}

		// add vfunc field to the type struct
		var vdeclarator = new CCodeFunctionDeclarator (m.vfunc_name);
		var cparam_map = new HashMap<int,CCodeParameter> (direct_hash, direct_equal);

		generate_cparameters (m, decl_space, cparam_map, new CCodeFunction ("fake"), vdeclarator, null, null, 1);

		var vdecl = new CCodeDeclaration ("void");
		vdecl.add_declarator (vdeclarator);
		type_struct.add_declaration (vdecl);

		// add vfunc field to the type struct
		vdeclarator = new CCodeFunctionDeclarator (m.get_finish_vfunc_name ());
		cparam_map = new HashMap<int,CCodeParameter> (direct_hash, direct_equal);

		generate_cparameters (m, decl_space, cparam_map, new CCodeFunction ("fake"), vdeclarator, null, null, 2);

		vdecl = new CCodeDeclaration (creturn_type.get_cname ());
		vdecl.add_declarator (vdeclarator);
		type_struct.add_declaration (vdecl);
	}

	public override void visit_yield_statement (YieldStatement stmt) {
		if (!is_in_coroutine ()) {
			return;
		}

		if (stmt.yield_expression == null) {
			int state = next_coroutine_state++;

			ccode.add_assignment (new CCodeMemberAccess.pointer (new CCodeIdentifier ("data"), "_state_"), new CCodeConstant (state.to_string ()));
			ccode.add_return (new CCodeConstant ("FALSE"));
			ccode.add_label ("_state_%d".printf (state));
			ccode.add_statement (new CCodeEmptyStatement ());

			return;
		}

		if (stmt.yield_expression.error) {
			stmt.error = true;
			return;
		}

		ccode.add_expression (get_cvalue (stmt.yield_expression));

		if (stmt.tree_can_fail && stmt.yield_expression.tree_can_fail) {
			// simple case, no node breakdown necessary

			add_simple_check (stmt.yield_expression);
		}

		/* free temporary objects */

		foreach (LocalVariable local in temp_ref_vars) {
			ccode.add_expression (destroy_local (local));
		}

		temp_ref_vars.clear ();
	}

	public override void return_with_exception (CCodeExpression error_expr)
	{
		if (!is_in_coroutine ()) {
			base.return_with_exception (error_expr);
			return;
		}

		var set_error = new CCodeFunctionCall (new CCodeIdentifier ("g_simple_async_result_set_from_error"));
		set_error.add_argument (new CCodeMemberAccess.pointer (new CCodeIdentifier ("data"), "_async_result"));
		set_error.add_argument (error_expr);
		ccode.add_expression (set_error);

		var free_error = new CCodeFunctionCall (new CCodeIdentifier ("g_error_free"));
		free_error.add_argument (error_expr);
		ccode.add_expression (free_error);

		append_local_free (current_symbol, false);

		complete_async ();
	}

	public override void visit_return_statement (ReturnStatement stmt) {
		base.visit_return_statement (stmt);

		if (!is_in_coroutine ()) {
			return;
		}

		complete_async ();
	}

	public override void generate_cparameters (Method m, CCodeFile decl_space, Map<int,CCodeParameter> cparam_map, CCodeFunction func, CCodeFunctionDeclarator? vdeclarator = null, Map<int,CCodeExpression>? carg_map = null, CCodeFunctionCall? vcall = null, int direction = 3) {
		if (m.coroutine) {
			decl_space.add_include ("gio/gio.h");

			if (direction == 1) {
				cparam_map.set (get_param_pos (-1), new CCodeParameter ("_callback_", "GAsyncReadyCallback"));
				cparam_map.set (get_param_pos (-0.9), new CCodeParameter ("_user_data_", "gpointer"));
				if (carg_map != null) {
					carg_map.set (get_param_pos (-1), new CCodeIdentifier ("_callback_"));
					carg_map.set (get_param_pos (-0.9), new CCodeIdentifier ("_user_data_"));
				}
			} else if (direction == 2) {
				cparam_map.set (get_param_pos (0.1), new CCodeParameter ("_res_", "GAsyncResult*"));
				if (carg_map != null) {
					carg_map.set (get_param_pos (0.1), new CCodeIdentifier ("_res_"));
				}
			}
		}
		base.generate_cparameters (m, decl_space, cparam_map, func, vdeclarator, carg_map, vcall, direction);
	}

	public string generate_async_callback_wrapper () {
		string async_callback_wrapper_func = "_vala_g_async_ready_callback";

		if (!add_wrapper (async_callback_wrapper_func)) {
			return async_callback_wrapper_func;
		}

		var function = new CCodeFunction (async_callback_wrapper_func, "void");
		function.modifiers = CCodeModifiers.STATIC;

		function.add_parameter (new CCodeParameter ("*source_object", "GObject"));
		function.add_parameter (new CCodeParameter ("*res", "GAsyncResult"));
		function.add_parameter (new CCodeParameter ("*user_data", "void"));

		push_function (function);

		var res_ref = new CCodeFunctionCall (new CCodeIdentifier ("g_object_ref"));
		res_ref.add_argument (new CCodeIdentifier ("res"));

		// store reference to async result of inner async function in out async result
		var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_simple_async_result_set_op_res_gpointer"));
		ccall.add_argument (new CCodeIdentifier ("user_data"));
		ccall.add_argument (res_ref);
		ccall.add_argument (new CCodeIdentifier ("g_object_unref"));
		ccode.add_expression (ccall);

		// call user-provided callback
		ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_simple_async_result_complete"));
		ccall.add_argument (new CCodeIdentifier ("user_data"));
		ccode.add_expression (ccall);

		// free async result
		ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_object_unref"));
		ccall.add_argument (new CCodeIdentifier ("user_data"));
		ccode.add_expression (ccall);

		pop_function ();

		cfile.add_function_declaration (function);
		cfile.add_function (function);

		return async_callback_wrapper_func;
	}
}
