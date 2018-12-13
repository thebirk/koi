package koi

import "core:fmt"

Opcode :: enum u8 {
	POP,
	PUSHK,
	PUSHNULL,
	PUSHFALSE, PUSHTRUE,
	GETLOCAL,
	SETLOCAL,
	GETGLOBAL,
	SETGLOBAL,
	ADD, SUB, MUL, DIV, MOD,
	CALL,
	JMP,
	EQ, LT, LTE,
	RETURN,
}

add :: proc(state: ^State, lhs, rhs: ^Value) -> ^Value {
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

call_function :: proc(state: ^State, func: ^Function, args: []^Value) {
	sf := push_call(state, func);
	#complete switch f in func.variant {
	case KoiFunction:
		exec_koi_function(state, cast(^KoiFunction)func, sf, args);
	}

	pop_call(state);
}

exec_koi_function :: proc(state: ^State, func: ^KoiFunction, sf: StackFrame, args: []^Value) -> ^Value {
	pc := 0;
	sp := sf.bottom;
	args_buffer: [dynamic]^Value;

	for v in args {
		state.stack[sp] = v; sp += 1;
	}

	for {
		op := Opcode(func.ops[pc]);
		pc += 1;
		
		using Opcode;
		switch op {
		case POP:
			assert(sp > sf.bottom);
			sp -= 1;
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
		case GETGLOBAL: panic("Opcode not implemented");
		case SETGLOBAL: panic("Opcode not implemented");
		case ADD:
			sp -= 1; lhs := state.stack[sp];
			sp -= 1; rhs := state.stack[sp];
			r := add(state, lhs, rhs);
			state.stack[sp] = r; sp += 1;
		case SUB: panic("Opcode not implemented");
		case MUL: panic("Opcode not implemented");
		case DIV: panic("Opcode not implemented");
		case MOD: panic("Opcode not implemented");
		case CALL:
			// Assuming varargs is passed as table
			sp -= 1; f := state.stack[sp];
			fun := cast(^Function) f;
			clear(&args_buffer);
			for i in 0..fun.arg_count-1 {
				sp -= 1;
				append(&args_buffer, state.stack[sp]);
			}
		case JMP:
			a1 := u16(func.ops[pc]); pc += 1;
			a2 := u16(func.ops[pc]); pc += 1;
			pc += int(transmute(i16) (a1 << 8 | a2));
		case EQ: panic("Opcode not implemented");
		case LT: panic("Opcode not implemented");
		case LTE: panic("Opcode not implemented");
		case RETURN:
			break; // Is it this easy?

		case:
			fmt.panicf("Invalid opcode: %x", op);
		}
	}

	// What do we return? Element at the top of the stack, otherwise nil?
	return nil;
}