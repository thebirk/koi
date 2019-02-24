package koi

import "core:fmt"
import "core:math"

// POP       = No args
// PUSHK     = Push constant, A = constant index
// PUSHNULL  = Push null
// PUSHFALSE = Push false
// PUSHTRUE  = Push true
// GETLOCAL  = Get local, A = local index
// SETLOCAL  = Set local, A = local index
// GETGLOBAL = Get global
// SETGLOBAL = Set global
// UNM       = Unary minus
// ADD       = Addition
// SUB       = Subtraction
// MUL       = Multiplication
// DIV       = Division
// MOD       = Modulo
// EQ        = Equality test
// LT        = Less than test
// LTE       = Less than or equal test
// GT        = Greater than test
// GTE       = Greater than or equal test
// IFT       = Do next instruction if true
// IFF       = Do next instruction if true
// JMP       = Relative jmp, A = signed distance
// CALL      = Call a function
// RETURN    = Return
// NEWTABLE  = Push new table to stack
// SETTABLE  = Set table value
// GETTABLE  = Get table value
// NEWARRAY  = Push new array, A = initial size, 0 = empty
// SETARRAY  = Set array value
// GETARRAY  = Get array value
// PRINT     = Print expression
// LEN       = Push length of argument(on stack)

Opcode :: enum u8 {
	POP,
	PUSHK,
	PUSHNULL,
	PUSHFALSE, PUSHTRUE,
	GETLOCAL,
	SETLOCAL,
	GETGLOBAL,
	SETGLOBAL,
	UNM, ADD, SUB, MUL, DIV, MOD,
	EQ, LT, LTE, GT, GTE,
	IFT, IFF, JMP,
	CALL, RETURN,
	NEWTABLE, SETTABLE, GETTABLE,
	NEWARRAY, SETARRAY, GETARRAY,
	PRINT, LEN,
}

op_add :: inline proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
	if is_number(lhs) && is_number(rhs) {
		l := cast(^Number) lhs;
		r := cast(^Number) rhs;
		result := new_value(state, Number);
		result.value = l.value + r.value;
		return result;
	}

	panic("Unimplemented!");
	return nil;
}

op_sub :: inline proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
	if is_number(lhs) && is_number(rhs) {
		l := cast(^Number) lhs;
		r := cast(^Number) rhs;
		result := new_value(state, Number);
		result.value = l.value - r.value;
		return result;
	}

	panic("Unimplemented!");
	return nil;
}

op_mul :: inline proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
	if is_number(lhs) && is_number(rhs) {
		l := cast(^Number) lhs;
		r := cast(^Number) rhs;
		result := new_value(state, Number);
		result.value = l.value * r.value;
		return result;
	}

	panic("Unimplemented!");
	return nil;
}

op_div :: inline proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
	if is_number(lhs) && is_number(rhs) {
		l := cast(^Number) lhs;
		r := cast(^Number) rhs;
		result := new_value(state, Number);
		result.value = l.value / r.value;
		return result;
	}

	panic("Unimplemented!");
	return nil;
}

op_mod :: inline proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
	if is_number(lhs) && is_number(rhs) {
		l := cast(^Number) lhs;
		r := cast(^Number) rhs;
		result := new_value(state, Number);
		result.value = math.mod(l.value, r.value);
		return result;
	}

	panic("Unimplemented!");
	return nil;
}

op_eq :: inline proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
	if is_number(lhs) && is_number(rhs) {
		l := cast(^Number) lhs;
		r := cast(^Number) rhs;
		result: ^Value = nil;
		if l.value == r.value {
			result = state.true_value;
		} else {
			result = state.false_value;
		}
		return result;
	}

	return nil;
}

op_lt :: inline proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
	if is_number(lhs) && is_number(rhs) {
		l := cast(^Number) lhs;
		r := cast(^Number) rhs;
		result: ^Value = nil;
		if l.value < r.value {
			result = state.true_value;
		} else {
			result = state.false_value;
		}
		return result;
	}

	return nil;
}

op_lte :: inline proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
	if is_number(lhs) && is_number(rhs) {
		l := cast(^Number) lhs;
		r := cast(^Number) rhs;
		result: ^Value = nil;
		if l.value <= r.value {
			result = state.true_value;
		} else {
			result = state.false_value;
		}
		return result;
	}

	return nil;
}

