import flatbuffers.FlatBuffers;
import flatbuffers.FlatBuffers.ByteBuffer;
import flatbuffers.FlatBuffers.Offset;
import flatbuffers.FlatBuffers.Builder;
import flatbuffers.FlatBuffers.Long;
import flatbuffers.impl.FlatBuffersPure.Encoding;
import flatbuffers.impl.FlatBuffersPure.TableT;
import haxe.Int32;
import haxe.Int64;
import haxe.io.UInt8Array;
import haxe.io.UInt16Array;
import haxe.io.Int32Array;
#if js
import flatbuffers.io.Float32Array;
import flatbuffers.io.Float64Array;
#else
import haxe.io.Float32Array;
import haxe.io.Float64Array;
#end
import haxe.ds.Either;
import flatbuffers.json.Value;
import flatbuffers.json.ValueExtensions;
using flatbuffers.json.ValueExtensions;
import haxe.ds.StringMap;


enum abstract Color(Int) from Int to Int {
	var Red = 1;
	var Green = 2;
	var Blue = 8;
	@inline
	public function new(i:Int) {
		this = i;
	}
	@:op(a|b)
	public static function or(a:Color, b:Color):Color;
	@:op(a&b)
	public static function and(a:Color, b:Color):Color;
	public static function fromStringSingle(s:String):Null<Color> switch s {
		case "Red":return Red;
		case "Green":return Green;
		case "Blue":return Blue;
		default:return null;
	};
	public static function __tojson(e:Color):Value {
		var allFlags:Int = Red | Green | Blue;
		if ((e & ~allFlags) != 0) return VNumber(Std.string(e));
		var flags:Array<String> = [];
		{
			if ((e & Red) != 0) flags.push("Red");
			if ((e & Green) != 0) flags.push("Green");
			if ((e & Blue) != 0) flags.push("Blue");
		};
		var finalStr = flags.join(" ");
		return VString(finalStr);
	}
	public static function __json(val:Value):Color switch val {
		case VNumber(i):return new Color(Std.parseInt(i));
		case VString(s):{
			var parts = s.split(" ");
			var result = 0;
			for (part in parts) {
				var e = fromStringSingle(part);
				if (e == null) throw "Unknown enum value: " + part;
				result |= e;
			};
			return new Color(result);
		};
		default:throw "Only integer and string values are allowed for enum Color";
	};
}

enum abstract Race(Int) from Int to Int {
	var None = -1;
	var Human = 0;
	var Dwarf = 1;
	var Elf = 2;
	@inline
	public function new(i:Int) {
		this = i;
	}
	public static function fromStringSingle(s:String):Null<Race> switch s {
		case "None":return None;
		case "Human":return Human;
		case "Dwarf":return Dwarf;
		case "Elf":return Elf;
		default:return null;
	};
	public static function __tojson(e:Race):Value switch e {
		case None:return VString("None");
		case Human:return VString("Human");
		case Dwarf:return VString("Dwarf");
		case Elf:return VString("Elf");
		default:return VNumber(Std.string(cast(e, Int)));
	};
	public static function __json(val:Value):Race switch val {
		case VNumber(i):return new Race(Std.parseInt(i));
		case VString(s):{
			var e = fromStringSingle(s);
			if (e == null) throw "Unknown enum value: " + s;
			return e;
		};
		default:throw "Only integer and string values are allowed for enum Race";
	};
}

class Vec3 {
	var bb : ByteBuffer;
	var bb_pos : Int;
	public function new() { }
	public function __init(i:Int, bb:ByteBuffer):Vec3 {
		this.bb_pos = i;
		this.bb = bb;
		return this;
	}
	public static function createVec3(builder:Builder, x:Float, y:Float, z:Float):Offset {
		builder.prep(4, 12);
		builder.writeFloat32(z);
		builder.writeFloat32(y);
		builder.writeFloat32(x);
		return builder.offset();
	}
	public function x():Float {
		return this.bb.readFloat32(this.bb_pos + 0);
	}
	public function y():Float {
		return this.bb.readFloat32(this.bb_pos + 4);
	}
	public function z():Float {
		return this.bb.readFloat32(this.bb_pos + 8);
	}
	public static function __json(obj:haxe.ds.StringMap<Value>, builder:Builder):Offset {
		var val_x = obj.get("x");
		var val_y = obj.get("y");
		var val_z = obj.get("z");
		return Vec3.createVec3(builder, val_x.asFloat(), val_y.asFloat(), val_z.asFloat());
	}
	public static function __tojson(obj:Vec3):Value {
		var map = new haxe.ds.StringMap<Value>();
		map.set("x", VNumber(Std.string(obj.x())));
		map.set("y", VNumber(Std.string(obj.y())));
		map.set("z", VNumber(Std.string(obj.z())));
		return VObject(map);
	}
}

