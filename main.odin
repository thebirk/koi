package koi

import "core:os"
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
//	global_names: map[string]^Value,

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
	state.global_scope = make_scope(nil);
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
		for in len..top-1 {
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

import_file :: proc(state: ^State, parent: ^Scope, filepath: string, import_into_file := false, import_name := "") {
	nodes, err := parse_file(filepath);
	if err != FileParseError.Ok {
		panic("invalid path");
	}

	file_scope := parent;
	if import_into_file {
		file_scope = make_scope(parent);
	}

	module := new_value(state, Table);
	if import_into_file {
		if import_name != "" {
			/*if v, ok := scope_get(file_scope, import_name); ok {

			} else {
				state_add_global(state, import_name, module);
			}*/
			scope_add(parent, import_name);
			scope_set(parent, import_name, module);
		} else {
			panic("Unsupported");
		}
	}

	for i in 0..len(nodes)-1 {
		node := nodes[i];
		switch n in node.kind {
		case NodeImport:
			if _, ok := file_scope.names[n.name]; ok {
					panic("Name already exists");
			}
			//scope_add(file_scope, n.name);
			scope_add(file_scope, "point");
		case NodeVariableDecl:
			if _, ok := file_scope.names[n.name]; ok {
					panic("Name already exists");
			}
			scope_add(file_scope, n.name);
		case NodeFn:
			if _, ok := file_scope.names[n.name]; ok {
					panic("Name already exists");
			}
			scope_add(file_scope, n.name);
		case: panic("Unexpected top-level node type!");	
		}
	}

	for i in 0..len(nodes)-1 {
		node := nodes[i];
		switch n in node.kind {
		case NodeImport:
			//TODO
			import_file(state, parent, n.name, true, "point");
		case NodeVariableDecl:
			//HOW
			// Create a dummy function and generate all the variable decls into here
			// call it, but it needs to be called before we gen functions
			// We should first add all references to all top-level nodes then generate them
			//panic("TODO");
		case NodeFn:
			f := gen_function(state, file_scope, cast(^NodeFn) node);
			//fmt.printf("f: %#v\n", f.variant);
			//fmt.printf("f.ops:\n%#v\n", f.variant.(KoiFunction).ops);
			/*if !state_add_global(state, n.name, f) {
				panic("Name already exists");
			}*/
			scope_set(file_scope, n.name, f);
		case: panic("Unexpected top-level node type!");	
		}
	}

	if import_into_file {
		for k, v in file_scope.names {
			module.data[k] = v.value;
		}
		// We cannot currently free the scope as values are stored here
		// we should only use scopes to check if variables are declared
		// all actual values should be stored on the state with namespaces names
		// ex. a fn test in import name "Test" would have the name in state: "test.Test"
		free(file_scope);
	}
}

main :: proc() {
	//dump_nodes(nodes);

	state := make_state();
	//import_file(state, "tests/point.koi", true, "point");
	import_file(state, state.global_scope, "test_gen.koi", false);

	main_v, ok := scope_get(state.global_scope, "main");
	if !ok {
		fmt.printf("Could not find a main entry point!\n");
		os.exit(1);
	}
	main := main_v.value;

	args: [dynamic]^Value;
	a1 := new_value(state, Number);
	a1.value = 111;
	append(&args, a1);
	ret := call_function(state, cast(^Function) main, args[:]);
	fmt.printf("\n\nRETURN:\n");
	print_value(ret);
	fmt.printf("\n");
	
	delete_state(state);
}