op_gt :: inline proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
	if is_number(lhs) && is_number(rhs) {
		l := cast(^Number) lhs;
		r := cast(^Number) rhs;
		result: ^Value = nil;
		if l.value > r.value {
			result = state.true_value;
		} else {
			result = state.false_value;
		}
		return result;
	}

	return nil;
}

op_gte :: inline proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
	if is_number(lhs) && is_number(rhs) {
		l := cast(^Number) lhs;
		r := cast(^Number) rhs;
		result: ^Value = nil;
		if l.value >= r.value {
			result = state.true_value;
		} else {
			result = state.false_value;
		}
		return result;
	}

	return nil;
}


op_unm :: inline proc(state: ^State, rhs: ^Value) -> ^Value {
	if is_number(rhs) {
		r := cast(^Number) rhs;
		result := new_value(state, Number);
		result.value = -r.value;
		return result;
	}

	panic("Unimplemented!");
	return nil;
}

vm_len :: inline proc(state: ^State, val: ^Value) -> ^Value {
	res := new_value(state, Number);

	switch val.kind {
	case String:
		s := cast(^String) val;
		res.value = f64(len(s.str));
	case Table:
		t := cast(^Table) val;
		res.value = f64(len(t.data));
	case Array:
		a := cast(^Array) val;
		res.value = f64(a.data.size);
	case: panic("TODO: Better error");
	}

	return res;
}

call_function :: inline proc(state: ^State, func: ^Function, args: []^Value) -> ^Value {
	sf := push_call(state, func);
	result: ^Value = nil;
	#complete switch f in func.variant {
	case KoiFunction:
		result = exec_koi_function(state, cast(^KoiFunction) &func.variant, sf, args);
	}

	pop_call(state);

	return result;
}

vm_print_value :: inline proc(v: ^Value) {
	switch v.kind {
	case Null: fmt.printf("null");
	case True: fmt.printf("true");
	case False: fmt.printf("false");
	case Number:
		n := cast(^Number) v;
		fmt.printf("%f", n.value);
	case String:
		s := cast(^String) v;
		fmt.printf("%s", s.str);
	case Table:
		fmt.printf("[table @ %p]", v);
	case Array:
		fmt.printf("[array @ %p]", v);
	case Function:
		fmt.printf("[function @ %p]", v);
	case: panic("Invalid type");
	}
}

op_funcs: [len(Opcode)]proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool;

vm_init_table :: proc() {
	op_funcs =  [len(Opcode)]proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool{
		opcode_pop,
		opcode_pushk,
		opcode_pushnull,
		opcode_pushfalse,
		opcode_pushtrue,
		opcode_getlocal,
		opcode_setlocal,
		opcode_getglobal,
		opcode_setglobal,
		opcode_unm,
		opcode_add,
		opcode_sub,
		opcode_mul,
		opcode_div,
		opcode_mod,
		opcode_eq,
		opcode_lt,
		opcode_lte,
		opcode_gt,
		opcode_gte,
		opcode_ift,
		opcode_iff,
		opcode_jmp,
		opcode_call,
		opcode_return,
		opcode_newtable,
		opcode_settable,
		opcode_gettable,
		opcode_newarray,
		opcode_setarray,
		opcode_getarray,
		opcode_print,
		opcode_len,
	};
}