class AllTypes {
	var bb : ByteBuffer;
	var bb_pos : Int;
	public function new() { }
	public function __init(i:Int, bb:ByteBuffer):AllTypes {
		this.bb_pos = i;
		this.bb = bb;
		return this;
	}
	public static function getRootAsAllTypes(bb:ByteBuffer, ?obj:AllTypes):AllTypes {
		return obj != null ? obj.__init(bb.readInt32(bb.position()) + bb.position(), bb) : new AllTypes().__init(bb.readInt32(bb.position()) + bb.position(), bb);
	}
	public function a():Bool {
		var offset:Int = this.bb.__offset(this.bb_pos, 4);
		return offset != 0 ? (this.bb.readInt8(this.bb_pos + offset) != 0) : false;
	}
	public function b():Int {
		var offset:Int = this.bb.__offset(this.bb_pos, 6);
		return offset != 0 ? this.bb.readInt8(this.bb_pos + offset) : 0;
	}
	public function c():Int {
		var offset:Int = this.bb.__offset(this.bb_pos, 8);
		return offset != 0 ? this.bb.readInt8(this.bb_pos + offset) : 0;
	}
	public function d():Int {
		var offset:Int = this.bb.__offset(this.bb_pos, 10);
		return offset != 0 ? this.bb.readInt16(this.bb_pos + offset) : 0;
	}
	public function e():Int {
		var offset:Int = this.bb.__offset(this.bb_pos, 12);
		return offset != 0 ? this.bb.readInt16(this.bb_pos + offset) : 0;
	}
	public function f():Int {
		var offset:Int = this.bb.__offset(this.bb_pos, 14);
		return offset != 0 ? this.bb.readInt32(this.bb_pos + offset) : 0;
	}
	public function g():Int {
		var offset:Int = this.bb.__offset(this.bb_pos, 16);
		return offset != 0 ? this.bb.readInt32(this.bb_pos + offset) : 0;
	}
	public function h():Int64 {
		var offset:Int = this.bb.__offset(this.bb_pos, 18);
		return offset != 0 ? this.bb.readInt64(this.bb_pos + offset) : Int64.make(0, 0);
	}
	public function i():Int64 {
		var offset:Int = this.bb.__offset(this.bb_pos, 20);
		return offset != 0 ? this.bb.readInt64(this.bb_pos + offset) : Int64.make(0, 0);
	}
	public function j():Float {
		var offset:Int = this.bb.__offset(this.bb_pos, 22);
		return offset != 0 ? this.bb.readFloat32(this.bb_pos + offset) : 0.0;
	}
	public function k():Float {
		var offset:Int = this.bb.__offset(this.bb_pos, 24);
		return offset != 0 ? this.bb.readFloat64(this.bb_pos + offset) : 0.0;
	}
	public function l():Null<String> {
		var offset:Int = this.bb.__offset(this.bb_pos, 26);
		return offset != 0 ? this.bb.__string(this.bb_pos + offset) : null;
	}
	public static function startAllTypes(builder:Builder):Void {
		builder.startObject(12);
	}
	public static function addA(builder:Builder, a:Bool):Void {
		builder.addFieldInt8(0, a ? 1 : 0, 0);
	}
	public static function addB(builder:Builder, b:Int):Void {
		builder.addFieldInt8(1, b, 0);
	}
	public static function addC(builder:Builder, c:Int):Void {
		builder.addFieldInt8(2, c, 0);
	}
	public static function addD(builder:Builder, d:Int):Void {
		builder.addFieldInt16(3, d, 0);
	}
	public static function addE(builder:Builder, e:Int):Void {
		builder.addFieldInt16(4, e, 0);
	}
	public static function addF(builder:Builder, f:Int):Void {
		builder.addFieldInt32(5, f, 0);
	}
	public static function addG(builder:Builder, g:Int):Void {
		builder.addFieldInt32(6, g, 0);
	}
	public static function addH(builder:Builder, h:Int64):Void {
		builder.addFieldInt64(7, h, builder.createLong(0, 0));
	}
	public static function addI(builder:Builder, i:Int64):Void {
		builder.addFieldInt64(8, i, builder.createLong(0, 0));
	}
	public static function addJ(builder:Builder, j:Float):Void {
		builder.addFieldFloat32(9, j, 0.0);
	}
	public static function addK(builder:Builder, k:Float):Void {
		builder.addFieldFloat64(10, k, 0.0);
	}
	public static function addL(builder:Builder, lOffset:Offset):Void {
		builder.addFieldOffset(11, lOffset, 0);
	}
	public static function endAllTypes(builder:Builder):Offset {
		var offset:Int = builder.endObject();
		return offset;
	}
	public static function __json(obj:haxe.ds.StringMap<Value>, builder:Builder):Offset {
		var val_a = obj.get("a");
		var val_b = obj.get("b");
		var val_c = obj.get("c");
		var val_d = obj.get("d");
		var val_e = obj.get("e");
		var val_f = obj.get("f");
		var val_g = obj.get("g");
		var val_h = obj.get("h");
		var val_i = obj.get("i");
		var val_j = obj.get("j");
		var val_k = obj.get("k");
		var val_l = obj.get("l");
		var off_l:Offset = 0;
		if (val_l != null) off_l = builder.createString(Right(val_l.asString()));
		AllTypes.startAllTypes(builder);
		if (val_a != null) AllTypes.addA(builder, val_a.asBool());
		if (val_b != null) AllTypes.addB(builder, val_b.asInt());
		if (val_c != null) AllTypes.addC(builder, val_c.asInt());
		if (val_d != null) AllTypes.addD(builder, val_d.asInt());
		if (val_e != null) AllTypes.addE(builder, val_e.asInt());
		if (val_f != null) AllTypes.addF(builder, val_f.asInt());
		if (val_g != null) AllTypes.addG(builder, val_g.asInt());
		if (val_h != null) AllTypes.addH(builder, val_h.asInt64());
		if (val_i != null) AllTypes.addI(builder, val_i.asInt64());
		if (val_j != null) AllTypes.addJ(builder, val_j.asFloat());
		if (val_k != null) AllTypes.addK(builder, val_k.asFloat());
		if (off_l != 0) AllTypes.addL(builder, off_l);
		return AllTypes.endAllTypes(builder);
	}
	public static function __tojson(obj:AllTypes):Value {
		var map = new haxe.ds.StringMap<Value>();
		map.set("a", VBool(obj.a()));
		map.set("b", VNumber(Std.string(obj.b())));
		map.set("c", VNumber(Std.string(obj.c())));
		map.set("d", VNumber(Std.string(obj.d())));
		map.set("e", VNumber(Std.string(obj.e())));
		map.set("f", VNumber(Std.string(obj.f())));
		map.set("g", VNumber(Std.string(obj.g())));
		map.set("h", VNumber(Std.string(obj.h())));
		map.set("i", VNumber(Std.string(obj.i())));
		map.set("j", VNumber(Std.string(obj.j())));
		map.set("k", VNumber(Std.string(obj.k())));
		if (obj.l() != null) map.set("l", VString(obj.l()));
		return VObject(map);
	}
}

