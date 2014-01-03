/* valavapicheck.c generated by valac, the Vala compiler
 * generated from valavapicheck.vala, do not modify */

/* valavapicheck.vala
 *
 * Copyright (C) 2007  Mathias Hasselmann
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
 * 	Mathias Hasselmann <mathias.hasselmann@gmx.de>
 */

#include <glib.h>
#include <glib-object.h>
#include <vala.h>
#include <valagee.h>
#include <stdlib.h>
#include <string.h>
#include <gidlmodule.h>
#include <gidlparser.h>
#include <gidlnode.h>
#include <stdio.h>
#include <glib/gstdio.h>


#define VALA_TYPE_VAPI_CHECK (vala_vapi_check_get_type ())
#define VALA_VAPI_CHECK(obj) (G_TYPE_CHECK_INSTANCE_CAST ((obj), VALA_TYPE_VAPI_CHECK, ValaVAPICheck))
#define VALA_VAPI_CHECK_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((klass), VALA_TYPE_VAPI_CHECK, ValaVAPICheckClass))
#define VALA_IS_VAPI_CHECK(obj) (G_TYPE_CHECK_INSTANCE_TYPE ((obj), VALA_TYPE_VAPI_CHECK))
#define VALA_IS_VAPI_CHECK_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), VALA_TYPE_VAPI_CHECK))
#define VALA_VAPI_CHECK_GET_CLASS(obj) (G_TYPE_INSTANCE_GET_CLASS ((obj), VALA_TYPE_VAPI_CHECK, ValaVAPICheckClass))

typedef struct _ValaVAPICheck ValaVAPICheck;
typedef struct _ValaVAPICheckClass ValaVAPICheckClass;
typedef struct _ValaVAPICheckPrivate ValaVAPICheckPrivate;
#define _vala_code_context_unref0(var) ((var == NULL) ? NULL : (var = (vala_code_context_unref (var), NULL)))
#define _vala_source_file_unref0(var) ((var == NULL) ? NULL : (var = (vala_source_file_unref (var), NULL)))
#define _vala_iterable_unref0(var) ((var == NULL) ? NULL : (var = (vala_iterable_unref (var), NULL)))
#define _g_free0(var) (var = (g_free (var), NULL))
#define __g_list_free__g_idl_module_free0_0(var) ((var == NULL) ? NULL : (var = (_g_list_free__g_idl_module_free0_ (var), NULL)))
#define _g_error_free0(var) ((var == NULL) ? NULL : (var = (g_error_free (var), NULL)))
#define _g_io_channel_unref0(var) ((var == NULL) ? NULL : (var = (g_io_channel_unref (var), NULL)))
#define _vala_source_reference_unref0(var) ((var == NULL) ? NULL : (var = (vala_source_reference_unref (var), NULL)))
#define _g_object_unref0(var) ((var == NULL) ? NULL : (var = (g_object_unref (var), NULL)))

struct _ValaVAPICheck {
	GObject parent_instance;
	ValaVAPICheckPrivate * priv;
};

struct _ValaVAPICheckClass {
	GObjectClass parent_class;
};

struct _ValaVAPICheckPrivate {
	ValaCodeContext* _context;
	ValaSourceFile* _gidl;
	ValaSourceFile* _metadata;
	ValaList* _scope;
	ValaSet* _symbols;
};


static gpointer vala_vapi_check_parent_class = NULL;

GType vala_vapi_check_get_type (void) G_GNUC_CONST;
#define VALA_VAPI_CHECK_GET_PRIVATE(o) (G_TYPE_INSTANCE_GET_PRIVATE ((o), VALA_TYPE_VAPI_CHECK, ValaVAPICheckPrivate))
enum  {
	VALA_VAPI_CHECK_DUMMY_PROPERTY,
	VALA_VAPI_CHECK_CONTEXT,
	VALA_VAPI_CHECK_GIDL,
	VALA_VAPI_CHECK_METADATA
};
ValaVAPICheck* vala_vapi_check_new (const gchar* gidlname, ValaCodeContext* context);
ValaVAPICheck* vala_vapi_check_construct (GType object_type, const gchar* gidlname, ValaCodeContext* context);
static void vala_vapi_check_set_gidl (ValaVAPICheck* self, ValaSourceFile* value);
static void vala_vapi_check_set_metadata (ValaVAPICheck* self, ValaSourceFile* value);
static void vala_vapi_check_set_context (ValaVAPICheck* self, ValaCodeContext* value);
static void vala_vapi_check_parse_gidl (ValaVAPICheck* self);
ValaSourceFile* vala_vapi_check_get_gidl (ValaVAPICheck* self);
static void vala_vapi_check_parse_members (ValaVAPICheck* self, const gchar* name, GList* members);
static void _g_idl_module_free0_ (gpointer var);
static void _g_list_free__g_idl_module_free0_ (GList* self);
static void vala_vapi_check_add_symbol (ValaVAPICheck* self, const gchar* name, const gchar* separator);
static gchar* vala_vapi_check_get_scope (ValaVAPICheck* self);
static void vala_vapi_check_enter_scope (ValaVAPICheck* self, const gchar* name);
static void vala_vapi_check_leave_scope (ValaVAPICheck* self);
static gint vala_vapi_check_check_metadata (ValaVAPICheck* self);
ValaSourceFile* vala_vapi_check_get_metadata (ValaVAPICheck* self);
gint vala_vapi_check_run (ValaVAPICheck* self);
static gint vala_vapi_check_main (gchar** args, int args_length1);
ValaCodeContext* vala_vapi_check_get_context (ValaVAPICheck* self);
static void vala_vapi_check_finalize (GObject* obj);
static void _vala_vala_vapi_check_get_property (GObject * object, guint property_id, GValue * value, GParamSpec * pspec);
static void _vala_vala_vapi_check_set_property (GObject * object, guint property_id, const GValue * value, GParamSpec * pspec);
static void _vala_array_destroy (gpointer array, gint array_length, GDestroyNotify destroy_func);
static void _vala_array_free (gpointer array, gint array_length, GDestroyNotify destroy_func);
static gint _vala_array_length (gpointer array);


