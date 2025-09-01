package flatbuffers.json;

import haxe.ds.StringMap;

class ObjectNode {
	public var map:StringMap<Value>;

	public function new(m:StringMap<Value>) {
		this.map = m;
	}

	public function get(key:String):Null<Value> {
		return map.get(key);
	}

	public function keys():Iterator<String> {
		return map.keys();
	}
}

class JsonReader {
	public var root:Value;

	public function new(json:String) {
		var data = byte.ByteData.ofString(json);
		var p = new JsonParser(data, "JsonReader");
		var v = p.parseJson();
		root = v;
	}
}