opcode_pop       :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	assert(sp^ > sf.bottom);
	sp^ -= 1;
	return false;
}
opcode_pushk     :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	k := func.ops[pc^]; pc^ += 1;
	state.stack[sp^] = func.constants[k]; sp^ += 1;
	return false;
}
opcode_pushnull  :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	state.stack[sp^] = state.null_value; sp^ += 1;
	return false;
}
opcode_pushfalse :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	state.stack[sp^] = state.false_value; sp^ += 1;
	return false;
}
opcode_pushtrue  :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	state.stack[sp^] = state.true_value; sp^ += 1;
	return false;
}
opcode_getlocal  :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	l := func.ops[pc^]; pc^ += 1;
	v := state.stack[sf.bottom+int(l)];
	state.stack[sp^] = v; sp^ += 1;
	return false;
}
opcode_setlocal  :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	l := func.ops[pc^]; pc^ += 1;
	sp^ -= 1; v := state.stack[sp^];
	state.stack[sf.bottom+int(l)] = v;
	return false;
}
opcode_getglobal :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	sp^ -= 1; s := state.stack[sp^];
	fmt.assertf(is_string(s), "Expected string value got %v", s.kind);
	name := cast(^String) s;

	v, _ := scope_get(state.global_scope, name.str);
	state.stack[sp^] = v.value; sp^ += 1;
	return false;
}
opcode_setglobal :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	sp^ -= 1; s := state.stack[sp^];
	fmt.assertf(is_string(s), "Expected string value got %v", s.kind);
	name := cast(^String) s;
	v, found := scope_get(state.global_scope, name.str); // Is this really needed?
	assert(found);
	sp^ -= 1; value := state.stack[sp^];
	scope_set(state.global_scope, name.str, value);

	return false;
}
opcode_unm       :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	sp^ -= 1; v := state.stack[sp^];
	res := op_unm(state, v);
	state.stack[sp^] = res; sp^ += 1;
	return false;
}
opcode_add       :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	sp^ -= 1; lhs := state.stack[sp^];
	sp^ -= 1; rhs := state.stack[sp^];
	r := op_add(state, lhs, rhs);
	state.stack[sp^] = r; sp^ += 1;
	return false;
}
opcode_sub       :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	sp^ -= 1; lhs := state.stack[sp^];
	sp^ -= 1; rhs := state.stack[sp^];
	r := op_sub(state, lhs, rhs);
	state.stack[sp^] = r; sp^ += 1;
	return false;
}
opcode_mul       :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	sp^ -= 1; lhs := state.stack[sp^];
	sp^ -= 1; rhs := state.stack[sp^];
	r := op_mul(state, lhs, rhs);
	state.stack[sp^] = r; sp^ += 1;
	return false;
}
opcode_div       :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	sp^ -= 1; lhs := state.stack[sp^];
	sp^ -= 1; rhs := state.stack[sp^];
	r := op_div(state, lhs, rhs);
	state.stack[sp^] = r; sp^ += 1;
	return false;
}
opcode_mod       :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	sp^ -= 1; lhs := state.stack[sp^];
	sp^ -= 1; rhs := state.stack[sp^];
	r := op_mod(state, lhs, rhs);
	state.stack[sp^] = r; sp^ += 1;
	return false;
}
opcode_eq        :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	sp^ -= 1; lhs := state.stack[sp^];
	sp^ -= 1; rhs := state.stack[sp^];
	r := op_eq(state, lhs, rhs);
	state.stack[sp^] = r; sp^ += 1;
	return false;
}
opcode_lt        :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	sp^ -= 1; lhs := state.stack[sp^];
	sp^ -= 1; rhs := state.stack[sp^];
	r := op_lt(state, lhs, rhs);
	state.stack[sp^] = r; sp^ += 1;
	return false;
}
opcode_lte       :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	sp^ -= 1; lhs := state.stack[sp^];
	sp^ -= 1; rhs := state.stack[sp^];
	r := op_lte(state, lhs, rhs);
	state.stack[sp^] = r; sp^ += 1;
	return false;
}
opcode_gt        :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	sp^ -= 1; lhs := state.stack[sp^];
	sp^ -= 1; rhs := state.stack[sp^];
	r := op_gt(state, lhs, rhs);
	state.stack[sp^] = r; sp^ += 1;
	return false;
}
opcode_gte       :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	sp^ -= 1; lhs := state.stack[sp^];
	sp^ -= 1; rhs := state.stack[sp^];
	r := op_gte(state, lhs, rhs);
	state.stack[sp^] = r; sp^ += 1;
	return false;
}
opcode_ift       :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	// assumes well-formed opcode
	sp^ -= 1; val := state.stack[sp^];
	if is_true(val) {
		return false;
	} else {
		pc^ += 3;
	}
	return false;
}
opcode_iff       :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	// assumes well-formed opcode
	sp^ -= 1; val := state.stack[sp^];
	if is_false(val) {
		return false;
	} else {
		pc^ += 3;
	}
	return false;
}
opcode_jmp       :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	a1 := u16(func.ops[pc^]); pc^ += 1;
	a2 := u16(func.ops[pc^]); pc^ += 1;
	dist := int(transmute(i16) (a1 << 8 | a2));
	pc^ += dist;
	return false;
}
opcode_call      :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	// Assuming varargs is passed as array.. nah
	// It would be easier if we created the table here

	// This is safe as the arguments are immeditaly copied out of the array in call_function
	static args_buffer: [dynamic]^Value;

	sp^ -= 1; f := state.stack[sp^];
	if !is_function(f) {
		print_value(f);
		fmt.printf("\n");
		fmt.assertf(is_function(f), "Expected Function got %v", f.kind);
	}
	fun := cast(^Function) f;
	clear(&args_buffer);
	for i in 0..fun.arg_count-1 {
		sp^ -= 1;
		append(&args_buffer, state.stack[sp^]);
	}
	ret := call_function(state, fun, args_buffer[:]);
	state.stack[sp^] = ret; sp^ += 1;
	return false;
}
opcode_return    :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	return true;
}
opcode_newtable  :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	v := new_value(state, Table);
	state.stack[sp^] = v; sp^ += 1;
	return false;
}
opcode_settable  :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	sp^ -= 1; key_v := state.stack[sp^];
	fmt.assertf(is_string(key_v), "expected string got %#v", key_v.kind);
	key := cast(^String) key_v;

	sp^ -= 1; value := state.stack[sp^];

	sp^ -= 1; table_v := state.stack[sp^];
	fmt.assertf(is_table(table_v), "expected table got %v", table_v.kind);
	table := cast(^Table) table_v;

	table.data[key.str] = value;

	state.stack[sp^] = table_v; sp^ += 1; // PUSH table back onto stack
	return false;
}
opcode_gettable  :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	sp^ -= 1; key_v := state.stack[sp^];
	fmt.assertf(is_string(key_v), "expected string got %#v", key_v.kind);
	key := cast(^String) key_v;

	sp^ -= 1; table_v := state.stack[sp^];
	fmt.assertf(is_table(table_v), "expected table got %v", table_v.kind);
	table := cast(^Table) table_v;

	//TODO: better error
	value, found := table.data[key.str];
	if !found {
		panic("value not in table, TODO: better error");
	}

	state.stack[sp^] = value; sp^ += 1;

	return false;
}
opcode_newarray  :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	v := new_value(state, Array);
	state.stack[sp^] = v; sp^ += 1;
	return false;
}
opcode_setarray  :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	sp^ -= 1; v := state.stack[sp^];
	sp^ -= 1; index_v := state.stack[sp^];
	assert(is_number(index_v));

	index := cast(^Number) index_v;

	sp^ -= 1; array_v := state.stack[sp^];
	assert(is_array(array_v));
	array := cast(^Array) array_v;

	i := int(index.value);
	panic("Incomplete");

	return false;
}
opcode_getarray  :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	panic("incomplete");

	return false;
}
opcode_print     :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	sp^ -= 1; v := state.stack[sp^];
	vm_print_value(v);
	fmt.printf("\n");
	return false;
}
opcode_len       :: proc(state: ^State, pc: ^int, sp: ^int, sf: ^StackFrame, func: ^KoiFunction) -> bool {
	sp^ -= 1; v := state.stack[sp^];
	res := vm_len(state, v);
	state.stack[sp^] = res; sp^ += 1;
	return false;
}