class Monster {
	var bb : ByteBuffer;
	var bb_pos : Int;
	public function new() { }
	public function __init(i:Int, bb:ByteBuffer):Monster {
		this.bb_pos = i;
		this.bb = bb;
		return this;
	}
	public static function finishMonsterBuffer(builder:Builder, offset:Offset):Void {
		builder.finish(offset, "MONS", false);
	}
	public static function finishSizePrefixedMonsterBuffer(builder:Builder, offset:Offset):Void {
		builder.finish(offset, "MONS", true);
	}
	public static function bufferHasIdentifier(bb:ByteBuffer):Bool {
		return bb.__has_identifier("MONS");
	}
	public static function getRootAsMonster(bb:ByteBuffer, ?obj:Monster):Monster {
		return obj != null ? obj.__init(bb.readInt32(bb.position()) + bb.position(), bb) : new Monster().__init(bb.readInt32(bb.position()) + bb.position(), bb);
	}
	public function pos(?obj:Null<Vec3>):Null<Vec3> {
		var offset:Int = this.bb.__offset(this.bb_pos, 4);
		return offset != 0 ? (obj != null ? obj : new Vec3()).__init(this.bb_pos + offset, this.bb) : null;
	}
	public function mana():Int {
		var offset:Int = this.bb.__offset(this.bb_pos, 6);
		return offset != 0 ? this.bb.readInt16(this.bb_pos + offset) : 0;
	}
	public function hp():Int {
		var offset:Int = this.bb.__offset(this.bb_pos, 8);
		return offset != 0 ? this.bb.readInt16(this.bb_pos + offset) : 0;
	}
	public function name():Null<String> {
		var offset:Int = this.bb.__offset(this.bb_pos, 10);
		return offset != 0 ? this.bb.__string(this.bb_pos + offset) : null;
	}
	public function friendly():Bool {
		var offset:Int = this.bb.__offset(this.bb_pos, 12);
		return offset != 0 ? (this.bb.readInt8(this.bb_pos + offset) != 0) : false;
	}
	public function inventory(index:Int):Int {
		var offset:Int = this.bb.__offset(this.bb_pos, 14);
		return offset != 0 ? this.bb.readInt8(this.bb.__vector(this.bb_pos + offset) + index * 1) : 0;
	}
	public function inventoryLength():Null<Int> {
		var offset:Int = this.bb.__offset(this.bb_pos, 14);
		return offset != 0 ? this.bb.__vector_len(this.bb_pos + offset) : 0;
	}
	public function inventoryArray():Null<UInt8Array> {
		var offset:Int = this.bb.__offset(this.bb_pos, 14);
		return offset != 0 ? UInt8Array.fromBytes(this.bb.bytes().view.buffer, this.bb.bytes().view.byteOffset + this.bb.__vector(this.bb_pos + offset), this.bb.__vector_len(this.bb_pos + offset)) : null;
	}
	public function color():Null<Color> {
		var offset:Int = this.bb.__offset(this.bb_pos, 16);
		return offset != 0 ? cast (this.bb.readInt8(this.bb_pos + offset)) : cast Color.Red;
	}
	public function weapons(index:Int, ?obj:Null<Weapon>):Null<Weapon> {
		var offset:Int = this.bb.__offset(this.bb_pos, 18);
		return offset != 0 ? (obj != null ? obj : new Weapon()).__init(this.bb.__indirect(this.bb.__vector(this.bb_pos + offset) + index * 4), this.bb) : null;
	}
	public function weaponsLength():Null<Int> {
		var offset:Int = this.bb.__offset(this.bb_pos, 18);
		return offset != 0 ? this.bb.__vector_len(this.bb_pos + offset) : 0;
	}
	public function path(index:Int, ?obj:Null<Vec3>):Null<Vec3> {
		var offset:Int = this.bb.__offset(this.bb_pos, 20);
		return offset != 0 ? (obj != null ? obj : new Vec3()).__init(this.bb.__vector(this.bb_pos + offset) + index * 12, this.bb) : null;
	}
	public function pathLength():Null<Int> {
		var offset:Int = this.bb.__offset(this.bb_pos, 20);
		return offset != 0 ? this.bb.__vector_len(this.bb_pos + offset) : 0;
	}
	public static function startMonster(builder:Builder):Void {
		builder.startObject(9);
	}
	public static function addPos(builder:Builder, posOffset:Offset):Void {
		builder.addFieldStruct(0, posOffset, 0);
	}
	public static function addMana(builder:Builder, mana:Int):Void {
		builder.addFieldInt16(1, mana, 0);
	}
	public static function addHp(builder:Builder, hp:Int):Void {
		builder.addFieldInt16(2, hp, 0);
	}
	public static function addName(builder:Builder, nameOffset:Offset):Void {
		builder.addFieldOffset(3, nameOffset, 0);
	}
	public static function addFriendly(builder:Builder, friendly:Bool):Void {
		builder.addFieldInt8(4, friendly ? 1 : 0, 0);
	}
	public static function addInventory(builder:Builder, inventoryOffset:Offset):Void {
		builder.addFieldOffset(5, inventoryOffset, 0);
	}
	public static function createInventoryVector(builder:Builder, data:Array<Int>):Offset {
		builder.startVector(1, data.length, 1);
		var i:Int = data.length - 1;
		while (i >= 0) { builder.addInt8(cast data[i]); i--; };
		return builder.endVector();
	}
	public static function startInventoryVector(builder:Builder, numElems:Int):Void {
		builder.startVector(1, numElems, 1);
	}
	public static function addColor(builder:Builder, color:Color):Void {
		builder.addFieldInt8(6, cast color, cast Color.Red);
	}
	public static function addWeapons(builder:Builder, weaponsOffset:Offset):Void {
		builder.addFieldOffset(7, weaponsOffset, 0);
	}
	public static function createWeaponsVector(builder:Builder, data:Array<Offset>):Offset {
		builder.startVector(4, data.length, 4);
		var i:Int = data.length - 1;
		while (i >= 0) { builder.addOffset(data[i]); i--; };
		return builder.endVector();
	}
	public static function startWeaponsVector(builder:Builder, numElems:Int):Void {
		builder.startVector(4, numElems, 4);
	}
	public static function addPath(builder:Builder, pathOffset:Offset):Void {
		builder.addFieldOffset(8, pathOffset, 0);
	}
	public static function startPathVector(builder:Builder, numElems:Int):Void {
		builder.startVector(12, numElems, 4);
	}
	public static function endMonster(builder:Builder):Offset {
		var offset:Int = builder.endObject();
		return offset;
	}
	public static function __json(obj:haxe.ds.StringMap<Value>, builder:Builder):Offset {
		var val_pos = obj.get("pos");
		var val_mana = obj.get("mana");
		var val_hp = obj.get("hp");
		var val_name = obj.get("name");
		var off_name:Offset = 0;
		if (val_name != null) off_name = builder.createString(Right(val_name.asString()));
		var val_friendly = obj.get("friendly");
		var val_inventory = obj.get("inventory");
		var off_inventory:Offset = 0;
		if (val_inventory != null) {
			var arr_inventory = val_inventory.asArray();
			var native_arr_inventory:Array<Int> = [];
			var i:Int = 0;
			do {
				native_arr_inventory.push(arr_inventory[i].asInt());
				++i;
			} while (i < arr_inventory.length);
			off_inventory = Monster.createInventoryVector(builder, native_arr_inventory);
		};
		var val_color = obj.get("color");
		var val_weapons = obj.get("weapons");
		var off_weapons:Offset = 0;
		if (val_weapons != null) {
			var arr_weapons = val_weapons.asArray();
			var offs_weapons:Array<Offset> = [];
			var i:Int = 0;
			do {
				offs_weapons.push(Weapon.__json(arr_weapons[i].asObject(), builder));
				++i;
			} while (i < arr_weapons.length);
			off_weapons = Monster.createWeaponsVector(builder, offs_weapons);
		};
		var val_path = obj.get("path");
		var off_path:Offset = 0;
		if (val_path != null) {
			var arr_path = val_path.asArray();
			Monster.startPathVector(builder, arr_path.length);
			var i:Int = arr_path.length - 1;
			do {
				Vec3.__json(arr_path[i].asObject(), builder);
				--i;
			} while (i >= 0);
			off_path = builder.endVector();
		};
		Monster.startMonster(builder);
		if (val_pos != null) Monster.addPos(builder, Vec3.__json(val_pos.asObject(), builder));
		if (val_mana != null) Monster.addMana(builder, val_mana.asInt());
		if (val_hp != null) Monster.addHp(builder, val_hp.asInt());
		if (off_name != 0) Monster.addName(builder, off_name);
		if (val_friendly != null) Monster.addFriendly(builder, val_friendly.asBool());
		if (off_inventory != 0) Monster.addInventory(builder, off_inventory);
		if (val_color != null) Monster.addColor(builder, Color.__json(val_color));
		if (off_weapons != 0) Monster.addWeapons(builder, off_weapons);
		if (off_path != 0) Monster.addPath(builder, off_path);
		return Monster.endMonster(builder);
	}
	public static function __tojson(obj:Monster):Value {
		var map = new haxe.ds.StringMap<Value>();
		if (obj.pos() != null) map.set("pos", Vec3.__tojson(obj.pos()));
		map.set("mana", VNumber(Std.string(obj.mana())));
		map.set("hp", VNumber(Std.string(obj.hp())));
		if (obj.name() != null) map.set("name", VString(obj.name()));
		map.set("friendly", VBool(obj.friendly()));
		if (obj.inventoryLength() > 0) map.set("inventory", {
			var arr:Array<Value> = [];
			var i:Int = 0;
			do {
				arr.push(VNumber(Std.string(obj.inventory(i))));
				++i;
			} while (i < obj.inventoryLength());
			VArray(arr);
		});
		map.set("color", Color.__tojson(obj.color()));
		if (obj.weaponsLength() > 0) map.set("weapons", {
			var arr:Array<Value> = [];
			var i:Int = 0;
			do {
				arr.push(Weapon.__tojson(obj.weapons(i)));
				++i;
			} while (i < obj.weaponsLength());
			VArray(arr);
		});
		if (obj.pathLength() > 0) map.set("path", {
			var arr:Array<Value> = [];
			var i:Int = 0;
			do {
				arr.push(Vec3.__tojson(obj.path(i)));
				++i;
			} while (i < obj.pathLength());
			VArray(arr);
		});
		return VObject(map);
	}
}