static glong string_strnlen (gchar* str, glong maxlen) {
	glong result = 0L;
	gchar* end = NULL;
	gchar* _tmp0_ = NULL;
	glong _tmp1_ = 0L;
	gchar* _tmp2_ = NULL;
	gchar* _tmp3_ = NULL;
	_tmp0_ = str;
	_tmp1_ = maxlen;
	_tmp2_ = memchr (_tmp0_, 0, (gsize) _tmp1_);
	end = _tmp2_;
	_tmp3_ = end;
	if (_tmp3_ == NULL) {
		glong _tmp4_ = 0L;
		_tmp4_ = maxlen;
		result = _tmp4_;
		return result;
	} else {
		gchar* _tmp5_ = NULL;
		gchar* _tmp6_ = NULL;
		_tmp5_ = end;
		_tmp6_ = str;
		result = (glong) (_tmp5_ - _tmp6_);
		return result;
	}
}


static gchar* string_substring (const gchar* self, glong offset, glong len) {
	gchar* result = NULL;
	glong string_length = 0L;
	gboolean _tmp0_ = FALSE;
	glong _tmp1_ = 0L;
	gboolean _tmp3_ = FALSE;
	glong _tmp9_ = 0L;
	glong _tmp15_ = 0L;
	glong _tmp18_ = 0L;
	glong _tmp19_ = 0L;
	glong _tmp20_ = 0L;
	glong _tmp21_ = 0L;
	glong _tmp22_ = 0L;
	gchar* _tmp23_ = NULL;
	g_return_val_if_fail (self != NULL, NULL);
	_tmp1_ = offset;
	if (_tmp1_ >= ((glong) 0)) {
		glong _tmp2_ = 0L;
		_tmp2_ = len;
		_tmp0_ = _tmp2_ >= ((glong) 0);
	} else {
		_tmp0_ = FALSE;
	}
	_tmp3_ = _tmp0_;
	if (_tmp3_) {
		glong _tmp4_ = 0L;
		glong _tmp5_ = 0L;
		glong _tmp6_ = 0L;
		_tmp4_ = offset;
		_tmp5_ = len;
		_tmp6_ = string_strnlen ((gchar*) self, _tmp4_ + _tmp5_);
		string_length = _tmp6_;
	} else {
		gint _tmp7_ = 0;
		gint _tmp8_ = 0;
		_tmp7_ = strlen (self);
		_tmp8_ = _tmp7_;
		string_length = (glong) _tmp8_;
	}
	_tmp9_ = offset;
	if (_tmp9_ < ((glong) 0)) {
		glong _tmp10_ = 0L;
		glong _tmp11_ = 0L;
		glong _tmp12_ = 0L;
		_tmp10_ = string_length;
		_tmp11_ = offset;
		offset = _tmp10_ + _tmp11_;
		_tmp12_ = offset;
		g_return_val_if_fail (_tmp12_ >= ((glong) 0), NULL);
	} else {
		glong _tmp13_ = 0L;
		glong _tmp14_ = 0L;
		_tmp13_ = offset;
		_tmp14_ = string_length;
		g_return_val_if_fail (_tmp13_ <= _tmp14_, NULL);
	}
	_tmp15_ = len;
	if (_tmp15_ < ((glong) 0)) {
		glong _tmp16_ = 0L;
		glong _tmp17_ = 0L;
		_tmp16_ = string_length;
		_tmp17_ = offset;
		len = _tmp16_ - _tmp17_;
	}
	_tmp18_ = offset;
	_tmp19_ = len;
	_tmp20_ = string_length;
	g_return_val_if_fail ((_tmp18_ + _tmp19_) <= _tmp20_, NULL);
	_tmp21_ = offset;
	_tmp22_ = len;
	_tmp23_ = g_strndup (((gchar*) self) + _tmp21_, (gsize) _tmp22_);
	result = _tmp23_;
	return result;
}


ValaVAPICheck* vala_vapi_check_construct (GType object_type, const gchar* gidlname, ValaCodeContext* context) {
	ValaVAPICheck * self = NULL;
	ValaCodeContext* _tmp0_ = NULL;
	const gchar* _tmp1_ = NULL;
	ValaSourceFile* _tmp2_ = NULL;
	ValaSourceFile* _tmp3_ = NULL;
	ValaCodeContext* _tmp4_ = NULL;
	const gchar* _tmp5_ = NULL;
	const gchar* _tmp6_ = NULL;
	gint _tmp7_ = 0;
	gint _tmp8_ = 0;
	gchar* _tmp9_ = NULL;
	gchar* _tmp10_ = NULL;
	gchar* _tmp11_ = NULL;
	gchar* _tmp12_ = NULL;
	ValaSourceFile* _tmp13_ = NULL;
	ValaSourceFile* _tmp14_ = NULL;
	ValaCodeContext* _tmp15_ = NULL;
	g_return_val_if_fail (gidlname != NULL, NULL);
	g_return_val_if_fail (context != NULL, NULL);
	self = (ValaVAPICheck*) g_object_new (object_type, NULL);
	_tmp0_ = context;
	_tmp1_ = gidlname;
	_tmp2_ = vala_source_file_new (_tmp0_, VALA_SOURCE_FILE_TYPE_SOURCE, _tmp1_, NULL, FALSE);
	_tmp3_ = _tmp2_;
	vala_vapi_check_set_gidl (self, _tmp3_);
	_vala_source_file_unref0 (_tmp3_);
	_tmp4_ = context;
	_tmp5_ = gidlname;
	_tmp6_ = gidlname;
	_tmp7_ = strlen (_tmp6_);
	_tmp8_ = _tmp7_;
	_tmp9_ = string_substring (_tmp5_, (glong) 0, (glong) (_tmp8_ - 5));
	_tmp10_ = _tmp9_;
	_tmp11_ = g_strconcat (_tmp10_, ".metadata", NULL);
	_tmp12_ = _tmp11_;
	_tmp13_ = vala_source_file_new (_tmp4_, VALA_SOURCE_FILE_TYPE_SOURCE, _tmp12_, NULL, FALSE);
	_tmp14_ = _tmp13_;
	vala_vapi_check_set_metadata (self, _tmp14_);
	_vala_source_file_unref0 (_tmp14_);
	_g_free0 (_tmp12_);
	_g_free0 (_tmp10_);
	_tmp15_ = context;
	vala_vapi_check_set_context (self, _tmp15_);
	return self;
}


