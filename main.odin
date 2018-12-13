package koi

import "core:fmt"

// Features we want:
//  - Easy odin interop
//    - ex. use type info so we can auto call odin proc from koi
//  - Validation before runtime, aka. catch unknown variables etc.
//  - some sort of iterator ala next(it)

Variable :: struct {
	name: string,
	is_local: bool,
	local_index: int,
}

Scope :: struct {
	parent: ^Scope,
	names: map[string]Variable,
}

make_scope :: proc(parent: ^Scope) -> ^Scope {
	s := new(Scope);
	s.parent = parent;
	return s;
}

StackFrame :: struct {
	func: ^Function,
	prev_stack_top: int,
	bottom: int,
}

State :: struct {
	global_scope: ^Scope,
	
	marking: bool, // We are currently marking, if this is the case all new objects should be grey
	all_objects: ^GCObject,
	grey_list: ^GCObject,
	black_list: ^GCObject,

	null_value: ^Value,
	true_value: ^Value,
	false_value: ^Value,
	// stack trace
	// linked list of all allocated data

	top: int,
	stack: [dynamic]^Value,
	call_stack: [dynamic]StackFrame,
}

make_state :: proc() -> ^State {
	state := new(State);
	state.global_scope = new(Scope);
/*	state.null_value = new_value(state, Null);
	state.true_value = new_value(state, True);
	state.false_value = new_value(state, False);
*/
	return state;
}

state_ensure_stack_size :: proc(using state: ^State) {
	if len(stack) < top {
		reserve(&stack, top);
	}
}

push_call :: proc(state: ^State, func: ^Function) -> StackFrame {
	bottom := state.top;
	state.top += func.stack_size + func.arg_count;
	sf := StackFrame{func = func, prev_stack_top = bottom, bottom = state.top};
	append(&state.call_stack, sf);
	state_ensure_stack_size(state);
	return sf;
}

pop_call :: proc(using state: ^State) {
	sf := pop(&state.call_stack);
	top = sf.prev_stack_top;
}

main :: proc() {
	state := make_state();

	//nodes, err := parse_file("test.koi");
/*	parser: Parser;
	init_parser(&parser, "test.koi");
	fmt.printf("%#v\n", parse_expr(&parser).kind);*/

	nodes, err := parse_file("test2.koi");
	nodes[0].loc = get_builtin_loc();
	for n in nodes {
		fmt.printf("%#v\n", n.kind);
	}
	/*
	t := next_token(&parser);
	for t.kind != TokenType.Eof {
		fmt.printf("%#v\n", t);
		t = next_token(&parser);
	}*/
}