package koi

import "core:fmt"
import "core:unicode/utf8"
import "shared:utf8proc"

TokenTypes :: distinct bit_set[TokenType];
TokenType :: enum {
	Eof,
	Ident,
	Fn,
	Return,
	Break,
	Continue,
	Var,
	Becomes,
	Do,
	If,
	Else,
	Import,
	For,   // iterators ala next(it)?
	In,
	Print,
	Len,
	Number,
	String,
	True,
	False,
	Null,
	SemiColon,
	Dot,
	Comma,
	Vararg,
	LeftPar,
	RightPar,
	LeftBrace,
	RightBrace,
	LeftBracket,
	RightBracket,
	Plus, Minus,
	Asterisk, Slash, Mod,
	LogicalNot,                      // !
	LogicalAnd, LogicalOr,           // && ||
	Equals, NotEqual,                // == !=
	GreaterThan, GreaterThanOrEqual, // > >=
	LessThan, LessThanOrEqual,       // < <=
	Equal,                           // =
	PlusEqual, MinusEqual,           // +=, -=
	AsteriskEqual, SlashEqual,       // *=, /=
	ModEqual,                        // %=
}

Location :: union {
	SourceLoc,
	BuiltinLoc,
}

SourceLoc :: struct {
	file: string,
	line: int,
	character: int,
}

BuiltinLoc :: struct {
	file: string,
	procedure: string,
	line: int,
	character: int,
}

print_location :: proc(location: Location) {
	#complete switch loc in location {
		case SourceLoc: fmt.printf("%s(%d:%d):", loc.file, loc.line, loc.character);
		case BuiltinLoc: panic("TODO: Implement BuiltinLoc printing. Using bps odin-path to print pretty paths.");
	}
}

get_builtin_loc :: proc(loc := #caller_location) -> Location {
	return BuiltinLoc{loc.file_path, loc.procedure, loc.line, loc.column};
}

Token :: struct {
	kind: TokenType,
	lexeme: string,
	loc: Location,
}

next_rune :: proc(parser: ^Parser) -> rune {
	parser.current_rune_offset = parser.offset;

	r, length := utf8.decode_rune(parser.data[parser.offset:]);
	if r == utf8.RUNE_ERROR {
		// return TokenType.Eof
	}
	parser.offset += length;
	parser.current_rune = r;
	parser.current_character += 1;

	return r;
}

is_alpha :: proc(r: rune) -> bool {
	return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z');
}

is_alnum :: proc(r: rune) -> bool {
	return is_alpha(r) || (r >= '0' && r <= '9');
}

is_letter :: proc(r: rune) -> bool {
	cat := utf8proc.category(r);
	return
		(cat == utf8proc.Category.LU ||
		 cat == utf8proc.Category.LL ||
		 cat == utf8proc.Category.LT ||
		 cat == utf8proc.Category.LM ||
		 cat == utf8proc.Category.LO
		);
}

is_ident :: proc(r: rune) -> bool {
	cat := utf8proc.category(r);
	return 
		(cat == utf8proc.Category.LU ||
		 cat == utf8proc.Category.LL ||
		 cat == utf8proc.Category.LT ||
		 cat == utf8proc.Category.LM ||
		 cat == utf8proc.Category.LO
		)
		|| (cat == utf8proc.Category.ND ||
			cat == utf8proc.Category.NL ||
			cat == utf8proc.Category.NO
			)
		|| r == '_';
}