ValaVAPICheck* vala_vapi_check_new (const gchar* gidlname, ValaCodeContext* context) {
	return vala_vapi_check_construct (VALA_TYPE_VAPI_CHECK, gidlname, context);
}


static void _g_idl_module_free0_ (gpointer var) {
	(var == NULL) ? NULL : (var = (g_idl_module_free (var), NULL));
}


static void _g_list_free__g_idl_module_free0_ (GList* self) {
	g_list_foreach (self, (GFunc) _g_idl_module_free0_, NULL);
	g_list_free (self);
}


static void vala_vapi_check_parse_gidl (ValaVAPICheck* self) {
	GEqualFunc _tmp0_ = NULL;
	ValaArrayList* _tmp1_ = NULL;
	GHashFunc _tmp2_ = NULL;
	GEqualFunc _tmp3_ = NULL;
	ValaHashSet* _tmp4_ = NULL;
	GError * _inner_error_ = NULL;
	g_return_if_fail (self != NULL);
	_tmp0_ = g_direct_equal;
	_tmp1_ = vala_array_list_new (G_TYPE_STRING, (GBoxedCopyFunc) g_strdup, g_free, _tmp0_);
	_vala_iterable_unref0 (self->priv->_scope);
	self->priv->_scope = (ValaList*) _tmp1_;
	_tmp2_ = g_str_hash;
	_tmp3_ = g_str_equal;
	_tmp4_ = vala_hash_set_new (G_TYPE_STRING, (GBoxedCopyFunc) g_strdup, g_free, _tmp2_, _tmp3_);
	_vala_iterable_unref0 (self->priv->_symbols);
	self->priv->_symbols = (ValaSet*) _tmp4_;
	{
		GList* _tmp5_ = NULL;
		ValaSourceFile* _tmp6_ = NULL;
		const gchar* _tmp7_ = NULL;
		const gchar* _tmp8_ = NULL;
		GList* _tmp9_ = NULL;
		_tmp6_ = self->priv->_gidl;
		_tmp7_ = vala_source_file_get_filename (_tmp6_);
		_tmp8_ = _tmp7_;
		_tmp9_ = g_idl_parse_file (_tmp8_, &_inner_error_);
		_tmp5_ = _tmp9_;
		if (_inner_error_ != NULL) {
			if (_inner_error_->domain == G_MARKUP_ERROR) {
				goto __catch0_g_markup_error;
			}
			g_critical ("file %s: line %d: unexpected error: %s (%s, %d)", __FILE__, __LINE__, _inner_error_->message, g_quark_to_string (_inner_error_->domain), _inner_error_->code);
			g_clear_error (&_inner_error_);
			return;
		}
		{
			GList* module_collection = NULL;
			GList* module_it = NULL;
			module_collection = _tmp5_;
			for (module_it = module_collection; module_it != NULL; module_it = module_it->next) {
				GIdlModule* module = NULL;
				module = (GIdlModule*) module_it->data;
				{
					GIdlModule* _tmp10_ = NULL;
					const gchar* _tmp11_ = NULL;
					GIdlModule* _tmp12_ = NULL;
					GList* _tmp13_ = NULL;
					_tmp10_ = module;
					_tmp11_ = _tmp10_->name;
					_tmp12_ = module;
					_tmp13_ = _tmp12_->entries;
					vala_vapi_check_parse_members (self, _tmp11_, _tmp13_);
				}
			}
			__g_list_free__g_idl_module_free0_0 (module_collection);
		}
	}
	goto __finally0;
	__catch0_g_markup_error:
	{
		GError* e = NULL;
		FILE* _tmp14_ = NULL;
		ValaSourceFile* _tmp15_ = NULL;
		const gchar* _tmp16_ = NULL;
		const gchar* _tmp17_ = NULL;
		GError* _tmp18_ = NULL;
		const gchar* _tmp19_ = NULL;
		e = _inner_error_;
		_inner_error_ = NULL;
		_tmp14_ = stderr;
		_tmp15_ = self->priv->_gidl;
		_tmp16_ = vala_source_file_get_filename (_tmp15_);
		_tmp17_ = _tmp16_;
		_tmp18_ = e;
		_tmp19_ = _tmp18_->message;
		fprintf (_tmp14_, "%s: %s\n", _tmp17_, _tmp19_);
		_g_error_free0 (e);
	}
	__finally0:
	if (_inner_error_ != NULL) {
		g_critical ("file %s: line %d: uncaught error: %s (%s, %d)", __FILE__, __LINE__, _inner_error_->message, g_quark_to_string (_inner_error_->domain), _inner_error_->code);
		g_clear_error (&_inner_error_);
		return;
	}
}


