package koi

import "core:fmt"
import "core:strings"

scope_get :: proc(scope: ^Scope, name: string) -> (Variable, bool) {
	if v, ok := scope.names[name]; ok {
		return v, true;
	}
	
	if scope.parent != nil {
		v, ok := scope_get(scope.parent, name);
		if ok {
			return v, true;
		}
	}

	return {}, false;
}

scope_add_local :: proc(scope: ^Scope, name: string, index: int) -> bool {
	if _, ok := scope.names[name]; ok {
		return false;
	}

	v := Variable{
		name = name,
		is_local = true,
		local_index = index,
	};
	scope.names[name] = v;
	return true;
}

push_func_stack :: inline proc(f: ^KoiFunction) {
	f.current_stack += 1;
	if f.current_stack > f.stack_size {
		f.stack_size = f.current_stack;
	}
}

pop_func_stack :: inline proc(f: ^KoiFunction) {
	f.current_stack -= 1;
}

gen_expr :: proc(state: ^State, scope: ^Scope, f: ^KoiFunction, node: ^Node) {
	using Opcode;
	switch n in node.kind {
	case NodeIdent:
		v, found := scope_get(scope, n.name);
		if !found {
			panic("TODO: Error, ident not found");
		}

		if v.is_local {
			push_func_stack(f);
			append(&f.ops, Opcode(GETLOCAL));
			append(&f.ops, Opcode(v.local_index));
		} else {
			for k, i in f.constants {
				if is_string(k) {
					s := cast(^String) k;
					if s.str == v.name {
						push_func_stack(f);
						append(&f.ops, Opcode(PUSHK));
						append(&f.ops, Opcode(i));
						return;
					}
				}
			}

			s := new_value(state, String);
			s.str = strings.new_string(n.name);
			k := len(f.constants);

			assert(k >= 0 && k <= 255, "Too many constants");

			push_func_stack(f);
			append(&f.ops, Opcode(PUSHK));
			append(&f.ops, Opcode(k));
		}
	case NodeNumber:
		s := new_value(state, Number);
		s.value = n.value;
		k := len(f.constants);
		append(&f.constants, s);

		assert(k >= 0 && k <= 255, "Too many constants");

		push_func_stack(f);
		append(&f.ops, Opcode(PUSHK));
		append(&f.ops, Opcode(k));
	case NodeString:
		s := new_value(state, String);
		s.str = strings.new_string(n.value);
		k := len(f.constants);

		assert(k >= 0 && k <= 255, "Too many constants");

		push_func_stack(f);
		append(&f.ops, Opcode(PUSHK));
		append(&f.ops, Opcode(k));
	case NodeNull:
		push_func_stack(f);
		append(&f.ops, Opcode(PUSHNULL));
	case NodeTrue:
		push_func_stack(f);
		append(&f.ops, Opcode(PUSHTRUE));
	case NodeFalse:
		push_func_stack(f);
		append(&f.ops, Opcode(PUSHFALSE));
	case NodeBinary:
		gen_expr(state, scope, f, n.rhs);
		gen_expr(state, scope, f, n.lhs);

		using TokenType;
		switch n.op {
		case Plus: append(&f.ops, Opcode(ADD));
		case Minus: append(&f.ops, Opcode(SUB));
		case Asterisk: append(&f.ops, Opcode(MUL));
		case Slash: append(&f.ops, Opcode(DIV));
		case Mod: append(&f.ops, Opcode(MOD));
		case: panic("Unexpected binary op!");
		}
		push_func_stack(f);
		pop_func_stack(f);
		pop_func_stack(f);
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
	switch n in node.kind {
	case NodeReturn:
		gen_expr(state, scope, f, n.expr);
		append(&f.ops, Opcode(RETURN));
		pop_func_stack(f);
	case NodeVariableDecl:
		index := f.locals;
		ok := scope_add_local(scope, n.name, index);
		if !ok {
			panic("Variable already exists!");
		}
		f.locals += 1;

		if n.expr != nil {
			gen_expr(state, scope, f, n.expr);
			pop_func_stack(f);
			append(&f.ops, Opcode(SETLOCAL));
			append(&f.ops, Opcode(index));
		} else {
			push_func_stack(f);
			append(&f.ops, Opcode(PUSHNULL));
			pop_func_stack(f);
			append(&f.ops, Opcode(SETLOCAL));
			append(&f.ops, Opcode(index));
		}
	case NodeCall:
		panic("TODO");
	case NodeAssignment:
		panic("TODO");
	case NodeIf:
		panic("TODO");
	case NodeFor:
		panic("TODO");
	case NodeBlock:
		gen_block(state, scope, f, node);
		
	case: panic("Unexpected stmt node type!");
	}
}

gen_block :: proc(state: ^State, parent_scope: ^Scope, f: ^KoiFunction, node: ^Node) {
	n := &node.kind.(NodeBlock);
	scope := make_scope(parent_scope);

	for stmt in n.stmts {
		gen_stmt(state, scope, f, stmt);
	}
}

gen_function :: proc(state: ^State, parent_scope: ^Scope, n: ^NodeFn) -> ^Function {
	fv := new_value(state, Function);
	fv.variant = KoiFunction{func=fv};
	f := &(fv.variant.(KoiFunction));
	f.stack_size = 0;

	scope := make_scope(parent_scope);
	f.arg_count = len(n.args);
	for a, i in n.args {
		scope_add_local(scope, a, f.locals);
		f.locals += 1;
	}

	gen_block(state, scope, f, n.block);

	// Return something
	push_func_stack(f);
	append(&f.ops, Opcode(Opcode.PUSHNULL));
	append(&f.ops, Opcode(Opcode.RETURN));

	return fv;
}