read_token :: proc(parser: ^Parser) -> Token {
	loc := SourceLoc{parser.filepath, parser.current_line, parser.current_character};

	start := parser.current_rune_offset;
	r := parser.current_rune;
	if r == utf8.RUNE_ERROR do return Token{TokenType.Eof, "eof", loc};

	if r == '\n' {
		next_rune(parser);
		parser.current_line += 1;
		parser.current_character = 1;
		return read_token(parser); //WARNING Recursion danger
	}

	if r == ' ' || r == '\t' || r == '\r' {
		next_rune(parser);
		return read_token(parser); //WARNING Recursion danger	
	}

	switch r {
		case ';': next_rune(parser); return Token{TokenType.SemiColon,    ";", loc};
		case ',': next_rune(parser); return Token{TokenType.Comma,        ",", loc};
		case '(': next_rune(parser); return Token{TokenType.LeftPar,      "(", loc};
		case ')': next_rune(parser); return Token{TokenType.RightPar,     ")", loc};
		case '{': next_rune(parser); return Token{TokenType.LeftBrace,    "{", loc};
		case '}': next_rune(parser); return Token{TokenType.RightBrace,   "}", loc};
		case '[': next_rune(parser); return Token{TokenType.LeftBracket,  "[", loc};
		case ']': next_rune(parser); return Token{TokenType.RightBracket, "]", loc};


		case '.': {
			r = next_rune(parser);
			if r == '.' {
				next_rune(parser);
				return Token{TokenType.Vararg, "..", loc};
			} else {
				return Token{TokenType.Dot, ".", loc};
			}
		}
		case '|': {
			r = next_rune(parser);
			if r == '|' {
				next_rune(parser);
				return Token{TokenType.LogicalOr, "||", loc};
			} else {
				// Fall down to invalid characterr
			}
		}
		case '&': {
			r = next_rune(parser);
			if r == '&' {
				next_rune(parser);
				return Token{TokenType.LogicalAnd, "&&", loc};
			} else {
				// Fall down to invalid characterr
			}
		}
		case '>': {
			r = next_rune(parser);
			if r == '=' {
				next_rune(parser);
				return Token{TokenType.GreaterThanOrEqual, ">=", loc};
			} else {
				return Token{TokenType.GreaterThan, ">", loc};
			}
		}
		case '<': {
			r = next_rune(parser);
			if r == '=' {
				next_rune(parser);
				return Token{TokenType.LessThanOrEqual, "<=", loc};
			} else {
				return Token{TokenType.LessThan, "<", loc};
			}
		}
		case ':': {
			r = next_rune(parser);
			if r == '=' {
				next_rune(parser);
				return Token{TokenType.Becomes, ":=", loc};
			} else {
				// Fall down to invalid character	
			}
		}
		case '=': {
			r = next_rune(parser);
			if r == '=' {
				next_rune(parser);
				return Token{TokenType.Equals, "==", loc};
			} else {
				return Token{TokenType.Equal, "=", loc};
			}
		}
		case '+': {
			r = next_rune(parser);
			if r == '=' {
				next_rune(parser);
				return Token{TokenType.PlusEqual, "+=", loc};
			} else {
				return Token{TokenType.Plus, "+", loc};
			}
		}
		case '-': {
			r = next_rune(parser);
			if r == '=' {
				next_rune(parser);
				return Token{TokenType.MinusEqual, "-=", loc};
			} else {
				return Token{TokenType.Minus, "-", loc};
			}
		}
		case '*': {
			r = next_rune(parser);
			if r == '=' {
				next_rune(parser);
				return Token{TokenType.AsteriskEqual, "*=", loc};
			} else {
				return Token{TokenType.Asterisk, "*", loc};
			}
		}
		case '/': {
			r = next_rune(parser);
			if r == '=' {
				next_rune(parser);
				return Token{TokenType.SlashEqual, "/=", loc};
			}
			else if r == '/' {
				next_rune(parser);

				for parser.current_rune != '\n' && parser.current_rune != utf8.RUNE_ERROR {
					next_rune(parser);
				}

				return read_token(parser);
			}
			else {
				return Token{TokenType.Slash, "/", loc};
			}
		}
		case '%': {
			r = next_rune(parser);
			if r == '=' {
				next_rune(parser);
				return Token{TokenType.ModEqual, "%=", loc};
			} else {
				return Token{TokenType.Mod, "%", loc};
			}
		}
		case '!': {
			r = next_rune(parser);
			if r == '=' {
				next_rune(parser);
				return Token{TokenType.NotEqual, "!=", loc};
			} else {
				return Token{TokenType.LogicalNot, "!", loc};
			}
		}

		case '"': {
			r = next_rune(parser);
			start = parser.current_rune_offset;

			//TODO: Handle escapes
			for {
				if r == '"' do break;

				r = next_rune(parser);
				if r == utf8.RUNE_ERROR do parser_error(parser, Token{loc=loc}, "unexpected end of file while parsing string");
			}

			lexeme := string(parser.data[start:parser.current_rune_offset]);
			next_rune(parser);
			return Token{TokenType.String, lexeme, loc};
		}

		case '0'..'9': {
			found_dot := false;

			for {
				if r == '.' {
					if found_dot {
						break;
					} else {
						found_dot = true;
					}
				}
				r = next_rune(parser);

				if (r < '0' || r > '9') && r != '.' do break;
			}

			lexeme := string(parser.data[start:parser.current_rune_offset]);
			return Token{TokenType.Number, lexeme, loc};
		}

		case: {
			if is_letter(r) || r == '_' {
				for {
					r = next_rune(parser);

					if !is_ident(r) do break;
				}

				lexeme := string(parser.data[start:parser.current_rune_offset]);
				token_type := TokenType.Ident;
				switch lexeme {
					case "var"      : token_type = TokenType.Var;
					case "if"       : token_type = TokenType.If;
					case "true"     : token_type = TokenType.True;
					case "null"     : token_type = TokenType.Null;
					case "print"    : token_type = TokenType.Print;
					case "len"      : token_type = TokenType.Len;
					case "in"       : token_type = TokenType.In;
					case "false"    : token_type = TokenType.False;
					case "else"     : token_type = TokenType.Else;
					case "fn"       : token_type = TokenType.Fn;
					case "import"   : token_type = TokenType.Import;
					case "return"   : token_type = TokenType.Return;
					case "do"       : token_type = TokenType.Do;
					case "for"      : token_type = TokenType.For;
					case "break"    : token_type = TokenType.Break;
					case "continue" : token_type = TokenType.Continue;
				}

				return Token{token_type, lexeme, loc};
			}
		}
	}

	fmt.printf("%s(%d:%d): Invalid character '%r'/%d!\n", loc.file, loc.line, loc.character, r, r);
	panic("");
	return Token{TokenType.Eof, "eof", loc};
}