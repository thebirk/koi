package koi

import "core:strconv"
import "core:strings"

Node :: struct {
	loc: Location,
	kind: any,
}

NodeNull  :: struct {using node: Node}
NodeTrue  :: struct {using node: Node}
NodeFalse :: struct {using node: Node}

NodeIdent :: struct {
	using node: Node,
	name: string,
}

NodeNumber :: struct {
	using node: Node,
	value: f64,
}

NodeString :: struct {
	using node: Node,
	value: string,
}

NodeIndex :: struct {
	using node: Node,
	expr: ^Node,
	index: ^Node,
}

NodeField :: struct {
	using node: Node,
	expr: ^Node,
}

NodeCall :: struct {
	using node: Node,
	expr: ^Node,
	args: [dynamic]^Node,
}

NodeBinary :: struct {
	using node: Node,
	op: TokenType,
	lhs, rhs: ^Node,
}

NodeUnary :: struct {
	using node: Node,
	op: TokenType,
	expr: ^Node,
}

NodeAssignment :: struct {
	using node: Node,
	op: TokenType,
	lhs: ^Node,
	rhs: ^Node,
}

NodeBlock :: struct {
	using node: Node,
	stmts: [dynamic]^Node,
}

NodeVariableDecl :: struct {
	using node: Node,
	name: string,
	expr: ^Node,
}

NodeFn :: struct {
	using node: Node,
	name: string,
	args: [dynamic]string,
	last_is_vararg: bool,
	block: ^Node,
}

NodeIf :: struct {
	using node: Node,
	cond: ^Node,
	block: ^Node,
	else_: ^Node,
}

NodeForType :: enum {
	Expr,
	InExpr,
	Forever,
	Stmts,
}

NodeFor :: struct {
	using node: Node,
	forkind: NodeForType,
	expr: ^Node,
	inexpr: ^Node,
	cond: ^Node,
	step: ^Node,
}

NodeReturn :: struct {
	using node: Node,
	expr: ^Node,
}

new_node :: proc(parser: ^Parser, $T: typeid) -> ^T {
	n := new(T);
	n.kind = n^;
	return n;
}

make_ident :: proc(parser: ^Parser, t: Token) -> ^NodeIdent {
	n := new_node(parser, NodeIdent);
	n.loc = t.loc;
	n.name = strings.new_string(t.lexeme);
	return n;
}

make_number :: proc(parser: ^Parser, t: Token) -> ^NodeNumber {
	n := new_node(parser, NodeNumber);
	n.loc = t.loc;
	n.value = strconv.parse_f64(t.lexeme);
	return n;
}

make_string :: proc(parser: ^Parser, t: Token) -> ^NodeString {
	n := new_node(parser, NodeString);
	n.loc = t.loc;
	n.value = strings.new_string(t.lexeme);
	return n;
}

make_index :: proc(parser: ^Parser, op: Token, expr: ^Node, index: ^Node) -> ^NodeIndex {
	n := new_node(parser, NodeIndex);
	n.loc = op.loc;
	n.expr = expr;
	n.index = index;
	return n;
}

make_field :: proc(parser: ^Parser, op: Token, expr: ^Node) -> ^NodeField {
	n := new_node(parser, NodeField);
	n.loc = op.loc;
	n.expr = expr;
	return n;
}

make_binary :: proc(parser: ^Parser, op: Token, lhs, rhs: ^Node) -> ^NodeBinary {
	n := new_node(parser, NodeBinary);
	n.loc = op.loc;
	n.lhs = lhs;
	n.rhs = rhs;
	n.op = op.kind;
	return n;
}

make_unary :: proc(parser: ^Parser, op: Token, expr: ^Node) -> ^NodeUnary {
	n := new_node(parser, NodeUnary);
	n.loc = op.loc;
	n.expr = expr;
	n.op = op.kind;
	return n;
}

make_assignment :: proc(parser: ^Parser, op: Token, lhs, rhs: ^Node) -> ^NodeAssignment {
	n := new_node(parser, NodeAssignment);
	n.loc = op.loc;
	n.lhs = lhs;
	n.rhs = rhs;
	return n;
}

make_block :: proc(parser: ^Parser, t: Token, stmts: [dynamic]^Node) -> ^NodeBlock {
	n := new_node(parser, NodeBlock);
	n.loc = t.loc;
	n.stmts = stmts;
	return n;
}

make_variable_decl :: proc(parser: ^Parser, op: Token, expr: ^Node) -> ^NodeVariableDecl {
	n := new_node(parser, NodeVariableDecl);
	n.loc = op.loc;
	n.expr = expr;
	n.name = strings.new_string(op.lexeme);
	return n;
}

make_variable_decl_named :: proc(parser: ^Parser, t: Token, name: string, expr: ^Node) -> ^NodeVariableDecl {
	n := new_node(parser, NodeVariableDecl);
	n.loc = t.loc;
	n.name = name;
	n.expr = expr;
	return n;
}

make_fn :: proc(parser: ^Parser, fn: Token, name: Token, args: [dynamic]string, last_is_vararg: bool, block: ^Node) -> ^NodeFn {
	n := new_node(parser, NodeFn);
	n.loc = fn.loc;
	n.name = strings.new_string(name.lexeme);
	n.args = args;
	n.last_is_vararg = last_is_vararg;
	n.block = block;
	return n;
}

make_if :: proc(parser: ^Parser, t: Token, cond: ^Node, block: ^Node, else_: ^Node) -> ^NodeIf {
	n := new_node(parser, NodeIf);
	n.loc = t.loc;
	n.cond = cond;
	n.block = block;
	n.else_ = else_;
	return n;
}

make_return :: proc(parser: ^Parser, t: Token, expr: ^Node) -> ^NodeReturn {
	n := new_node(parser, NodeReturn);
	n.loc = t.loc;
	n.expr = expr;
	return n;
}

make_null :: proc(parser: ^Parser, t: Token) -> ^NodeNull {
	n := new_node(parser, NodeNull);
	n.loc = t.loc;
	return n;
}

make_true :: proc(parser: ^Parser, t: Token) -> ^NodeTrue {
	n := new_node(parser, NodeTrue);
	n.loc = t.loc;
	return n;
}

make_false :: proc(parser: ^Parser, t: Token) -> ^NodeFalse {
	n := new_node(parser, NodeFalse);
	n.loc = t.loc;
	return n;
}