static void vala_vapi_check_add_symbol (ValaVAPICheck* self, const gchar* name, const gchar* separator) {
	const gchar* _tmp0_ = NULL;
	g_return_if_fail (self != NULL);
	g_return_if_fail (name != NULL);
	_tmp0_ = separator;
	if (NULL != _tmp0_) {
		gchar* fullname = NULL;
		gchar* _tmp1_ = NULL;
		gchar* _tmp2_ = NULL;
		const gchar* _tmp3_ = NULL;
		gchar* _tmp4_ = NULL;
		gchar* _tmp5_ = NULL;
		const gchar* _tmp6_ = NULL;
		gchar* _tmp7_ = NULL;
		gchar* _tmp8_ = NULL;
		ValaSet* _tmp9_ = NULL;
		const gchar* _tmp10_ = NULL;
		_tmp1_ = vala_vapi_check_get_scope (self);
		_tmp2_ = _tmp1_;
		_tmp3_ = separator;
		_tmp4_ = g_strconcat (_tmp2_, _tmp3_, NULL);
		_tmp5_ = _tmp4_;
		_tmp6_ = name;
		_tmp7_ = g_strconcat (_tmp5_, _tmp6_, NULL);
		_tmp8_ = _tmp7_;
		_g_free0 (_tmp5_);
		_g_free0 (_tmp2_);
		fullname = _tmp8_;
		_tmp9_ = self->priv->_symbols;
		_tmp10_ = fullname;
		vala_collection_add ((ValaCollection*) _tmp9_, _tmp10_);
		_g_free0 (fullname);
	} else {
		ValaSet* _tmp11_ = NULL;
		const gchar* _tmp12_ = NULL;
		_tmp11_ = self->priv->_symbols;
		_tmp12_ = name;
		vala_collection_add ((ValaCollection*) _tmp11_, _tmp12_);
	}
}


static gchar* vala_vapi_check_get_scope (ValaVAPICheck* self) {
	gchar* result = NULL;
	ValaList* _tmp0_ = NULL;
	ValaList* _tmp1_ = NULL;
	gint _tmp2_ = 0;
	gint _tmp3_ = 0;
	gpointer _tmp4_ = NULL;
	g_return_val_if_fail (self != NULL, NULL);
	_tmp0_ = self->priv->_scope;
	_tmp1_ = self->priv->_scope;
	_tmp2_ = vala_collection_get_size ((ValaCollection*) _tmp1_);
	_tmp3_ = _tmp2_;
	_tmp4_ = vala_list_get (_tmp0_, _tmp3_ - 1);
	result = (gchar*) _tmp4_;
	return result;
}


static void vala_vapi_check_enter_scope (ValaVAPICheck* self, const gchar* name) {
	ValaList* _tmp0_ = NULL;
	const gchar* _tmp1_ = NULL;
	const gchar* _tmp2_ = NULL;
	g_return_if_fail (self != NULL);
	g_return_if_fail (name != NULL);
	_tmp0_ = self->priv->_scope;
	_tmp1_ = name;
	vala_collection_add ((ValaCollection*) _tmp0_, _tmp1_);
	_tmp2_ = name;
	vala_vapi_check_add_symbol (self, _tmp2_, NULL);
}


static void vala_vapi_check_leave_scope (ValaVAPICheck* self) {
	ValaList* _tmp0_ = NULL;
	ValaList* _tmp1_ = NULL;
	gint _tmp2_ = 0;
	gint _tmp3_ = 0;
	g_return_if_fail (self != NULL);
	_tmp0_ = self->priv->_scope;
	_tmp1_ = self->priv->_scope;
	_tmp2_ = vala_collection_get_size ((ValaCollection*) _tmp1_);
	_tmp3_ = _tmp2_;
	vala_list_remove_at (_tmp0_, _tmp3_ - 1);
}


static void vala_vapi_check_parse_members (ValaVAPICheck* self, const gchar* name, GList* members) {
	const gchar* _tmp0_ = NULL;
	GList* _tmp1_ = NULL;
	g_return_if_fail (self != NULL);
	g_return_if_fail (name != NULL);
	_tmp0_ = name;
	vala_vapi_check_enter_scope (self, _tmp0_);
	_tmp1_ = members;
	{
		GList* node_collection = NULL;
		GList* node_it = NULL;
		node_collection = _tmp1_;
		for (node_it = node_collection; node_it != NULL; node_it = node_it->next) {
			GIdlNode* node = NULL;
			node = (GIdlNode*) node_it->data;
			{
				GIdlNode* _tmp2_ = NULL;
				GIdlNodeTypeId _tmp3_ = 0;
				_tmp2_ = node;
				_tmp3_ = _tmp2_->type;
				switch (_tmp3_) {
					case G_IDL_NODE_ENUM:
					{
						GIdlNode* _tmp4_ = NULL;
						const gchar* _tmp5_ = NULL;
						GIdlNode* _tmp6_ = NULL;
						GList* _tmp7_ = NULL;
						_tmp4_ = node;
						_tmp5_ = ((GIdlNodeEnum*) _tmp4_)->gtype_name;
						_tmp6_ = node;
						_tmp7_ = ((GIdlNodeEnum*) _tmp6_)->values;
						vala_vapi_check_parse_members (self, _tmp5_, _tmp7_);
						break;
					}
					case G_IDL_NODE_FUNCTION:
					{
						GIdlNode* _tmp8_ = NULL;
						const gchar* _tmp9_ = NULL;
						GIdlNode* _tmp10_ = NULL;
						GList* _tmp11_ = NULL;
						_tmp8_ = node;
						_tmp9_ = ((GIdlNodeFunction*) _tmp8_)->symbol;
						_tmp10_ = node;
						_tmp11_ = ((GIdlNodeFunction*) _tmp10_)->parameters;
						vala_vapi_check_parse_members (self, _tmp9_, (GList*) _tmp11_);
						break;
					}
					case G_IDL_NODE_BOXED:
					{
						GIdlNode* _tmp12_ = NULL;
						const gchar* _tmp13_ = NULL;
						GIdlNode* _tmp14_ = NULL;
						GList* _tmp15_ = NULL;
						_tmp12_ = node;
						_tmp13_ = ((GIdlNodeBoxed*) _tmp12_)->gtype_name;
						_tmp14_ = node;
						_tmp15_ = ((GIdlNodeBoxed*) _tmp14_)->members;
						vala_vapi_check_parse_members (self, _tmp13_, _tmp15_);
						break;
					}
					case G_IDL_NODE_INTERFACE:
					case G_IDL_NODE_OBJECT:
					{
						GIdlNode* _tmp16_ = NULL;
						const gchar* _tmp17_ = NULL;
						GIdlNode* _tmp18_ = NULL;
						GList* _tmp19_ = NULL;
						_tmp16_ = node;
						_tmp17_ = ((GIdlNodeInterface*) _tmp16_)->gtype_name;
						_tmp18_ = node;
						_tmp19_ = ((GIdlNodeInterface*) _tmp18_)->members;
						vala_vapi_check_parse_members (self, _tmp17_, _tmp19_);
						break;
					}
					case G_IDL_NODE_FIELD:
					case G_IDL_NODE_PARAM:
					{
						GIdlNode* _tmp20_ = NULL;
						const gchar* _tmp21_ = NULL;
						_tmp20_ = node;
						_tmp21_ = _tmp20_->name;
						vala_vapi_check_add_symbol (self, _tmp21_, ".");
						break;
					}
					case G_IDL_NODE_PROPERTY:
					case G_IDL_NODE_SIGNAL:
					{
						GIdlNode* _tmp22_ = NULL;
						const gchar* _tmp23_ = NULL;
						_tmp22_ = node;
						_tmp23_ = _tmp22_->name;
						vala_vapi_check_add_symbol (self, _tmp23_, "::");
						break;
					}
					case G_IDL_NODE_STRUCT:
					{
						GIdlNode* _tmp24_ = NULL;
						const gchar* _tmp25_ = NULL;
						GIdlNode* _tmp26_ = NULL;
						GList* _tmp27_ = NULL;
						_tmp24_ = node;
						_tmp25_ = _tmp24_->name;
						_tmp26_ = node;
						_tmp27_ = ((GIdlNodeStruct*) _tmp26_)->members;
						vala_vapi_check_parse_members (self, _tmp25_, _tmp27_);
						break;
					}
					case G_IDL_NODE_VALUE:
					case G_IDL_NODE_VFUNC:
					{
						break;
					}
					default:
					{
						GIdlNode* _tmp28_ = NULL;
						const gchar* _tmp29_ = NULL;
						GIdlNode* _tmp30_ = NULL;
						GIdlNodeTypeId _tmp31_ = 0;
						_tmp28_ = node;
						_tmp29_ = _tmp28_->name;
						_tmp30_ = node;
						_tmp31_ = _tmp30_->type;
						g_warning ("valavapicheck.vala:121: TODO: %s: Implement support for type %d nodes", _tmp29_, (gint) _tmp31_);
						break;
					}
				}
			}
		}
	}
	vala_vapi_check_leave_scope (self);
}


