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

enum abstract Color(Int) from Int to Int {
	var Red = 1;
	var Green = 2;
	var Blue = 3;
	@inline
	public function new(i:Int) {
		this = i;
	}
	@:op(a|b)
	public static function or(a:Color, b:Color):Color;
	@:op(a&b)
	public static function and(a:Color, b:Color):Color;
}

enum abstract Race(Int) from Int to Int {
	var None = -1;
	var Human = 0;
	var Dwarf = 2;
	var Elf = 3;
	@inline
	public function new(i:Int) {
		this = i;
	}
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
}

