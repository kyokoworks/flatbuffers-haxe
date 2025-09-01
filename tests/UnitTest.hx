package;

import haxe.unit.TestRunner;
import haxe.unit.TestCase;
import flatbuffers.FlatBuffers;
import flatbuffers.FlatBuffers.Builder;
import flatbuffers.FlatBuffers.Offset;
import flatbuffers.json.JsonReader;
import flatbuffers.json.Value;

using flatbuffers.json.ValueExtensions;

class UnitTest {
	static function main() {
		var r:TestRunner = new TestRunner();
		r.add(new TestFlatbuffers());
		r.add(new TestJsonSupport());
		r.run();
	}
}

class TestFlatbuffers extends haxe.unit.TestCase {
	public function testConstants() {
		// Check whether the enums have been generated correctly.
		assertEquals(Monster.Color.Red, 1);
		assertEquals(Monster.Color.Green, 2);
		assertEquals(Monster.Color.Blue, 8);

		assertEquals(Monster.Race.None, -1);
		assertEquals(Monster.Race.Human, 0);
		assertEquals(Monster.Race.Dwarf, 1);
		assertEquals(Monster.Race.Elf, 2);
	}

	public function testBasic() {
		var builder:Builder = new Builder(1024);

		// Create some weapons for our Monster ('Sword' and 'Axe').
		var weaponOne:Offset = builder.createString(Right('Sword'));
		var weaponTwo:Offset = builder.createString(Right('Axe'));

		Monster.Weapon.startWeapon(builder);
		Monster.Weapon.addName(builder, weaponOne);
		Monster.Weapon.addDamage(builder, 3);

		var sword:Offset = Monster.Weapon.endWeapon(builder);

		// Create the second `Weapon` ('Axe').
		Monster.Weapon.startWeapon(builder);
		Monster.Weapon.addName(builder, weaponTwo);
		Monster.Weapon.addDamage(builder, 5);

		var axe:Offset = Monster.Weapon.endWeapon(builder);

		// Monster.addEquippedType(builder, Equipment.Weapon); // Union type
		// Monster.addEquipped(builder, axe); // Union data

		// Serialize a name for our monster, called 'Orc'.
		var name:Offset = builder.createString(Right('Orc'));

		var expectedPaths:Array<Array<Float>> = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0], [7.0, 8.0, 9.0]];

		Monster.startPathVector(builder, expectedPaths.length);
		var i = expectedPaths.length - 1;
		while (i >= 0) {
			var p = expectedPaths[i];
			Monster.Vec3.createVec3(builder, p[0], p[1], p[2]);
			i--;
		}
		var path = builder.endVector();

		// Create a `vector` representing the inventory of the Orc. Each number
		// could correspond to an item that can be claimed after he is slain.
		var treasure:Array<Int> = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]; // INV TO UP.
		var inv = Monster.createInventoryVector(builder, treasure);

		// Create an array from the two `Weapon`s and pass it to the
		// `createWeaponsVector()` method to create a FlatBuffer vector.
		var weaps:Array<Offset> = [sword, axe];
		var weapons:Offset = Monster.createWeaponsVector(builder, weaps);

		Monster.startMonster(builder);
		Monster.addMana(builder, 150);
		Monster.addHp(builder, 300);
		var pos:Offset = Monster.Vec3.createVec3(builder, 1.0, 2.0, 3.0);
		Monster.addPos(builder, pos);
		Monster.addColor(builder, Monster.Color.Red | Monster.Color.Blue);
		Monster.addName(builder, name);
		Monster.addInventory(builder, inv);
		Monster.addWeapons(builder, weapons);
		Monster.addPath(builder, path);
		// Monster.addEquippedType(builder, Equipment.Weapon);
		// Monster.addEquipped(builder, axe);

		var orc:Offset = Monster.endMonster(builder);
		Monster.finishMonsterBuffer(builder, orc);

		#if cpp
		var array = builder.asUint8Array();
		var bytes = haxe.io.Bytes.alloc(array.length);
		for (i in 0...array.length)
			bytes.set(i, array[i]);
		sys.io.File.saveBytes("test.mon", bytes);
		#end

		var buf:ByteBuffer = builder.dataBuffer();

		var monster = Monster.getRootAsMonster(buf);
		assertEquals(150, monster.mana());
		assertEquals(300, monster.hp());
		assertEquals('Orc', monster.name());
		assertEquals(Monster.Color.Red | Monster.Color.Blue, monster.color());
		assertEquals(1.0, monster.pos().x());
		assertEquals(2.0, monster.pos().y());
		assertEquals(3.0, monster.pos().z());
		// Get and test the `inventory` FlatBuffer `vector`.
		for (i in 0...monster.inventoryLength()) {
			assertEquals(i, monster.inventory(i));
		}

		// Get and test the `path` FlatBuffer `vector` of `struct`s.
		assertEquals(expectedPaths.length, monster.pathLength());
		for (i in 0...monster.pathLength()) {
			var p = monster.path(i);
			assertEquals(expectedPaths[i][0], p.x());
			assertEquals(expectedPaths[i][1], p.y());
			assertEquals(expectedPaths[i][2], p.z());
		}

		// Get and test the `weapons` FlatBuffer `vector` of `table`s.
		var expectedWeaponNames:Array<String> = ['Sword', 'Axe'];
		var expectedWeaponDamages:Array<Int> = [3, 5];
		for (i in 0...monster.weaponsLength()) {
			assertEquals(expectedWeaponNames[i], monster.weapons(i).name());
			assertEquals(expectedWeaponDamages[i], monster.weapons(i).damage());
		}

		trace('The FlatBuffer was successfully created and verified!');
	}
}

