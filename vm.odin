package koi

import "core:fmt"
import "core:math"

// JMP 0 - would be a nop
// 1: EQ 1  - next instr + 1 if false
// 2: PUSHTRUE
// 3: JMP 1 - next instr + 1
// 4: PUSHFALSE
// 5: ...

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
	NEWARRAY,
	PRINT,
}

op_add :: proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
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

op_sub :: proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
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

op_mul :: proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
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

op_div :: proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
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

op_mod :: proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
	if is_number(lhs) && is_number(rhs) {
		l := cast(^Number) lhs;
		r := cast(^Number) rhs;
		result := new_value(state, Number);
		fmt.printf("math.mod(3, 2) = %v\n", math.mod_f64(3, 2));
		result.value = math.mod(l.value, r.value);
		return result;
	}

	panic("Unimplemented!");
	return nil;
}

op_eq :: proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
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

op_lt :: proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
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

op_lte :: proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
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

op_unm :: proc(state: ^State, rhs: ^Value) -> ^Value {
	if is_number(rhs) {
		r := cast(^Number) rhs;
		result := new_value(state, Number);
		result.value = -r.value;
		return result;
	}

	panic("Unimplemented!");
	return nil;
}

call_function :: proc(state: ^State, func: ^Function, args: []^Value) -> ^Value {
	sf := push_call(state, func);
	result: ^Value = nil;
	#complete switch f in func.variant {
	case KoiFunction:
		result = exec_koi_function(state, cast(^KoiFunction) &func.variant, sf, args);
	}

	pop_call(state);

	return result;
}

// Pass this a file scope, instead of have it using state.global_scope?
exec_koi_function :: proc(state: ^State, func: ^KoiFunction, sf: StackFrame, args: []^Value) -> ^Value {
	pc := 0;
	sp := sf.bottom;
	args_buffer: [dynamic]^Value;

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

		if false {
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
			panic("mod is broken, pls fix|");
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
			assert(is_function(f));
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
			print_value(v);
			fmt.printf("\n");
		case:
			fmt.panicf("Invalid opcode: %v", op);
		}
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

	// What do we return? Element at the top of the stack, otherwise nil?
	// Assumes opcode is wellformed and always returns something
	return state.stack[sp-1];
}