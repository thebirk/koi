package koi

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
}

Value :: struct {
	using gc: GCObject,
	kind: typeid,
}

Null :: struct { using _: Value }
True :: struct { using _: Value }
False :: struct { using _: Value }

Number :: struct {
	using _: Value,
	value: f64,
}

String :: struct {
	using _: Value,
	str: string,
}

Function :: struct {
	using _: Value,
	loc: Location,
	stack_size: int, // This should be more than enough?
	arg_count: int,
	variant: union {
		KoiFunction,
	},
}

KoiFunction :: struct {
	using func: ^Function,
	ops: [dynamic]u8,
	constants: [dynamic]^Value, // Shared by references unlike the stack.
	locals: int,
}

Array :: struct {
	using _: Value,
	data: arraylist.ArrayList(^Value),
}

Table :: struct {
	using _: Value,
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
	marking = true;

	for i in 0..top-1 {
		v := stack[i];

		// This needs to be doubly linked list
		v.next = state.grey_list;
		v.color = GCColor.Grey;
		state.grey_list = v;
	}
}