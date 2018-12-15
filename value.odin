package koi

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
	next: ^GCObject,
	// Used only by GCObjects in the grey of black list
	next_list: ^GCObject,
	prev_list: ^GCObject,
}

Value :: struct {
	using gc: GCObject,
	kind: typeid,
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

new_value :: proc(state: ^State, $T: typeid) -> ^T {
	val := new(T);
	
	if state.marking {
		val.color = GCColor.Grey;
		val.next = state.grey_list;
		state.grey_list = cast(^GCObject) val;
	} else {
		val.color = GCColor.White;
		val.next = state.all_objects;
		state.all_objects = cast(^GCObject) val;
	}

	val.kind = typeid_of(T);
	return val;
}

init_marking_phase :: proc(using state: ^State) {
	sync.mutex_lock(&state.marking_mutex);
	marking = true;
	sync.mutex_unlock(&state.marking_mutex);

	for i in 0..top-1 {
		v := stack[i];

		// This needs to be doubly linked list
		v.next = state.grey_list;
		v.color = GCColor.Grey;
		state.grey_list = v;
	}

	// Kick off worker thread
	sync.semaphore_release(&state.start_gc_thread);
}