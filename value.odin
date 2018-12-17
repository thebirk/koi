package koi

import "core:fmt"
import "core:sync"
import "shared:birk/arraylist"

GCColor :: enum {
	White = 0,
	Grey,
	Black,
}

// TODO: When we send a gcobject out of Koi, we mark is at foreign(aka. dont free me whatsover),
// when that functions returns, we remove the mark and they return to their normal lives.
GCObject :: struct {
	color: GCColor,
	is_constant: b8,
	next: ^GCObject,
	// Used only by GCObjects in the grey of black list
	next_list: ^GCObject,
	prev_list: ^GCObject,
}

Value :: struct {
	using gc: GCObject,
	kind: typeid,
	kind_str: string,
}

Null :: struct { using base: Value }
True :: struct { using base: Value }
False :: struct { using base: Value }

Number :: struct {
	using base: Value,
	value: f64,
}

String :: struct {
	using base: Value,
	str: string,
}

Function :: struct {
	using base: Value,
	loc: Location,
	stack_size: int, // This should be more than enough?
	arg_count: int,
	locals: int,
	variant: union {
		KoiFunction,
	},
}

KoiFunction :: struct {
	using func: ^Function,
	ops: [dynamic]Opcode,
	constants: [dynamic]^Value, // Shared by references unlike the stack.
	current_stack: int,
}

Array :: struct {
	using base: Value,
	data: arraylist.ArrayList(^Value),
}

Table :: struct {
	using base: Value,
	data: map[string]^Value,
}

is_null     :: proc(v: ^Value) -> bool do return v.kind == typeid_of(Null);
is_true     :: proc(v: ^Value) -> bool do return v.kind == typeid_of(True);
is_false    :: proc(v: ^Value) -> bool do return v.kind == typeid_of(False);
is_number   :: proc(v: ^Value) -> bool do return v.kind == typeid_of(Number);
is_string   :: proc(v: ^Value) -> bool do return v.kind == typeid_of(String);
is_function :: proc(v: ^Value) -> bool do return v.kind == typeid_of(Function);
is_array    :: proc(v: ^Value) -> bool do return v.kind == typeid_of(Array);
is_table    :: proc(v: ^Value) -> bool do return v.kind == typeid_of(Table);

using import "core:runtime";
new_value :: proc(state: ^State, $T: typeid, add_to_gc := true) -> ^T {
	val := new(T);
	val.kind = typeid_of(T);
	val.kind_str = (type_info_of(T).variant.(Type_Info_Named)).name;
	
	if add_to_gc {
		if state.marking {
			val.color = GCColor.Grey;
			sync.mutex_lock(&state.grey_list_mutex);
			val.next_list = state.grey_list;
			if state.grey_list != nil {
				state.grey_list.prev_list = cast(^GCObject) val;
			}
			state.grey_list = cast(^GCObject) val;
			sync.mutex_unlock(&state.grey_list_mutex);
		} else {
			val.color = GCColor.White;
			val.next = state.all_objects;
			state.all_objects = cast(^GCObject) val;
		}
		
		state.total_values += 1;
		//fmt.printf("%d\n", state.max_values);

		if state.total_values > state.max_values {
			//state.max_values = 2*state.total_values;
			//init_marking_phase(state);
		}
	} else {
		val.is_constant = true;
	}

	return val;
}

free_value :: proc(state: ^State, v: ^Value) {
	state.total_values -= 1;
	switch v.kind {
	case True, False, Null, Number:
		// Do nothing
	case String:
		s := cast(^String) v;
		delete(s.str);
	case Table:
		t := cast(^Table) v;
		if len(t.data) > 0 {
			delete(t.data);
		}
	case Array:
		arr := cast(^Array) v;
		panic("TODO: free Array");
	case Function:
		f := cast(^Function) v;
		fmt.printf("f: %#v\n", f^);
		panic("TODO: free Function");
	case: panic("Uncomplete free_value case!");
	}
	free(v);
}	

init_marking_phase :: proc(using state: ^State) {
	sync.mutex_lock(&state.marking_mutex);
	if marking {
		sync.mutex_unlock(&state.marking_mutex);	
		return;
	}
	marking = true;
	sync.mutex_unlock(&state.marking_mutex);
	fmt.printf("Starting to mark!\n");

	sync.mutex_lock(&state.grey_list_mutex);
	fmt.printf("Got grey list mutex!\n");
	for i in 0..top-1 {
		v := stack[i];
		if v == nil do continue;

		v.color = GCColor.Grey;
		v.next_list = state.grey_list;
		if state.grey_list != nil {
			state.grey_list.prev_list = v;
		}
		state.grey_list = v;
	}

	//TODO: Replace with state.global_names
	for k, v in state.global_scope.names {
		vv := v.value; // Workaround for silly mutability behaviour
		vv.color = GCColor.Grey;
		vv.next_list = state.grey_list;
		if state.grey_list != nil {
			state.grey_list.prev_list = vv;
		}
		state.grey_list = vv;
	}
	sync.mutex_unlock(&state.grey_list_mutex);

	// Kick off worker thread
	sync.semaphore_release(&state.start_gc_thread);
}

print_value :: proc(v: ^Value) {
	switch v.kind {
	case True: fmt.printf("True");
	case False: fmt.printf("False");
	case Null: fmt.printf("Null");
	case Number:
		n := cast(^Number) v;
		fmt.printf("Number: %f", n.value);
	case String:
		str := cast(^String) v;
		fmt.printf("String: \"%s\"", str.str);
	case Function: fmt.printf("Function");
	case Table:
		t := cast(^Table) v;
		fmt.printf("Table: {\n");
		for k, v in t.data {
			fmt.printf("    %v = %v,\n", k, v.kind);
		}
		fmt.printf("}\n");
	case Array: fmt.printf("Function");
	case: panic("Invalid value type");
	}
}