class TestJsonSupport extends haxe.unit.TestCase {
	public function testJsonReader() {
		// Test basic JSON parsing
		var jsonStr = '{"name": "test", "value": 42, "flag": true, "nested": {"x": 1.5}}';
		var reader = new JsonReader(jsonStr);

		assertEquals("test", reader.root.asObject().get("name").asString());
		assertEquals(42, reader.root.asObject().get("value").asInt());
		assertEquals(true, reader.root.asObject().get("flag").asBool());
		assertEquals(1.5, reader.root.asObject().get("nested").asObject().get("x").asFloat());
	}

	public function testEnumJsonSerialization() {
		// Test regular enum (Race)
		var human = Monster.Race.Human;
		var json = Monster.Race.__tojson(human);
		assertTrue(json.match(VString("Human")));

		var parsed = Monster.Race.__json(VString("Human"));
		assertEquals(human, parsed);

		// Test enum with integer value
		var parsed2 = Monster.Race.__json(VNumber("0"));
		assertEquals(human, parsed2);

		// Test fromStringSingle
		var dwarf = Monster.Race.fromStringSingle("Dwarf");
		assertTrue(dwarf != null);
		assertEquals(Monster.Race.Dwarf, dwarf);

		var invalid = Monster.Race.fromStringSingle("InvalidRace");
		assertTrue(invalid == null);
	}

	public function testBitflagEnumJsonSerialization() {
		// Test bitflag enum (Color)
		var red = Monster.Color.Red;
		var redJson = Monster.Color.__tojson(red);
		assertTrue(redJson.match(VString("Red")));

		var redGreen = Monster.Color.Red | Monster.Color.Green;
		var redGreenJson = Monster.Color.__tojson(redGreen);
		assertTrue(redGreenJson.match(VString(_)));

		switch (redGreenJson) {
			case VString(s):
				// Should contain both "Red" and "Green"
				assertTrue(s.indexOf("Red") >= 0);
				assertTrue(s.indexOf("Green") >= 0);
			default:
				assertTrue(false); // Should not reach here
		}

		// Test parsing space-separated flags
		var parsed = Monster.Color.__json(VString("Red Green"));
		assertEquals(redGreen, parsed);

		// Test parsing integer value
		var parsed2 = Monster.Color.__json(VNumber("9")); // Red (1) | Blue (8)
		assertEquals(Monster.Color.Red | Monster.Color.Blue, parsed2);

		// Test unknown bits - should return integer representation
		var unknownBits = new Monster.Color(15); // All bits set including unknown ones
		var unknownJson = Monster.Color.__tojson(unknownBits);
		assertTrue(unknownJson.match(VNumber("15")));
	}

	public function testCompleteJsonToFlatBuffer() {
		// Test complete JSON to FlatBuffer conversion
		var jsonStr = '{
			"pos": {"x": 1.0, "y": 2.0, "z": 3.0},
			"mana": 150,
			"hp": 300,
			"name": "JsonOrc",
			"color": "Red Blue",
			"friendly": true,
			"inventory": [0, 1, 2, 3, 4],
			"weapons": [
				{"name": "JsonSword", "damage": 10},
				{"name": "JsonAxe", "damage": 15}
			],
			"path": [
				{"x": 1.0, "y": 2.0, "z": 3.0},
				{"x": 4.0, "y": 5.0, "z": 6.0}
			]
		}';

		var reader = new JsonReader(jsonStr);
		var builder = new Builder(1024);

		// Use the generated __json method
		var offset = Monster.__json(reader.root.asObject(), builder);
		Monster.finishMonsterBuffer(builder, offset);

		var buf = builder.dataBuffer();
		var monster = Monster.getRootAsMonster(buf);

		// Verify the data
		assertEquals(150, monster.mana());
		assertEquals(300, monster.hp());
		assertEquals("JsonOrc", monster.name());
		assertEquals(true, monster.friendly());
		assertEquals(Monster.Color.Red | Monster.Color.Blue, monster.color());

		// Check position
		assertEquals(1.0, monster.pos().x());
		assertEquals(2.0, monster.pos().y());
		assertEquals(3.0, monster.pos().z());

		// Check inventory
		assertEquals(5, monster.inventoryLength());
		for (i in 0...5) {
			assertEquals(i, monster.inventory(i));
		}

		// Check weapons
		assertEquals(2, monster.weaponsLength());
		assertEquals("JsonSword", monster.weapons(0).name());
		assertEquals(10, monster.weapons(0).damage());
		assertEquals("JsonAxe", monster.weapons(1).name());
		assertEquals(15, monster.weapons(1).damage());

		// Check path
		assertEquals(2, monster.pathLength());
		assertEquals(1.0, monster.path(0).x());
		assertEquals(4.0, monster.path(1).x());
	}

	public function testJsonErrorHandling() {
		// Test invalid enum value
		try {
			Monster.Race.__json(VString("InvalidRace"));
			assertTrue(false); // Should not reach here
		} catch (e:String) {
			assertTrue(e.indexOf("Unknown enum value") >= 0);
		}

		// Test invalid JSON value type for enum
		try {
			Monster.Race.__json(VBool(true));
			assertTrue(false); // Should not reach here
		} catch (e:String) {
			assertTrue(e.indexOf("Only integer and string values are allowed") >= 0);
		}
	}
}
