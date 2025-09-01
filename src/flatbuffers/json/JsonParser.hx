package flatbuffers.json;

import haxe.ds.StringMap;
import hxparse.Parser.parse as parse;

private enum Token {
	TBrOpen;
	TBrClose;
	TComma;
	TDblDot;
	TBkOpen;
	TBkClose;
	TDash;
	TDot;
	TTrue;
	TFalse;
	TNull;
	TNumber(v:String);
	TString(v:String);
	TEof;
}

class JsonLexer extends hxparse.Lexer implements hxparse.RuleBuilder {
	static var buf:StringBuf;

	public static var tok = @:rule [
		"{" => TBrOpen,
		"}" => TBrClose,
		"," => TComma,
		":" => TDblDot,
		"[" => TBkOpen,
		"]" => TBkClose,
		"-" => TDash,
		"\\." => TDot,
		"true" => TTrue,
		"false" => TFalse,
		"null" => TNull,
		"-?(([1-9][0-9]*)|0)(.[0-9]+)?([eE][\\+\\-]?[0-9]+)?" => TNumber(lexer.current),
		'"' => {
			buf = new StringBuf();
			lexer.token(string);
			TString(buf.toString());
		},
		"[\r\n\t ]" => lexer.token(tok),
		"" => TEof
	];

	static var string = @:rule [
		"\\\\t" => {
			buf.addChar("\t".code);
			lexer.token(string);
		},
		"\\\\n" => {
			buf.addChar("\n".code);
			lexer.token(string);
		},
		"\\\\r" => {
			buf.addChar("\r".code);
			lexer.token(string);
		},
		'\\\\"' => {
			buf.addChar('"'.code);
			lexer.token(string);
		},
		"\\\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]" => {
			buf.add(String.fromCharCode(Std.parseInt("0x" + lexer.current.substr(2))));
			lexer.token(string);
		},
		'"' => {
			lexer.curPos().pmax;
		},
		'[^"]' => {
			buf.add(lexer.current);
			lexer.token(string);
		},
	];
}

/** 
 * Controls how duplicate keys in JSON objects are handled during parsing.
 */
enum JsonDupePolicy {
	/**
	 * UseLastValue
	 *
	 * When an object contains multiple entries with the same key, the parser keeps
	 * the value from the final occurrence, overriding any earlier values for that key.
	 * Use this policy when later values should take precedence (simple last-wins behavior).
	 */
	UseLastValue;

	/**
	 * UseFirstValue
	 *
	 * When duplicate keys occur, the parser preserves the value from the first
	 * occurrence and ignores any subsequent entries with the same key.
	 * Use this policy to maintain the initial value and ignore later overrides.
	 */
	UseFirstValue;

	/**
	 * ErrorOnDuplicate
	 *
	 * Treat duplicate keys within the same object as a parsing error and emit/raise
	 * an error when a duplicate is encountered. Use this policy for strict validation
	 * and to catch ambiguous or invalid input.
	 */
	ErrorOnDuplicate;
}

class JsonParser extends hxparse.Parser<hxparse.LexerTokenSource<Token>, Token> implements hxparse.ParserBuilder {
	var dupePolicy:JsonDupePolicy;

	public function new(input:byte.ByteData, sourceName:String) {
		this.dupePolicy = ErrorOnDuplicate;

		var lexer = new JsonLexer(input, sourceName);
		var ts = new hxparse.LexerTokenSource(lexer, JsonLexer.tok);
		super(ts);
	}

	public function setDupePolicy(policy:JsonDupePolicy):Void {
		this.dupePolicy = policy;
	}

	public function parseJson():Value {
		return switch stream {
			case [TBrOpen, obj = parseObject()]: VObject(obj);
			case [TBkOpen, arr = parseArray()]: VArray(arr);
			case [TNumber(s)]: (VNumber(s));
			case [TTrue]: (VBool(true));
			case [TFalse]: (VBool(false));
			case [TNull]: (VNull);
			case [TString(s)]: (VString(s));
			case _:
				junk();
				throw 'Unexpected token in JSON input at position: ${stream.curPos()}';
		};
	}

	function parseObject():StringMap<Value> {
		var acc = new StringMap<Value>();
		while (true) {
			switch stream {
				case [TBrClose]:
					return acc;
				case [TString(s), TDblDot, e = parseJson()]:
					switch (dupePolicy) {
						case UseLastValue:
							acc.set(s, e);
						case UseFirstValue:
							if (!acc.exists(s)) acc.set(s, e);
						case ErrorOnDuplicate:
							if (acc.exists(s))
								throw 'Duplicate key in JSON object: ' + s;
							acc.set(s, e);
					}
					switch stream {
						case [TBrClose]: return acc;
						case [TComma]: // continue
					}
			}
		}
	}

	function parseArray():Array<Value> {
		var acc = new Array<Value>();
		while (true) {
			switch stream {
				case [TBkClose]:
					return acc;
				case [elt = parseJson()]:
					acc.push(elt);
					switch stream {
						case [TBkClose]: return acc;
						case [TComma]: // continue
					}
			}
		}
	}
}
