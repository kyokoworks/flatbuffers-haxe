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
		Monster.addHp(builder, 300);
		Monster.addColor(builder, Monster.Color.Red);
		Monster.addName(builder, name);
		Monster.addInventory(builder, inv);
		Monster.addWeapons(builder, weapons);
		// Monster.addEquippedType(builder, Equipment.Weapon);
		// Monster.addEquipped(builder, axe);

		var orc:Offset = Monster.endMonster(builder);
		builder.finish(orc);
		
		var buf:ByteBuffer = builder.dataBuffer();
		
		var monster = Monster.getRootAsMonster(buf);

		assertEquals(monster.mana(), 150);
		assertEquals(monster.hp(), 300);
		assertEquals(monster.name(), 'Orc');
		assertEquals(monster.color(), Monster.Color.Red);
		assertEquals(monster.pos().x(), 1.0);
		assertEquals(monster.pos().y(), 2.0);
		assertEquals(monster.pos().z(), 3.0);

		// Get and test the `inventory` FlatBuffer `vector`.
		for (i in 0...monster.inventoryLength()) {
			assertEquals(monster.inventory(i), i);
		}

		// Get and test the `weapons` FlatBuffer `vector` of `table`s.
		var expectedWeaponNames:Array<String> = ['Sword', 'Axe'];
		var expectedWeaponDamages:Array<Int> = [3, 5];
		for (i in 0...monster.weaponsLength()) {
			assertEquals(monster.weapons(i).name(), expectedWeaponNames[i]);
			assertEquals(monster.weapons(i).damage(), expectedWeaponDamages[i]);
		}

		trace('The FlatBuffer was successfully created and verified!');
	}
}
