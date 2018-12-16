package koi

import "core:os"
import "core:fmt"
import "core:strings"

gen_error :: proc(node: ^Node, fmt_string: string, args: ..any) -> ! {
	print_location(node.loc);
	fmt.printf("\e[91m error: \e[0m");
	fmt.printf(fmt_string, ..args);
	fmt.printf("\n");

	//TODO: Print the line, with the line above and below as well
	//      try using an arrow as well
	//      Easiest solution would be to tag tokens with the start offset

	os.exit(1);
}

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

scope_set :: proc(scope: ^Scope, name: string, value: ^Value) {
	// Assumes the caller knows the variable exists
	if _, ok := scope.names[name]; ok {
		v := scope.names[name];
		v.value = value;
		scope.names[name] = v;
	}

	if scope.parent != nil {
		scope_set(scope, name, value);
	}
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
			gen_error(node, "undeclared variable '%s'.", n.name);
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
						append(&f.ops, GETGLOBAL);
						push_func_stack(f);
						pop_func_stack(f); // GETGLOBAL pops the previuos value of the stack
						return;
					}
				}
			}

			s := new_value(state, String);
			s.str = strings.new_string(n.name);
			k := len(f.constants);
			append(&f.constants, s); // Actually add the damn constant

			assert(k >= 0 && k <= 255, "Too many constants");

			push_func_stack(f);
			append(&f.ops, Opcode(PUSHK));
			append(&f.ops, Opcode(k));
			append(&f.ops, GETGLOBAL);
			push_func_stack(f);
			pop_func_stack(f); // GETGLOBAL pops the previuos value of the stack
		}
	case NodeNumber:
		s := new_value(state, Number);
		s.value = n.value;
		k := len(f.constants);
		append(&f.constants, s);

		//TODO: Constant number pooling

		assert(k >= 0 && k <= 255, "Too many constants");

		push_func_stack(f);
		append(&f.ops, Opcode(PUSHK));
		append(&f.ops, Opcode(k));
	case NodeString:
		s := new_value(state, String);
		s.str = strings.new_string(n.value);
		k := len(f.constants);
		append(&f.constants, s);

		//TODO: Constant string pooling

		assert(k >= 0 && k <= 255, "Too many constants");

		append(&f.ops, Opcode(PUSHK));
		push_func_stack(f);
		append(&f.ops, Opcode(k));
	case NodeNull:
		append(&f.ops, Opcode(PUSHNULL));
		push_func_stack(f);
	case NodeTrue:
		append(&f.ops, Opcode(PUSHTRUE));
		push_func_stack(f);
	case NodeFalse:
		append(&f.ops, Opcode(PUSHFALSE));
		push_func_stack(f);
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
		gen_expr(state, scope, f, n.expr);
		gen_expr(state, scope, f, n.field);
		append(&f.ops, GETTABLE);
		push_func_stack(f);
		pop_func_stack(f);
		pop_func_stack(f);
	case NodeCall:
		gen_call(state, scope, f, cast(^NodeCall) node);
	case NodeTableLiteral:
		append(&f.ops, NEWTABLE);
		push_func_stack(f);

		for e in n.entries {
			gen_expr(state, scope, f, e.expr);
			gen_expr(state, scope, f, e.name);
			append(&f.ops, SETTABLE); // Set tables restores the table to the top of the stack after use
			pop_func_stack(f);
			pop_func_stack(f);
		}
	case:
		panic("Unexpected node type!");
	}
}

