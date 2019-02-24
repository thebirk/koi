package koi

import "core:os"
import "core:fmt"
import "core:sync"
import "core:time"
import "core:thread"
//import "koir"

// Features we want:
//  - Easy odin interop
//    - ex. use type info so we can auto call odin proc from koi
//  - Validation before runtime, aka. catch unknown variables etc.
//  - some sort of iterator ala next(it)

// TODO:
// - push/pop for scopes, how to handle the 'names' map? 
// - implement arrays and maps properly
// - change null to nil
// - add self/method call
// - add type hints to function args
// - make usertypes have callbacks for certain functions like tostring, hash, etc.
//   * also a name to associate with the type
// - maybe add methods which are always self called? Do we need methods then?

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

delete_scope :: proc(s: ^Scope) {
	delete(s.names);
	free(s);
}

StackFrame :: struct {
	func: ^Function,
	prev_stack_top: int,
	bottom: int,
}

State :: struct {
	global_scope: ^Scope,
	global_names: map[string]^Value,
	userdata_counter: i64,

//	gc_worker_stop: bool,
//	gc_worker_stop_mutex: sync.Mutex,
//	marking: bool, // We are currently marking, if this is the case all new objects should be grey
//	marking_mutex: sync.Mutex,
//	gc_thread: ^thread.Thread,
//	start_gc_thread: sync.Semaphore,
	total_values,max_values: int,

	number_pool: [dynamic]^Value,

	// linked list of all allocated data
//	all_objects: ^GCObject,
//	grey_list_mutex: sync.Mutex,
	// We should only need a mutex for the grey list because thats the only data
	// both threads will be touching at the same time.
//	grey_list: ^GCObject,
//	black_list: ^GCObject,
	gc: GCState,

	null_value: ^Value,
	true_value: ^Value,
	false_value: ^Value,
	// stack trace

	top: int,
	stack: [dynamic]^Value,
	call_stack: [dynamic]StackFrame,
}

make_state :: proc() -> ^State {
	state := new(State);

	///TEMP
	vm_init_table();

	// sync.semaphore_init(&state.start_gc_thread);
	// sync.mutex_init(&state.marking_mutex);
	// sync.mutex_init(&state.gc_worker_stop_mutex);
	// sync.mutex_init(&state.grey_list_mutex);

	state.global_scope = make_scope(nil);
	state.null_value = new_value(state, Null, false);
	state.true_value = new_value(state, True, false);
	state.false_value = new_value(state, False, false);

	//TODO: make this an argument
	preallocated_numbers := 100;
	for i := 0; i <  preallocated_numbers; i += 1 {
		n := new(Number);
		n.kind = typeid_of(Number);
		append(&state.number_pool, n);
	}

	// state.gc_thread = thread.create(gc_worker_proc);
	// state.gc_thread.data = rawptr(state);
	// state.gc_thread.init_context = context;
	// state.gc_thread.use_init_context = true;
	// thread.start(state.gc_thread);


	state.total_values = 0;
	state.max_values = 1000;

	state.userdata_counter = 1;

	return state;
}

delete_state :: proc(state: ^State) {
	// sync.mutex_lock(&state.gc_worker_stop_mutex);
	// state.gc_worker_stop = true;
	// sync.mutex_unlock(&state.gc_worker_stop_mutex);
	// sync.semaphore_release(&state.start_gc_thread);
	// thread.destroy(state.gc_thread);

	// Free all the values
	// Free null, true, and false

	delete(state.stack);
	delete(state.call_stack);

	delete_scope(state.global_scope);

	// This needs some more work so that we dont double free stuff like null, etc.
	gc_free_all(state, &state.gc);

	free_value(state, state.null_value);
	free_value(state, state.true_value);
	free_value(state, state.false_value);

	for v in state.number_pool {
		// We can call a normal free here because we know all entires *should*
		// be numbers and they dont have auxiallry memory
		free(v);
	}
	delete(state.number_pool);

	free(state);
}

