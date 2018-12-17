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
	global_names: map[string]^Value,

	gc_worker_stop: bool,
	gc_worker_stop_mutex: sync.Mutex,
	marking: bool, // We are currently marking, if this is the case all new objects should be grey
	marking_mutex: sync.Mutex,
	gc_thread: ^thread.Thread,
	start_gc_thread: sync.Semaphore,
	total_values,max_values: int,

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

gc_add_to_grey_from_white :: proc(state: ^State, v: ^Value) {
	if v.color != GCColor.White do return;
	v.color = GCColor.Grey;
	v.next_list = state.grey_list;
	if state.grey_list != nil {
		state.grey_list.prev_list = v;
	}
	state.grey_list = v;
}

gc_mark_value :: proc(state: ^State, v: ^Value) {
	if v.color == GCColor.Black do return; // Does this even happen?
	assert(v.color == GCColor.Grey);

	v.color = GCColor.Black;
	v.next_list = state.black_list;
	if state.black_list != nil {
		state.black_list.prev_list = v;
	}
	state.black_list = v;

	switch v.kind {
	case True, False, Null, String, Number:
		// No children to add
	case Function:
		f := cast(^Function) v;
		#complete switch fv in f.variant {
		case KoiFunction:
			for v in fv.constants {
				gc_add_to_grey_from_white(state, v);
			}
		}
	case Table:
		t := cast(^Table) v;
		for _, v in t.data {
			if v != nil do gc_add_to_grey_from_white(state, v);
		}
	case Array:
		arr := cast(^Array) v;
		for v in arr.data.data[:arr.data.size] {
			gc_add_to_grey_from_white(state, v);
		}
	case: panic("Unsupported value type!");
	}
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

		sync.mutex_lock(&state.grey_list_mutex);
		grey_list_empty := state.grey_list == nil;
		sync.mutex_unlock(&state.grey_list_mutex);

		for !grey_list_empty {
			sync.mutex_lock(&state.grey_list_mutex);

			v := cast(^Value) state.grey_list;
			state.grey_list = v.next_list;
			gc_mark_value(state, v);

			grey_list_empty = state.grey_list == nil;
			if !grey_list_empty do sync.mutex_unlock(&state.grey_list_mutex);
		}

		assert(state.grey_list == nil);

		// We dont want any more elements
		// So set marking = false and grab the greylist
		sync.mutex_lock(&state.marking_mutex);
		state.marking = false;
		sync.mutex_unlock(&state.marking_mutex);

		freed_in_pass := 0;

		gc := &state.all_objects;
		for gc^ != nil {
			val := gc^;
			if val.color == GCColor.White && !val.is_constant {
				gc^ = val.next;
				free_value(state, cast(^Value)val);
				freed_in_pass += 1;	
			} else {
				val.color = GCColor.White;
				gc = &val.next;
			}
		}

		fmt.printf("GC: Freed %d, Values: %d, Max: %d\n", freed_in_pass, state.total_values, state.max_values);
		state.max_values = 2*state.total_values; // New threshold
		//fmt.printf("New Threshold: %d\n", state.max_values);

		b := state.black_list;
		for b != nil {
			b.color = GCColor.White;
			b.next_list = nil;
			b.prev_list = nil;
			b = b.next_list;
		}
		state.black_list = nil;


		sync.mutex_unlock(&state.grey_list_mutex);
	}

	return 0;
}

make_state :: proc() -> ^State {
	state := new(State);

	sync.semaphore_init(&state.start_gc_thread);
	sync.mutex_init(&state.marking_mutex);
	sync.mutex_init(&state.gc_worker_stop_mutex);
	sync.mutex_init(&state.grey_list_mutex);

	state.global_scope = make_scope(nil);
	state.null_value = new_value(state, Null, false);
	state.true_value = new_value(state, True, false);
	state.false_value = new_value(state, False, false);

	state.gc_thread = thread.create(gc_worker_proc);
	state.gc_thread.data = rawptr(state);
	state.gc_thread.init_context = context;
	state.gc_thread.use_init_context = true;
	thread.start(state.gc_thread);

	state.total_values = 0;
	state.max_values = 100;

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

// Things that aint right
// - print "test" + 1; Passes throgh the lexer as a statement, this is aint right.
// - print ""; Empty strings are probably broken

main :: proc() {
	//dump_nodes(nodes);

	state := make_state();
	sync.mutex_lock(&state.gc_worker_stop_mutex);
	sync.mutex_lock(&state.gc_worker_stop_mutex);
	sync.mutex_lock(&state.gc_worker_stop_mutex);
	sync.mutex_lock(&state.gc_worker_stop_mutex);
	sync.mutex_lock(&state.gc_worker_stop_mutex);
	sync.mutex_unlock(&state.gc_worker_stop_mutex);
	//import_file(state, "tests/point.koi", true, "point");
	//import_file(state, state.global_scope, "test_gen.koi", false);
	import_file(state, state.global_scope, "tests/gctest.koi", false);

	main_v, ok := scope_get(state.global_scope, "main");
	if !ok {
		fmt.printf("Could not find a main entry point!\n");
		os.exit(1);
	}
	main := main_v.value;

	mk := (cast(^Function)main).variant.(KoiFunction);
	out, err := os.open("dump.bin", os.O_RDWR|os.O_CREATE);
	dump: []u8 = transmute([]u8) mk.ops[:];
	os.write(out, dump);
	os.close(out);

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
