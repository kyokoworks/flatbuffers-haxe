package flatbuffers.json;

import haxe.ds.StringMap;

// A typed JSON value tree used by generated code. Numbers are stored as strings
// to preserve full precision (64-bit) until conversion.
enum Value {
	VNull;
	VBool(b:Bool);
	VNumber(s:String); // number stored as string
	VString(s:String);
	VObject(map:StringMap<Value>);
	VArray(arr:Array<Value>);
}