get_userdata_type :: proc(state: ^State) -> i64 {
	t := state.userdata_counter;
	state.userdata_counter += 1;
	return t;
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
	//TODO: free nodes
	// defer {}
	if err != FileParseError.Ok {
		panic("invalid path");
	}

	if true {
		out, ok := os.open("out.dump", os.O_CREATE);
		for n in nodes {
			print_node(out, n);
		}
		os.close(out);
	}

	file_scope := parent;
	if import_into_file {
		file_scope = make_scope(parent);
	}

	// We dont really need to allocate this always
	// but does it really matter when it will be GCed?
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
		delete_scope(file_scope);
	}
}

// Things that aint right
// 

print_stats :: proc(state: ^State) {
	fmt.printf("\n\nStats:\n");
	fmt.printf("Total values: %d\n", state.total_values);
	fmt.printf("Max   values: %d\n\n", state.max_values);

	counts: map[typeid]int;
	defer delete(counts);
	obj := state.gc.all_objects;
	for obj != nil {
		v := cast(^Value) obj;
		obj = obj.next;

		counts[v.kind] += 1;
	}

	for k, v in counts {
		fmt.printf("%v: %v\n", k, v);
	}

	fmt.printf("\n");
}

main :: proc() {
	//dump_nodes(nodes);

	state := make_state();
	// sync.mutex_lock(&state.gc_worker_stop_mutex);
	// sync.mutex_lock(&state.gc_worker_stop_mutex);
	// sync.mutex_lock(&state.gc_worker_stop_mutex);
	// sync.mutex_lock(&state.gc_worker_stop_mutex);
	// sync.mutex_lock(&state.gc_worker_stop_mutex);
	// sync.mutex_unlock(&state.gc_worker_stop_mutex);
	//import_file(state, "tests/point.koi", true, "point");
	//import_file(state, state.global_scope, "test_gen.koi", false);
	//import_file(state, state.global_scope, "tests/gctest.koi", false);
	
	t1 := time.now();
	import_file(state, state.global_scope, "tests/tablesandfns.koi", false);
	//import_file(state, state.global_scope, "tests/theslowloopthing.koi", false);
	t2 := time.now();
	fmt.printf("%vms\n", time.diff(t1, t2) / time.Millisecond);
	

	main_v, ok := scope_get(state.global_scope, "main");
	if !ok {
		fmt.printf("Could not find 'main'!\n");
		os.exit(1);
	}
	main := main_v.value;

	if true {
		fmt.printf("size_of(Null)     = %d\n", size_of(Null));
		fmt.printf("size_of(True)     = %d\n", size_of(True));
		fmt.printf("size_of(False)    = %d\n", size_of(False));
		fmt.printf("size_of(Number)   = %d\n", size_of(Number));
		fmt.printf("size_of(String)   = %d\n", size_of(String));
		fmt.printf("size_of(Function) = %d\n", size_of(Function));
		fmt.printf("size_of(Array)    = %d\n", size_of(Array));
		fmt.printf("size_of(Table)    = %d\n", size_of(Table));
	}

	if false {
		mk := (cast(^Function)main).variant.(KoiFunction);
		out, err := os.open("dump.bin", os.O_RDWR|os.O_CREATE);
		dump: []u8 = transmute([]u8) mk.ops[:];
		os.write(out, dump);
		os.close(out);
	}

	fmt.printf("\nPROGRAM EXECUTION:\n");

	args: [dynamic]^Value;
	defer delete(args);

	a1 := new_value(state, Number);
	a1.value = 111;
	append(&args, a1);
	ret := call_function(state, cast(^Function) main, args[:]);
	
	fmt.printf("\n\nRETURN:\n");
	print_value(ret);
	fmt.printf("\n");

	print_stats(state);
	
	//koir.regex_function(state, args);

	delete_state(state);
}