static gint vala_vapi_check_check_metadata (ValaVAPICheck* self) {
	gint result = 0;
	GError * _inner_error_ = NULL;
	g_return_val_if_fail (self != NULL, 0);
	{
		GIOChannel* metafile = NULL;
		ValaSourceFile* _tmp0_ = NULL;
		const gchar* _tmp1_ = NULL;
		const gchar* _tmp2_ = NULL;
		GIOChannel* _tmp3_ = NULL;
		gchar* line = NULL;
		gint lineno = 0;
		_tmp0_ = self->priv->_metadata;
		_tmp1_ = vala_source_file_get_filename (_tmp0_);
		_tmp2_ = _tmp1_;
		_tmp3_ = g_io_channel_new_file (_tmp2_, "r", &_inner_error_);
		metafile = _tmp3_;
		if (_inner_error_ != NULL) {
			goto __catch1_g_error;
		}
		lineno = 1;
		while (TRUE) {
			GIOStatus _tmp4_ = 0;
			GIOChannel* _tmp5_ = NULL;
			gchar* _tmp6_ = NULL;
			GIOStatus _tmp7_ = 0;
			gchar** tokens = NULL;
			const gchar* _tmp8_ = NULL;
			gchar** _tmp9_ = NULL;
			gchar** _tmp10_ = NULL;
			gint tokens_length1 = 0;
			gint _tokens_size_ = 0;
			gchar* symbol = NULL;
			gchar** _tmp11_ = NULL;
			gint _tmp11__length1 = 0;
			const gchar* _tmp12_ = NULL;
			gchar* _tmp13_ = NULL;
			gboolean _tmp14_ = FALSE;
			const gchar* _tmp15_ = NULL;
			gint _tmp16_ = 0;
			gint _tmp17_ = 0;
			gboolean _tmp21_ = FALSE;
			gint _tmp35_ = 0;
			_tmp5_ = metafile;
			_tmp7_ = g_io_channel_read_line (_tmp5_, &_tmp6_, NULL, NULL, &_inner_error_);
			_g_free0 (line);
			line = _tmp6_;
			_tmp4_ = _tmp7_;
			if (_inner_error_ != NULL) {
				_g_free0 (line);
				_g_io_channel_unref0 (metafile);
				goto __catch1_g_error;
			}
			if (!(G_IO_STATUS_NORMAL == _tmp4_)) {
				break;
			}
			_tmp8_ = line;
			_tmp10_ = _tmp9_ = g_strsplit (_tmp8_, " ", 2);
			tokens = _tmp10_;
			tokens_length1 = _vala_array_length (_tmp9_);
			_tokens_size_ = tokens_length1;
			_tmp11_ = tokens;
			_tmp11__length1 = tokens_length1;
			_tmp12_ = _tmp11_[0];
			_tmp13_ = g_strdup (_tmp12_);
			symbol = _tmp13_;
			_tmp15_ = symbol;
			_tmp16_ = strlen (_tmp15_);
			_tmp17_ = _tmp16_;
			if (_tmp17_ > 0) {
				ValaSet* _tmp18_ = NULL;
				const gchar* _tmp19_ = NULL;
				gboolean _tmp20_ = FALSE;
				_tmp18_ = self->priv->_symbols;
				_tmp19_ = symbol;
				_tmp20_ = vala_collection_contains ((ValaCollection*) _tmp18_, _tmp19_);
				_tmp14_ = !_tmp20_;
			} else {
				_tmp14_ = FALSE;
			}
			_tmp21_ = _tmp14_;
			if (_tmp21_) {
				ValaSourceReference* src = NULL;
				ValaSourceFile* _tmp22_ = NULL;
				gint _tmp23_ = 0;
				ValaSourceLocation _tmp24_ = {0};
				gint _tmp25_ = 0;
				const gchar* _tmp26_ = NULL;
				gint _tmp27_ = 0;
				gint _tmp28_ = 0;
				ValaSourceLocation _tmp29_ = {0};
				ValaSourceReference* _tmp30_ = NULL;
				ValaSourceReference* _tmp31_ = NULL;
				const gchar* _tmp32_ = NULL;
				gchar* _tmp33_ = NULL;
				gchar* _tmp34_ = NULL;
				_tmp22_ = self->priv->_metadata;
				_tmp23_ = lineno;
				vala_source_location_init (&_tmp24_, NULL, _tmp23_, 1);
				_tmp25_ = lineno;
				_tmp26_ = symbol;
				_tmp27_ = strlen (_tmp26_);
				_tmp28_ = _tmp27_;
				vala_source_location_init (&_tmp29_, NULL, _tmp25_, (gint) _tmp28_);
				_tmp30_ = vala_source_reference_new (_tmp22_, &_tmp24_, &_tmp29_);
				src = _tmp30_;
				_tmp31_ = src;
				_tmp32_ = symbol;
				_tmp33_ = g_strdup_printf ("Symbol `%s' not found", _tmp32_);
				_tmp34_ = _tmp33_;
				vala_report_error (_tmp31_, _tmp34_);
				_g_free0 (_tmp34_);
				_vala_source_reference_unref0 (src);
			}
			_tmp35_ = lineno;
			lineno = _tmp35_ + 1;
			_g_free0 (symbol);
			tokens = (_vala_array_free (tokens, tokens_length1, (GDestroyNotify) g_free), NULL);
		}
		result = 0;
		_g_free0 (line);
		_g_io_channel_unref0 (metafile);
		return result;
	}
	goto __finally1;
	__catch1_g_error:
	{
		GError* _error_ = NULL;
		ValaSourceFile* _tmp36_ = NULL;
		const gchar* _tmp37_ = NULL;
		const gchar* _tmp38_ = NULL;
		GError* _tmp39_ = NULL;
		const gchar* _tmp40_ = NULL;
		gchar* _tmp41_ = NULL;
		gchar* _tmp42_ = NULL;
		_error_ = _inner_error_;
		_inner_error_ = NULL;
		_tmp36_ = self->priv->_metadata;
		_tmp37_ = vala_source_file_get_filename (_tmp36_);
		_tmp38_ = _tmp37_;
		_tmp39_ = _error_;
		_tmp40_ = _tmp39_->message;
		_tmp41_ = g_strdup_printf ("%s: %s", _tmp38_, _tmp40_);
		_tmp42_ = _tmp41_;
		vala_report_error (NULL, _tmp42_);
		_g_free0 (_tmp42_);
		result = 1;
		_g_error_free0 (_error_);
		return result;
	}
	__finally1:
	g_critical ("file %s: line %d: uncaught error: %s (%s, %d)", __FILE__, __LINE__, _inner_error_->message, g_quark_to_string (_inner_error_->domain), _inner_error_->code);
	g_clear_error (&_inner_error_);
	return 0;
}