// Pass this a file scope, instead of have it using state.global_scope?
exec_koi_function :: proc(state: ^State, func: ^KoiFunction, sf: StackFrame, args: []^Value) -> ^Value {
	pc := 0;
	sp := sf.bottom;
	args_buffer: [dynamic]^Value; // Can we do without this?

	assert(len(args) == func.arg_count);

	for v in args {
		state.stack[sp] = v; sp += 1;
	}

	for i in 0..func.locals-len(args)-1 {
		sp += 1;
	}

	vm_loop: for {
		op := Opcode(func.ops[pc]);
		//fmt.printf("pc: % 3d, opcode: %v\n", pc, op);
		pc += 1;

		when false {
			fmt.printf("stack (%d):\n", func.stack_size);
			for v in state.stack[sf.bottom+func.locals:sf.bottom+func.locals+func.stack_size] {
				if v == nil {
					fmt.printf("nil\n");
				} else {
					switch v.kind {
					case Number:
						fmt.printf("%#v\n", (cast(^Number)v)^);
					case:
						fmt.printf("%#v\n", v);
					}
				}
			}
		}

		if u16(op) >= len(Opcode) do fmt.panicf("Invalid opcode %2x\n", u8(op));

		if op_funcs[op](state, &pc, &sp, &sf, func) {
			break vm_loop;
		}
/*
		using Opcode;
		switch op {
		case POP:
			assert(sp > sf.bottom);
			sp -= 1;
		case PUSHNULL:
			state.stack[sp] = state.null_value; sp += 1;
		case PUSHTRUE:
			state.stack[sp] = state.true_value; sp += 1;
		case PUSHFALSE:
			state.stack[sp] = state.false_value; sp += 1;
		case PUSHK:
			k := func.ops[pc]; pc += 1;
			state.stack[sp] = func.constants[k]; sp += 1;
		case GETLOCAL:
			l := func.ops[pc]; pc += 1;
			v := state.stack[sf.bottom+int(l)];
			state.stack[sp] = v; sp += 1;
		case SETLOCAL:
			l := func.ops[pc]; pc += 1;
			sp -= 1; v := state.stack[sp];
			state.stack[sf.bottom+int(l)] = v;
		case GETGLOBAL:
			sp -= 1; s := state.stack[sp];
			fmt.assertf(is_string(s), "Expected string value got %v", s.kind);
			name := cast(^String) s;

			v, _ := scope_get(state.global_scope, name.str);
			state.stack[sp] = v.value; sp += 1;
		case SETGLOBAL:
			sp -= 1; s := state.stack[sp];
			fmt.assertf(is_string(s), "Expected string value got %v", s.kind);
			name := cast(^String) s;
			v, found := scope_get(state.global_scope, name.str); // Is this really needed?
			assert(found);
			sp -= 1; value := state.stack[sp];
			scope_set(state.global_scope, name.str, value);
		case ADD:
			sp -= 1; lhs := state.stack[sp];
			sp -= 1; rhs := state.stack[sp];
			r := op_add(state, lhs, rhs);
			state.stack[sp] = r; sp += 1;
		case SUB:
			sp -= 1; lhs := state.stack[sp];
			sp -= 1; rhs := state.stack[sp];
			r := op_sub(state, lhs, rhs);
			state.stack[sp] = r; sp += 1;
		case MUL:
			sp -= 1; lhs := state.stack[sp];
			sp -= 1; rhs := state.stack[sp];
			r := op_mul(state, lhs, rhs);
			state.stack[sp] = r; sp += 1;
		case DIV:
			sp -= 1; lhs := state.stack[sp];
			sp -= 1; rhs := state.stack[sp];
			r := op_div(state, lhs, rhs);
			state.stack[sp] = r; sp += 1;
		case MOD:
			sp -= 1; lhs := state.stack[sp];
			sp -= 1; rhs := state.stack[sp];
			r := op_mod(state, lhs, rhs);
			state.stack[sp] = r; sp += 1;
		case EQ:
			sp -= 1; lhs := state.stack[sp];
			sp -= 1; rhs := state.stack[sp];
			r := op_eq(state, lhs, rhs);
			state.stack[sp] = r; sp += 1;
		case LT:
			sp -= 1; lhs := state.stack[sp];
			sp -= 1; rhs := state.stack[sp];
			r := op_lt(state, lhs, rhs);
			state.stack[sp] = r; sp += 1;
		case LTE:
			sp -= 1; lhs := state.stack[sp];
			sp -= 1; rhs := state.stack[sp];
			r := op_lte(state, lhs, rhs);
			state.stack[sp] = r; sp += 1;
		case CALL:
			// Assuming varargs is passed as array.. nah
			// It would be easier if we created the table here
			sp -= 1; f := state.stack[sp];
			if !is_function(f) {
				print_value(f);
				fmt.printf("\n");
				fmt.assertf(is_function(f), "Expected Function got %v", f.kind);
			}
			fun := cast(^Function) f;
			clear(&args_buffer);
			for i in 0..fun.arg_count-1 {
				sp -= 1;
				append(&args_buffer, state.stack[sp]);
			}
			ret := call_function(state, fun, args_buffer[:]);
			state.stack[sp] = ret; sp += 1;
		case JMP:
			a1 := u16(func.ops[pc]); pc += 1;
			a2 := u16(func.ops[pc]); pc += 1;
			dist := int(transmute(i16) (a1 << 8 | a2));
			pc += dist;
		case RETURN:
			break vm_loop; // Is it this easy?
		case NEWTABLE:
			v := new_value(state, Table);
			state.stack[sp] = v; sp += 1;
		case SETTABLE:
			sp -= 1; key_v := state.stack[sp];
			fmt.assertf(is_string(key_v), "expected string got %#v", key_v.kind);
			key := cast(^String) key_v;

			sp -= 1; value := state.stack[sp];

			sp -= 1; table_v := state.stack[sp];
			fmt.assertf(is_table(table_v), "expected table got %v", table_v.kind);
			table := cast(^Table) table_v;

			table.data[key.str] = value;

			state.stack[sp] = table_v; sp += 1; // PUSH table back onto stack
		case GETTABLE:
			sp -= 1; key_v := state.stack[sp];
			fmt.assertf(is_string(key_v), "expected string got %#v", key_v.kind);
			key := cast(^String) key_v;

			sp -= 1; table_v := state.stack[sp];
			fmt.assertf(is_table(table_v), "expected table got %v", table_v.kind);
			table := cast(^Table) table_v;

			//TODO: better error
			value, found := table.data[key.str];
			if !found {
				panic("value not in table, TODO: better error");
			}

			state.stack[sp] = value; sp += 1;
		case NEWARRAY:
			v := new_value(state, Array);
			state.stack[sp] = v; sp += 1;
		case SETARRAY:
			sp -= 1; v := state.stack[sp];
			sp -= 1; index_v := state.stack[sp];
			assert(is_number(index_v));

			index := cast(^Number) index_v;

			sp -= 1; array_v := state.stack[sp];
			assert(is_array(array_v));
			array := cast(^Array) array_v;

			i := int(index.value);
		case GETARRAY:
			panic("dfsdfs");
		case IFT:
			// assumes well-formed opcode
			sp -= 1; val := state.stack[sp];
			if is_true(val) {
				continue;
			} else {
				pc += 3;
			}
		case IFF:
			// assumes well-formed opcode
			sp -= 1; val := state.stack[sp];
			if is_false(val) {
				continue;
			} else {
				pc += 3;
			}
		case UNM:
			sp -= 1; v := state.stack[sp];
			res := op_unm(state, v);
			state.stack[sp] = res; sp += 1;
		case PRINT:
			sp -= 1; v := state.stack[sp];
			vm_print_value(v);
			fmt.printf("\n");
		case LEN:
			sp -= 1; v := state.stack[sp];
			res := vm_len(state, v);
			state.stack[sp] = res; sp += 1;
		case:
			fmt.panicf("Invalid opcode: %v", op);
		}
		*/
	}

	if false {
		fmt.printf("locals(%d):\n", func.locals);
		for v in state.stack[sf.bottom:func.locals] {
			if v == nil {
				fmt.printf("nil\n");
			} else {
				switch v.kind {
				case Number:
					fmt.printf("%#v\n", (cast(^Number)v)^);
				case:
					fmt.printf("%#v\n", v);
				}
			}
		}

		fmt.printf("stack (%d):\n", func.stack_size);
		for v in state.stack[sf.bottom+func.locals:sf.bottom+func.locals+func.stack_size] {
			if v == nil {
				fmt.printf("nil\n");
			} else {
				switch v.kind {
				case Number:
					fmt.printf("%#v\n", (cast(^Number)v)^);
				case:
					fmt.printf("%#v\n", v);
				}
			}
		}
	}

	delete(args_buffer);

	// What do we return? Element at the top of the stack, otherwise nil?
	// Assumes opcode is wellformed and always returns something
	return state.stack[sp-1];
}