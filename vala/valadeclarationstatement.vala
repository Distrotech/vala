/* valadeclarationstatement.vala
 *
 * Copyright (C) 2006-2010  Jürg Billeter
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


/**
 * Represents a local variable or constant declaration statement in the source code.
 */
public class Vala.DeclarationStatement : BaseStatement {
	/**
	 * The local variable or constant declaration.
	 */
	public Symbol declaration {
		get {
			return _declaration;
		}
		set {
			_declaration = value;
			if (_declaration != null) {
				_declaration.parent_node = this;
			}
		}
	}

	Symbol _declaration;

	/**
	 * Creates a new declaration statement.
	 *
	 * @param decl   local variable declaration
	 * @param source reference to source code
	 * @return       newly created declaration statement
	 */
	public DeclarationStatement (Symbol declaration, SourceReference? source_reference) {
		this.declaration = declaration;
		this.source_reference = source_reference;
	}

	public override void accept (CodeVisitor visitor) {
		visitor.visit_declaration_statement (this);
	}

	public override void accept_children (CodeVisitor visitor) {
		declaration.accept (visitor);
	}

	public override void get_error_types (Collection<DataType> collection, SourceReference? source_reference = null) {
		if (source_reference == null) {
			source_reference = this.source_reference;
		}
		var local = declaration as LocalVariable;
		if (local != null && local.initializer != null) {
			local.initializer.get_error_types (collection, source_reference);
		}
	}

	public override bool check (CodeContext context) {
		if (checked) {
			return !error;
		}

		checked = true;

		declaration.check (context);

		return !error;
	}

	public override void emit (CodeGenerator codegen) {
		codegen.visit_declaration_statement (this);
	}
}