gen_call :: proc(state: ^State, scope: ^Scope, f: ^KoiFunction, node: ^NodeCall) {
	//TODO: Determine argument order. Should we push in reverse
	for i := len(node.args)-1; i >= 0; i -= 1 {
		gen_expr(state, scope, f, node.args[i]);
	}
	gen_expr(state, scope, f, node.expr);
	append(&f.ops, Opcode.CALL);
	push_func_stack(f); // Return value
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

		if n.expr != nil {
			gen_expr(state, scope, f, n.expr);
			append(&f.ops, Opcode(SETLOCAL));
			pop_func_stack(f);
			append(&f.ops, Opcode(index));
		} else {
			append(&f.ops, Opcode(PUSHNULL));
			push_func_stack(f);
			append(&f.ops, Opcode(SETLOCAL));
			pop_func_stack(f);
			append(&f.ops, Opcode(index));
		}

		ok := scope_add_local(scope, n.name, index);
		if !ok {
			gen_error(node, "variable '%s' already exists.", n.name);
		}
		f.locals += 1;
	case NodeCall:
		gen_call(state, scope, f, cast(^NodeCall) node);
		append(&f.ops, POP);
		pop_func_stack(f);
	case NodeAssignment:
		switch lhs in n.lhs.kind {
		case NodeIdent:
			v, ok := scope_get(scope, lhs.name);
			if !ok {
				gen_error(n.lhs, "undeclared variable '%s'.", lhs.name);
			}

			switch n.op {
			case TokenType.Equal:
				gen_expr(state, scope, f, n.rhs);
			case TokenType.PlusEqual:
				gen_expr(state, scope, f, n.lhs);
				gen_expr(state, scope, f, n.rhs);
				append(&f.ops, ADD);
				push_func_stack(f);
				pop_func_stack(f);
				pop_func_stack(f);
			case TokenType.MinusEqual:
				gen_expr(state, scope, f, n.lhs);
				gen_expr(state, scope, f, n.rhs);
				append(&f.ops, SUB);
				push_func_stack(f);
				pop_func_stack(f);
				pop_func_stack(f);
			case TokenType.AsteriskEqual:
				gen_expr(state, scope, f, n.lhs);
				gen_expr(state, scope, f, n.rhs);
				append(&f.ops, MUL);
				push_func_stack(f);
				pop_func_stack(f);
				pop_func_stack(f);
			case TokenType.SlashEqual:
				gen_expr(state, scope, f, n.lhs);
				gen_expr(state, scope, f, n.rhs);
				append(&f.ops, DIV);
				push_func_stack(f);
				pop_func_stack(f);
				pop_func_stack(f);
			case TokenType.ModEqual:
				gen_expr(state, scope, f, n.lhs);
				gen_expr(state, scope, f, n.rhs);
				append(&f.ops, MOD);
				push_func_stack(f);
				pop_func_stack(f);
				pop_func_stack(f);
			case:
				fmt.panicf("Invalid assignment op type: %v", n.op);
			}

			if v.is_local {
				append(&f.ops, SETLOCAL);
				pop_func_stack(f);
				append(&f.ops, Opcode(v.local_index));
			} else {
				for k, i in f.constants {
					if is_string(k) {
						s := cast(^String) k;
						if s.str == v.name {
							push_func_stack(f);
							append(&f.ops, Opcode(PUSHK));
							append(&f.ops, Opcode(i));
							append(&f.ops, SETGLOBAL);
							pop_func_stack(f);
							return;
						}
					}
				}

				s := new_value(state, String);
				s.str = strings.new_string(lhs.name);
				k := len(f.constants);
				append(&f.constants, s); // Actually add the damn constant

				push_func_stack(f);
				append(&f.ops, Opcode(PUSHK));
				append(&f.ops, Opcode(k));
				append(&f.ops, SETGLOBAL);
				pop_func_stack(f);
			}
		case NodeIndex:
			panic("//TODO:");
		case NodeField:
			panic("//TODO:");
		case NodeBinary, NodeUnary:
			gen_error(n.lhs, "cannot assign to expression.");
		case NodeString, NodeNumber, NodeNull, NodeTrue, NodeFalse:
			gen_error(n.lhs, "cannot assign to literal.");
		case NodeCall:
			gen_error(n.lhs, "cannot assign to function call.");
		case:
			gen_error(n.lhs, "cannot assign to left hand side.");
		}
	case NodeIf:
		gen_expr(state, scope, f, n.cond);

		append(&f.ops, PUSHTRUE);
		push_func_stack(f);

		append(&f.ops, EQ);
		push_func_stack(f);
		pop_func_stack(f);
		pop_func_stack(f);

		append(&f.ops, JMP);
		true_jmp := len(f.ops);
		append(&f.ops, Opcode(0));
		append(&f.ops, Opcode(0));
		false_jmp := len(f.ops);
		append(&f.ops, Opcode(0));
		append(&f.ops, Opcode(0));

		if n.else_ != nil {
			false_scope := make_scope(scope);
			switch ne in n.else_.kind {
			case NodeIf:
				gen_stmt(state, false_scope, f, n.else_);
			case NodeBlock:
				gen_block(state, false_scope, f, n.else_);
			case:
				panic("Invalid else block node type");
			}
			free(false_scope);
		}

		true_loc := len(f.ops);
		true_scope := make_scope(scope);
		gen_block(state, true_scope, f, n.block);
		free(true_scope);
		
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
	for a in n.args {
		scope_add_local(scope, a, f.locals);
		f.locals += 1;
	}

	gen_block(state, scope, f, n.block);

	// Return something
	append(&f.ops, Opcode(Opcode.PUSHNULL));
	push_func_stack(f);
	append(&f.ops, Opcode(Opcode.RETURN));
	pop_func_stack(f);

	if true {
		fmt.printf("\n\nfunc: %s\nops (%d): %#v\n", n.name, len(f.ops), f.ops);
		fmt.printf("f.arg_count: %v\n", f.arg_count);
		fmt.printf("constants(%v):\n", len(f.constants));
		if false {
			for v in f.constants {
				fmt.printf("%#v\n", v^);
			}
		}
	}

	return fv;
}