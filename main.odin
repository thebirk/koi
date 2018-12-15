package koi

import "core:fmt"
import "core:sync"
import "core:thread"

// Features we want:
//  - Easy odin interop
//    - ex. use type info so we can auto call odin proc from koi
//  - Validation before runtime, aka. catch unknown variables etc.
//  - some sort of iterator ala next(it)

Variable :: struct {
	name: string,
	is_local: bool,
	local_index: int,
	value: ^Value,
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

	gc_worker_stop: bool,
	gc_worker_stop_mutex: sync.Mutex,
	marking: bool, // We are currently marking, if this is the case all new objects should be grey
	marking_mutex: sync.Mutex,
	gc_thread: ^thread.Thread,
	start_gc_thread: sync.Semaphore,

	// linked list of all allocated data
	all_objects: ^GCObject,
	grey_list_mutex: sync.Mutex,
	// We should only need a mutex for the grey list because thats the only data
	// both threads will be touching at the same time.
	grey_list: ^GCObject,
	black_list: ^GCObject,

	null_value: ^Value,
	true_value: ^Value,
	false_value: ^Value,
	// stack trace

	top: int,
	stack: [dynamic]^Value,
	call_stack: [dynamic]StackFrame,
}

gc_worker_proc :: proc(t: ^thread.Thread) -> int {
	state := cast(^State) t.data;
	for {
		sync.semaphore_wait(&state.start_gc_thread);
		sync.semaphore_post(&state.start_gc_thread, 0);

		sync.mutex_lock(&state.gc_worker_stop_mutex);
		if state.gc_worker_stop {
			sync.mutex_unlock(&state.gc_worker_stop_mutex);
			return 0;
		}
		sync.mutex_unlock(&state.gc_worker_stop_mutex);

		sync.mutex_lock(&state.marking_mutex);
		if !state.marking {
			panic("GC thread was started but we are not marking :(");
		}
		sync.mutex_unlock(&state.marking_mutex);

		
	}

	return 0;
}

make_state :: proc() -> ^State {
	state := new(State);
	state.global_scope = new(Scope);
	state.null_value = new_value(state, Null);
	state.true_value = new_value(state, True);
	state.false_value = new_value(state, False);

	sync.semaphore_init(&state.start_gc_thread);
	sync.mutex_init(&state.marking_mutex);
	sync.mutex_init(&state.gc_worker_stop_mutex);

	state.gc_thread = thread.create(gc_worker_proc);
	state.gc_thread.data = rawptr(state);
	state.gc_thread.init_context = context;
	state.gc_thread.use_init_context = true;
	thread.start(state.gc_thread);

	return state;
}

delete_state :: proc(state: ^State) {
	sync.mutex_lock(&state.gc_worker_stop_mutex);
	state.gc_worker_stop = true;
	sync.mutex_unlock(&state.gc_worker_stop_mutex);
	sync.semaphore_release(&state.start_gc_thread);
	thread.destroy(state.gc_thread);

	// Free all the values
	// Free null, true, and false
	free(state);
}

state_ensure_stack_size :: proc(using state: ^State) {
	if top >= len(stack) {
		len := len(stack);
		reserve(&stack, top);
		for i in len..top-1 {
			append(&stack, nil);
		}
	}
}

push_call :: proc(state: ^State, func: ^Function) -> StackFrame {
	bottom := state.top;
	state.top += func.stack_size + func.locals;
	sf := StackFrame{func = func, prev_stack_top = state.top, bottom = bottom};
	append(&state.call_stack, sf);
	state_ensure_stack_size(state);
	return sf;
}

pop_call :: proc(using state: ^State) {
	sf := pop(&state.call_stack);
	top = sf.prev_stack_top;
}

state_add_global :: proc(using state: ^State, name: string, v: ^Value) -> bool {
	if _, ok := state.global_scope.names[name]; ok {
		return false;
	}

	state.global_scope.names[name] = Variable{value = v, name = name};
	return true;
}

// Things that aint right
//   - var test = test; // This should scream at yah

main :: proc() {

	//nodes, err := parse_file("test.koi");
/*	parser: Parser;
	init_parser(&parser, "test.koi");
	fmt.printf("%#v\n", parse_expr(&parser).kind);*/

	nodes, err := parse_file("test_gen.koi");
	/*nodes[0].loc = get_builtin_loc();
	for n in nodes {
		fmt.printf("%#v\n", n.kind);
	}*/
	/*
	t := next_token(&parser);
	for t.kind != TokenType.Eof {
		fmt.printf("%#v\n", t);
		t = next_token(&parser);
	}*/

	state := make_state();

	//TODO: Pre-Register names

	for i in 0..len(nodes)-1 {
		node := nodes[i];
		switch n in node.kind {
		case NodeImport:
			//TODO
		case NodeVariableDecl:
			//HOW
			// Create a dummy function and generate all the variable decls into here
			// call it, but it needs to be called before we gen functions
			// We should first add all references to all top-level nodes then generate them
			//panic("TODO");
		case NodeFn:
			f := gen_function(state, state.global_scope, cast(^NodeFn) node);
			//fmt.printf("f: %#v\n", f.variant);
			//fmt.printf("f.ops:\n%#v\n", f.variant.(KoiFunction).ops);
			if !state_add_global(state, n.name, f) {
				panic("Name already exists");
			}
		case: panic("Unexpected top-level node type!");	
		}
	}

	main_v, ok := scope_get(state.global_scope, "main");
	if !ok {
		panic("No main");
	}
	main := main_v.value;

	args: [dynamic]^Value;
	a1 := new_value(state, Number);
	a1.value = 111;
	append(&args, a1);
	ret := call_function(state, cast(^Function) main, args[:]);
	fmt.printf("\n\nRETURN: ");
	switch ret.kind {
		case Number:
			fmt.printf("%#v\n", (cast(^Number)ret)^);
		case True:
			fmt.printf("%#v\n", ret.kind);
		case False:
			fmt.printf("%#v\n", ret.kind);
		case Null:
			fmt.printf("%#v\n", ret.kind);
		case:
			fmt.printf("%v, %v\n", ret, ret.kind);
	}

	delete_state(state);
}