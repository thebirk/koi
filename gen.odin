package koi

import "core:strings"

scope_get :: proc(scope: ^Scope, name: string) -> (Variable, bool) {
	if v, ok := scope.names[name]; ok {
		return v, true;
	}
	v, ok := scope_get(scope.parent, name);
	if ok {
		return v, true;
	} else {
		return {}, false;
	}
}

scope_add_local :: proc(scope: ^Scope, name: string, index: int) -> bool {
	if _, ok := scope.names[name]; ok {
		return false;
	}

	v := Variable{
		name = name,
		is_local = true,
		index = index,
	};
	scope.names[name] = v;
	return true;
}

gen_expr :: proc(state: ^State, scope: ^Scope, f: ^KoiFunction, node: ^Node) {
	using Opcode;
	switch n in node.kind {
	case NodeIdent:
		v, found := scope_get(scope, n.name);
		if !found {
			panic("TODO: Error");
		}

		if v.is_local {
			append(&f.ops, u8(GETLOCAL));
			append(&f.ops, u8(v.local_index));
		} else {
			for k, i in f.constants {
				if is_string(k) {
					s := cast(^String) k;
					if s.str == v.name {
						append(&f.ops, u8(PUSHK));
						append(&f.ops, u8(i));
						return;
					}
				}
			}

			s := new_value(state, String);
			s.str = strings.new_string(n.name);
			k := len(f.constants);

			assert(k >= 0 && k <= 255, "Too many constants");

			append(&f.ops, u8(PUSHK));
			append(&f.ops, u8(k));
		}
	case NodeNumber:
		s := new_value(state, Number);
		s.value = n.value;
		k := len(f.constants);

		assert(k >= 0 && k <= 255, "Too many constants");

		append(&f.ops, u8(PUSHK));
		append(&f.ops, u8(k));
	case NodeString:
		s := new_value(state, String);
		s.str = strings.new_string(n.value);
		k := len(f.constants);

		assert(k >= 0 && k <= 255, "Too many constants");

		append(&f.ops, u8(PUSHK));
		append(&f.ops, u8(k));
	case NodeNull:
		append(&f.ops, u8(PUSHNULL));
	case NodeTrue:
		append(&f.ops, u8(PUSHTRUE));
	case NodeFalse:
		append(&f.ops, u8(PUSHFALSE));
	case NodeBinary:
		gen_expr(state, scope, f, n.rhs);
		gen_expr(state, scope, f, n.lhs);

		using TokenType;
		switch n.op {
		case Plus: append(&f.ops, u8(ADD));
		case Minus: append(&f.ops, u8(SUB));
		case Asterisk: append(&f.ops, u8(MUL));
		case Slash: append(&f.ops, u8(DIV));
		case Mod: append(&f.ops, u8(MOD));
		case: panic("Unexpected binary op!");
		}
	case NodeUnary:
		panic("TODO");
	case NodeIndex:
		panic("TODO");
	case NodeField:
		panic("TODO");
	case NodeCall:
		panic("TODO");
	case:
		panic("Unexpected node type!");
	}
}

gen_stmt :: proc(state: ^State, scope: ^Scope, f: ^KoiFunction, node: ^Node) {
	using Opcode;
	switch n in node {
	case NodeReturn:
		gen_expr(state, scope, f, n.expr);
		append(&f.ops, u8(RETURN));
	case NodeVariableDecl:
		index := f.locals;
		ok := scope_add_local(state, n.name, index);
		if !ok {
			panic("Variable already exists!");
		}
		f.locals += 1;

		if n.expr != nil {
			gen_expr(state, scope, f, n.expr);
			append(&f.ops, u8(SETLOCAL));
			append(&f.ops, u8(index));
		} else {
			append(&f.ops, u8(PUSHNULL));
			append(&f.ops, u8(SETLOCAL));
			append(&f.ops, u8(index));
		}
	case NodeCall:
		panic("TODO");
	case NodeAssignment: panic("TODO");
	case NodeIf: panic("TODO");
	case NodeFor: panic("TODO");
	case NodeBlock:
		gen_block(state, scope, f, n);
		
	case: panic("Unexpected stmt node type!");
	}
}

gen_block :: proc(state: ^State, parent_scope: ^Scope, f: ^KoiFunction, node: ^NodeBlock) {
	assert(node.kind == NodeBlock);
	scope := make_scope(parent_scope);

	for stmt in node.stmts {
		gen_stmt(state, scope, f, stmt);
	}
}

gen_function :: proc(state: ^State, parent_scope: ^Scope, n: ^NodeFn) -> ^Function {
	fv := new_value(state, Function);
	fv.variant = KoiFunction{};
	f := &fv.variant.(KoiFunction);

	scope := make_scope(parent_scope);
	f.arg_count = len(n.args);
	for a, i in n.args {
		scope_add_local(scope, a, f.locals);
		f.locals += 1;
	}

	gen_block(state, scope, n.block);

	// Return something
	append(&f.ops, Opcode.PUSHNULL);
	append(&f.ops, Opcode.RETURN);

	return fv;
}