gint vala_vapi_check_run (ValaVAPICheck* self) {
	gint result = 0;
	ValaSourceFile* _tmp0_ = NULL;
	const gchar* _tmp1_ = NULL;
	const gchar* _tmp2_ = NULL;
	gboolean _tmp3_ = FALSE;
	ValaSourceFile* _tmp9_ = NULL;
	const gchar* _tmp10_ = NULL;
	const gchar* _tmp11_ = NULL;
	gboolean _tmp12_ = FALSE;
	gint _tmp18_ = 0;
	g_return_val_if_fail (self != NULL, 0);
	_tmp0_ = self->priv->_gidl;
	_tmp1_ = vala_source_file_get_filename (_tmp0_);
	_tmp2_ = _tmp1_;
	_tmp3_ = g_file_test (_tmp2_, G_FILE_TEST_IS_REGULAR);
	if (!_tmp3_) {
		ValaSourceFile* _tmp4_ = NULL;
		const gchar* _tmp5_ = NULL;
		const gchar* _tmp6_ = NULL;
		gchar* _tmp7_ = NULL;
		gchar* _tmp8_ = NULL;
		_tmp4_ = self->priv->_gidl;
		_tmp5_ = vala_source_file_get_filename (_tmp4_);
		_tmp6_ = _tmp5_;
		_tmp7_ = g_strdup_printf ("%s not found", _tmp6_);
		_tmp8_ = _tmp7_;
		vala_report_error (NULL, _tmp8_);
		_g_free0 (_tmp8_);
		result = 2;
		return result;
	}
	_tmp9_ = self->priv->_metadata;
	_tmp10_ = vala_source_file_get_filename (_tmp9_);
	_tmp11_ = _tmp10_;
	_tmp12_ = g_file_test (_tmp11_, G_FILE_TEST_IS_REGULAR);
	if (!_tmp12_) {
		ValaSourceFile* _tmp13_ = NULL;
		const gchar* _tmp14_ = NULL;
		const gchar* _tmp15_ = NULL;
		gchar* _tmp16_ = NULL;
		gchar* _tmp17_ = NULL;
		_tmp13_ = self->priv->_metadata;
		_tmp14_ = vala_source_file_get_filename (_tmp13_);
		_tmp15_ = _tmp14_;
		_tmp16_ = g_strdup_printf ("%s not found", _tmp15_);
		_tmp17_ = _tmp16_;
		vala_report_error (NULL, _tmp17_);
		_g_free0 (_tmp17_);
		result = 2;
		return result;
	}
	vala_vapi_check_parse_gidl (self);
	_tmp18_ = vala_vapi_check_check_metadata (self);
	result = _tmp18_;
	return result;
}


