package;

import haxe.unit.TestRunner;
import haxe.unit.TestCase;

import flatbuffers.FlatBuffers;
import flatbuffers.FlatBuffers.Builder;
import flatbuffers.FlatBuffers.Offset;

class UnitTest 
{
	static function main() 
	{
			var r:TestRunner = new TestRunner();
			r.add(new TestFlatbuffers());
			r.run();
	}
}

class TestFlatbuffers extends haxe.unit.TestCase 
{
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

	public function testBasic(){
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

		var expectedPaths:Array<Array<Float>> = [
			[1.0, 2.0, 3.0],
			[4.0, 5.0, 6.0],
			[7.0, 8.0, 9.0]
		];

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

		var pos:Offset = Monster.Vec3.createVec3(builder, 1.0, 2.0, 3.0);
		Monster.startMonster(builder);
		Monster.addPos(builder, pos);
		Monster.addMana(builder, 150);
		Monster.addHp(builder, 300);
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
		for(i in 0...array.length)
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
