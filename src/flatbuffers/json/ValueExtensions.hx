package flatbuffers.json;

import flatbuffers.json.Value;
import haxe.ds.StringMap;
import haxe.Int64;

// Extension methods for enum Value so generated code can call methods on Value directly.
class ValueExtensions {
	public static inline function isNull(v:Value):Bool {
		return switch (v) {
			case VNull: true;
			default: false;
		}
	}

	public static inline function isString(v:Value):Bool {
		return switch (v) {
			case VString(_): true;
			default: false;
		}
	}

	public static inline function isNumber(v:Value):Bool {
		return switch (v) {
			case VNumber(_): true;
			default: false;
		}
	}

	public static inline function isBool(v:Value):Bool {
		return switch (v) {
			case VBool(_): true;
			default: false;
		}
	}

	public static inline function asString(v:Value):String {
		return switch (v) {
			case VString(s): s;
			case VNumber(s): s;
			default: throw 'Not a string';
		}
	}

	public static inline function asInt(v:Value):Int {
		switch (v) {
			case VNumber(s):
				var n = Std.parseInt(s);
				if (n == null)
					throw 'Not an int';
				return n;
			default:
				throw 'Not an int';
		}
	}

	public static inline function asInt64(v:Value):Int64 {
		switch (v) {
			case VNumber(s) | VString(s):
				var n = Int64.parseString(s);
				return n;
			default:
				throw 'Not an int64';
		}
	}

	public static inline function asFloat(v:Value):Float {
		switch (v) {
			case VNumber(s):
				return Std.parseFloat(s);
			default:
				throw 'Not a float';
		}
	}

	public static inline function asBool(v:Value):Bool {
		return switch (v) {
			case VBool(b): b;
			default: throw 'Not a bool';
		}
	}

	public static inline function asObject(v:Value):StringMap<Value> {
		return switch (v) {
			case VObject(m): m;
			default: throw 'Not an object';
		}
	}

	// Return the underlying array of Values. Legacy code expecting ValueNode is provided below.
	public static inline function asArray(v:Value):Array<Value> {
		return switch (v) {
			case VArray(a): a;
			default: throw 'Not an array';
		}
	}

	// public static inline function asString(v:Null<Value>):String {
	// 	return asString(cast(v, Value));
	// }

	// public static inline function asInt(v:Null<Value>):Int {
	// 	return asInt(cast(v, Value));
	// }

	// public static inline function asInt64(v:Null<Value>):Int64 {
	// 	return asInt64(cast(v, Value));
	// }

	// public static inline function asFloat(v:Null<Value>):Float {
	// 	return asFloat(cast(v, Value));
	// }

	// public static inline function asBool(v:Null<Value>):Bool {
	// 	return asBool(cast(v, Value));
	// }

	// public static inline function asObject(v:Null<Value>):StringMap<Value> {
	// 	return asObject(cast(v, Value));
	// }

	// public static inline function asArray(v:Null<Value>):Array<Value> {
	// 	return asArray(cast(v, Value));
	// }
}