static gint vala_vapi_check_main (gchar** args, int args_length1) {
	gint result = 0;
	gboolean _tmp0_ = FALSE;
	gchar** _tmp1_ = NULL;
	gint _tmp1__length1 = 0;
	gboolean _tmp5_ = FALSE;
	ValaVAPICheck* vapicheck = NULL;
	gchar** _tmp11_ = NULL;
	gint _tmp11__length1 = 0;
	const gchar* _tmp12_ = NULL;
	ValaCodeContext* _tmp13_ = NULL;
	ValaCodeContext* _tmp14_ = NULL;
	ValaVAPICheck* _tmp15_ = NULL;
	ValaVAPICheck* _tmp16_ = NULL;
	ValaVAPICheck* _tmp17_ = NULL;
	gint _tmp18_ = 0;
	_tmp1_ = args;
	_tmp1__length1 = args_length1;
	if (2 != _tmp1__length1) {
		_tmp0_ = TRUE;
	} else {
		gchar** _tmp2_ = NULL;
		gint _tmp2__length1 = 0;
		const gchar* _tmp3_ = NULL;
		gboolean _tmp4_ = FALSE;
		_tmp2_ = args;
		_tmp2__length1 = args_length1;
		_tmp3_ = _tmp2_[1];
		_tmp4_ = g_str_has_suffix (_tmp3_, ".gidl");
		_tmp0_ = !_tmp4_;
	}
	_tmp5_ = _tmp0_;
	if (_tmp5_) {
		FILE* _tmp6_ = NULL;
		gchar** _tmp7_ = NULL;
		gint _tmp7__length1 = 0;
		const gchar* _tmp8_ = NULL;
		gchar* _tmp9_ = NULL;
		gchar* _tmp10_ = NULL;
		_tmp6_ = stdout;
		_tmp7_ = args;
		_tmp7__length1 = args_length1;
		_tmp8_ = _tmp7_[0];
		_tmp9_ = g_path_get_basename (_tmp8_);
		_tmp10_ = _tmp9_;
		fprintf (_tmp6_, "Usage: %s library.gidl\n", _tmp10_);
		_g_free0 (_tmp10_);
		result = 2;
		return result;
	}
	_tmp11_ = args;
	_tmp11__length1 = args_length1;
	_tmp12_ = _tmp11_[1];
	_tmp13_ = vala_code_context_new ();
	_tmp14_ = _tmp13_;
	_tmp15_ = vala_vapi_check_new (_tmp12_, _tmp14_);
	_tmp16_ = _tmp15_;
	_vala_code_context_unref0 (_tmp14_);
	vapicheck = _tmp16_;
	_tmp17_ = vapicheck;
	_tmp18_ = vala_vapi_check_run (_tmp17_);
	result = _tmp18_;
	_g_object_unref0 (vapicheck);
	return result;
}


int main (int argc, char ** argv) {
#if !GLIB_CHECK_VERSION (2,35,0)
	g_type_init ();
#endif
	return vala_vapi_check_main (argv, argc);
}


ValaCodeContext* vala_vapi_check_get_context (ValaVAPICheck* self) {
	ValaCodeContext* result;
	ValaCodeContext* _tmp0_ = NULL;
	g_return_val_if_fail (self != NULL, NULL);
	_tmp0_ = self->priv->_context;
	result = _tmp0_;
	return result;
}


static gpointer _vala_code_context_ref0 (gpointer self) {
	return self ? vala_code_context_ref (self) : NULL;
}


static void vala_vapi_check_set_context (ValaVAPICheck* self, ValaCodeContext* value) {
	ValaCodeContext* _tmp0_ = NULL;
	ValaCodeContext* _tmp1_ = NULL;
	g_return_if_fail (self != NULL);
	_tmp0_ = value;
	_tmp1_ = _vala_code_context_ref0 (_tmp0_);
	_vala_code_context_unref0 (self->priv->_context);
	self->priv->_context = _tmp1_;
	g_object_notify ((GObject *) self, "context");
}


ValaSourceFile* vala_vapi_check_get_gidl (ValaVAPICheck* self) {
	ValaSourceFile* result;
	ValaSourceFile* _tmp0_ = NULL;
	g_return_val_if_fail (self != NULL, NULL);
	_tmp0_ = self->priv->_gidl;
	result = _tmp0_;
	return result;
}


static gpointer _vala_source_file_ref0 (gpointer self) {
	return self ? vala_source_file_ref (self) : NULL;
}


static void vala_vapi_check_set_gidl (ValaVAPICheck* self, ValaSourceFile* value) {
	ValaSourceFile* _tmp0_ = NULL;
	ValaSourceFile* _tmp1_ = NULL;
	g_return_if_fail (self != NULL);
	_tmp0_ = value;
	_tmp1_ = _vala_source_file_ref0 (_tmp0_);
	_vala_source_file_unref0 (self->priv->_gidl);
	self->priv->_gidl = _tmp1_;
	g_object_notify ((GObject *) self, "gidl");
}


ValaSourceFile* vala_vapi_check_get_metadata (ValaVAPICheck* self) {
	ValaSourceFile* result;
	ValaSourceFile* _tmp0_ = NULL;
	g_return_val_if_fail (self != NULL, NULL);
	_tmp0_ = self->priv->_metadata;
	result = _tmp0_;
	return result;
}


static void vala_vapi_check_set_metadata (ValaVAPICheck* self, ValaSourceFile* value) {
	ValaSourceFile* _tmp0_ = NULL;
	ValaSourceFile* _tmp1_ = NULL;
	g_return_if_fail (self != NULL);
	_tmp0_ = value;
	_tmp1_ = _vala_source_file_ref0 (_tmp0_);
	_vala_source_file_unref0 (self->priv->_metadata);
	self->priv->_metadata = _tmp1_;
	g_object_notify ((GObject *) self, "metadata");
}