class Weapon {
	var bb : ByteBuffer;
	var bb_pos : Int;
	public function new() { }
	public function __init(i:Int, bb:ByteBuffer):Weapon {
		this.bb_pos = i;
		this.bb = bb;
		return this;
	}
	public static function getRootAsWeapon(bb:ByteBuffer, ?obj:Weapon):Weapon {
		return obj != null ? obj.__init(bb.readInt32(bb.position()) + bb.position(), bb) : new Weapon().__init(bb.readInt32(bb.position()) + bb.position(), bb);
	}
	public function name():Null<String> {
		var offset:Int = this.bb.__offset(this.bb_pos, 4);
		return offset != 0 ? this.bb.__string(this.bb_pos + offset) : null;
	}
	public function damage():Int {
		var offset:Int = this.bb.__offset(this.bb_pos, 6);
		return offset != 0 ? this.bb.readInt16(this.bb_pos + offset) : 0;
	}
	public static function startWeapon(builder:Builder):Void {
		builder.startObject(2);
	}
	public static function addName(builder:Builder, nameOffset:Offset):Void {
		builder.addFieldOffset(0, nameOffset, 0);
	}
	public static function addDamage(builder:Builder, damage:Int):Void {
		builder.addFieldInt16(1, damage, 0);
	}
	public static function endWeapon(builder:Builder):Offset {
		var offset:Int = builder.endObject();
		return offset;
	}
	public static function __json(obj:haxe.ds.StringMap<Value>, builder:Builder):Offset {
		var val_name = obj.get("name");
		var off_name:Offset = 0;
		if (val_name != null) off_name = builder.createString(Right(val_name.asString()));
		var val_damage = obj.get("damage");
		Weapon.startWeapon(builder);
		if (off_name != 0) Weapon.addName(builder, off_name);
		if (val_damage != null) Weapon.addDamage(builder, val_damage.asInt());
		return Weapon.endWeapon(builder);
	}
	public static function __tojson(obj:Weapon):Value {
		var map = new haxe.ds.StringMap<Value>();
		if (obj.name() != null) map.set("name", VString(obj.name()));
		map.set("damage", VNumber(Std.string(obj.damage())));
		return VObject(map);
	}
}