static void vala_vapi_check_class_init (ValaVAPICheckClass * klass) {
	vala_vapi_check_parent_class = g_type_class_peek_parent (klass);
	g_type_class_add_private (klass, sizeof (ValaVAPICheckPrivate));
	G_OBJECT_CLASS (klass)->get_property = _vala_vala_vapi_check_get_property;
	G_OBJECT_CLASS (klass)->set_property = _vala_vala_vapi_check_set_property;
	G_OBJECT_CLASS (klass)->finalize = vala_vapi_check_finalize;
	g_object_class_install_property (G_OBJECT_CLASS (klass), VALA_VAPI_CHECK_CONTEXT, vala_param_spec_code_context ("context", "context", "context", VALA_TYPE_CODE_CONTEXT, G_PARAM_STATIC_NAME | G_PARAM_STATIC_NICK | G_PARAM_STATIC_BLURB | G_PARAM_READABLE));
	g_object_class_install_property (G_OBJECT_CLASS (klass), VALA_VAPI_CHECK_GIDL, vala_param_spec_source_file ("gidl", "gidl", "gidl", VALA_TYPE_SOURCE_FILE, G_PARAM_STATIC_NAME | G_PARAM_STATIC_NICK | G_PARAM_STATIC_BLURB | G_PARAM_READABLE));
	g_object_class_install_property (G_OBJECT_CLASS (klass), VALA_VAPI_CHECK_METADATA, vala_param_spec_source_file ("metadata", "metadata", "metadata", VALA_TYPE_SOURCE_FILE, G_PARAM_STATIC_NAME | G_PARAM_STATIC_NICK | G_PARAM_STATIC_BLURB | G_PARAM_READABLE));
}


static void vala_vapi_check_instance_init (ValaVAPICheck * self) {
	self->priv = VALA_VAPI_CHECK_GET_PRIVATE (self);
}


static void vala_vapi_check_finalize (GObject* obj) {
	ValaVAPICheck * self;
	self = G_TYPE_CHECK_INSTANCE_CAST (obj, VALA_TYPE_VAPI_CHECK, ValaVAPICheck);
	_vala_code_context_unref0 (self->priv->_context);
	_vala_source_file_unref0 (self->priv->_gidl);
	_vala_source_file_unref0 (self->priv->_metadata);
	_vala_iterable_unref0 (self->priv->_scope);
	_vala_iterable_unref0 (self->priv->_symbols);
	G_OBJECT_CLASS (vala_vapi_check_parent_class)->finalize (obj);
}


GType vala_vapi_check_get_type (void) {
	static volatile gsize vala_vapi_check_type_id__volatile = 0;
	if (g_once_init_enter (&vala_vapi_check_type_id__volatile)) {
		static const GTypeInfo g_define_type_info = { sizeof (ValaVAPICheckClass), (GBaseInitFunc) NULL, (GBaseFinalizeFunc) NULL, (GClassInitFunc) vala_vapi_check_class_init, (GClassFinalizeFunc) NULL, NULL, sizeof (ValaVAPICheck), 0, (GInstanceInitFunc) vala_vapi_check_instance_init, NULL };
		GType vala_vapi_check_type_id;
		vala_vapi_check_type_id = g_type_register_static (G_TYPE_OBJECT, "ValaVAPICheck", &g_define_type_info, 0);
		g_once_init_leave (&vala_vapi_check_type_id__volatile, vala_vapi_check_type_id);
	}
	return vala_vapi_check_type_id__volatile;
}


static void _vala_vala_vapi_check_get_property (GObject * object, guint property_id, GValue * value, GParamSpec * pspec) {
	ValaVAPICheck * self;
	self = G_TYPE_CHECK_INSTANCE_CAST (object, VALA_TYPE_VAPI_CHECK, ValaVAPICheck);
	switch (property_id) {
		case VALA_VAPI_CHECK_CONTEXT:
		vala_value_set_code_context (value, vala_vapi_check_get_context (self));
		break;
		case VALA_VAPI_CHECK_GIDL:
		vala_value_set_source_file (value, vala_vapi_check_get_gidl (self));
		break;
		case VALA_VAPI_CHECK_METADATA:
		vala_value_set_source_file (value, vala_vapi_check_get_metadata (self));
		break;
		default:
		G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
		break;
	}
}


static void _vala_vala_vapi_check_set_property (GObject * object, guint property_id, const GValue * value, GParamSpec * pspec) {
	ValaVAPICheck * self;
	self = G_TYPE_CHECK_INSTANCE_CAST (object, VALA_TYPE_VAPI_CHECK, ValaVAPICheck);
	switch (property_id) {
		case VALA_VAPI_CHECK_CONTEXT:
		vala_vapi_check_set_context (self, vala_value_get_code_context (value));
		break;
		case VALA_VAPI_CHECK_GIDL:
		vala_vapi_check_set_gidl (self, vala_value_get_source_file (value));
		break;
		case VALA_VAPI_CHECK_METADATA:
		vala_vapi_check_set_metadata (self, vala_value_get_source_file (value));
		break;
		default:
		G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
		break;
	}
}


static void _vala_array_destroy (gpointer array, gint array_length, GDestroyNotify destroy_func) {
	if ((array != NULL) && (destroy_func != NULL)) {
		int i;
		for (i = 0; i < array_length; i = i + 1) {
			if (((gpointer*) array)[i] != NULL) {
				destroy_func (((gpointer*) array)[i]);
			}
		}
	}
}


static void _vala_array_free (gpointer array, gint array_length, GDestroyNotify destroy_func) {
	_vala_array_destroy (array, array_length, destroy_func);
	g_free (array);
}


static gint _vala_array_length (gpointer array) {
	int length;
	length = 0;
	if (array) {
		while (((gpointer*) array)[length]) {
			length++;
		}
	}
	return length;
}



