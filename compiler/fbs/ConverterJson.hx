package fbs;

import fbs.Ast;
import fbs.Parser;
import fbs.Converter;
import haxe.macro.Expr;

class CoverterJson {
	static var nullPos:Position = {min: 0, max: 0, file: ""};

	static var typeStringMapValue = makeType("haxe.ds.StringMap<Value>");
	static var typeJsonValue = makeType("Value");
	static var typeInt = makeType('Int');

	public static inline function getJsonImports() {
		return
			'\nimport flatbuffers.json.Value;\nimport flatbuffers.json.ValueExtensions;\nusing flatbuffers.json.ValueExtensions;\nimport haxe.ds.StringMap;\n';
	}

	static inline function capitalizeFieldName(fieldName:String):String {
		return fieldName.charAt(0).toUpperCase() + fieldName.substr(1);
	}

	public static inline function makeStructJsonMethods(structObj:FbsStruct, converter:Converter):Array<Field> {
		var className = structObj.name;
		var fields = structObj.fields;

		// Generate expressions for the __json method body
		var expressions:Array<Expr> = [];

		// Collect field values from JSON object
		var fieldArgs:Array<Expr> = [];
		for (field in fields) {
			var fieldName = field.name;
			var varName = 'val_${fieldName}';

			// Get the field value from JSON object
			expressions.push(makeExpr(makeVar(varName, null, makeExpr(ECall(makeExpr(EField(makeIdent('obj'), 'get')), [makeString(fieldName)])))));

			// Convert the field value to appropriate type and add to arguments
			var convertExpr = generateFieldConversion(field.type, false, varName, converter);
			if (convertExpr != null) {
				fieldArgs.push(convertExpr);
			} else {
				// For primitive types that don't need conversion
				fieldArgs.push(makeIdent(varName));
			}
		}

		// For structs, we use the create* method directly with all field values
		// return ClassName.createClassName(builder, field1, field2, ...)
		expressions.push(makeExpr(EReturn(makeExpr(ECall(makeIdent('${className}.create${className}'), [makeIdent('builder')].concat(fieldArgs))))));

		var converterField = {
			name: "__json",
			kind: FFun({
				args: [
					makeFuncArg("obj", typeStringMapValue),
					makeFuncArg("builder", makeType("Builder"))
				],
				ret: makeType("Offset"),
				expr: makeExpr(EBlock(expressions)),
				params: null
			}),
			doc: null,
			meta: [],
			access: [APublic, AStatic],
			pos: nullPos
		};

		// Generate __tojson method
		var toJsonField = makeStructToJsonMethod(structObj, converter);

		return [converterField, toJsonField];
	}

	public static inline function makeTableJsonMethods(tableObj:FbsTable, converter:Converter):Array<Field> {
		var className = tableObj.name;
		var fields = tableObj.fields;

		// Generate expressions for the __json method body
		var expressions:Array<Expr> = [];

		// Pre-serialize non-inline fields (strings, vectors, nested objects)
		for (field in fields) {
			var fieldName = field.name;
			var varName = 'val_${fieldName}';
			var offsetName = 'off_${fieldName}';

			// Get the field value from JSON object
			expressions.push(makeExpr(makeVar(varName, null, makeExpr(ECall(makeExpr(EField(makeIdent('obj'), 'get')), [makeString(fieldName)])))));

			if (needsOffset(field.type, field.isVector, converter)) {
				// Initialize offset variable
				expressions.push(makeExpr(makeVar(offsetName, makeType('Offset'), makeInt('0'))));
			}

			// Generate serialization code based on field type
			var serializeExpr = generateFieldSerialization(field.type, field.isVector, field.name, varName, offsetName, converter, className);
			if (serializeExpr != null) {
				expressions.push(serializeExpr);
			}
		}

		// Start building the table
		expressions.push(makeExpr(ECall(makeIdent('${className}.start${className}'), [makeIdent('builder')])));

		// Add fields to the table
		for (i in 0...fields.length) {
			var field = fields[i];
			var fieldName = field.name;
			var varName = 'val_${fieldName}';
			var offsetName = 'off_${fieldName}';
			var capitalizedFieldName = capitalizeFieldName(fieldName);

			if (needsOffset(field.type, field.isVector, converter)) {
				expressions.push(makeExpr(EIf(makeExpr(EBinop(OpNotEq, makeIdent(offsetName), makeInt('0'))),
					makeExpr(ECall(makeIdent('${className}.add${capitalizedFieldName}'), [makeIdent('builder'), makeIdent(offsetName)])), null)));
			} else {
				var convertExpr = generateFieldConversion(field.type, field.isVector, varName, converter);
				if (convertExpr != null) {
					expressions.push(makeExpr(EIf(makeExpr(EBinop(OpNotEq, makeIdent(varName), makeIdent('null'))),
						makeExpr(ECall(makeIdent('${className}.add${capitalizedFieldName}'), [makeIdent('builder'), convertExpr])), null)));
				}
			}
		}

		// End and return the table
		expressions.push(makeExpr(EReturn(makeExpr(ECall(makeIdent('${className}.end${className}'), [makeIdent('builder')])))));

		var converterField = {
			name: "__json",
			kind: FFun({
				args: [
					makeFuncArg("obj", typeStringMapValue),
					makeFuncArg("builder", makeType("Builder"))
				],
				ret: makeType("Offset"),
				expr: makeExpr(EBlock(expressions)),
				params: null
			}),
			doc: null,
			meta: [],
			access: [APublic, AStatic],
			pos: nullPos
		};

		// Generate __tojson method
		var toJsonField = makeTableToJsonMethod(tableObj, converter);

		return [converterField, toJsonField];
	}

	public static inline function makeEnumMethods(enumObj:FbsEnum, converter:Converter, isBitFlags:Bool):Array<Field> {
		var enumName = enumObj.name;
		var ctors = enumObj.ctors;

		// Generate fromStringSingle method
		var fromStringCases:Array<Case> = [];
		for (ctor in ctors) {
			var ctorName = ctor.name.getParameters()[0];
			fromStringCases.push({
				values: [makeExpr(EConst(CString(ctorName)))],
				expr: makeExpr(EReturn(makeIdent(ctorName))),
				guard: null
			});
		}
		var caseDefault:Expr = makeExpr(EReturn(makeIdent("null")));

		var fromStringField:Field = {
			name: 'fromStringSingle',
			kind: FFun({
				args: [makeFuncArg('s', makeType('String'))],
				ret: makeType('Null', null, [TPType(makeType(enumName))]),
				expr: makeExpr(ESwitch(makeIdent('s'), fromStringCases, caseDefault)),
				params: null
			}),
			doc: null,
			meta: [],
			access: [APublic, AStatic],
			pos: nullPos
		};

		// Generate __tojson method
		var toJsonField:Field;
		if (isBitFlags) {
			// For bitflags: generate allFlags calculation and flag checking
			var allFlagsExpr = null;
			for (i in 0...ctors.length) {
				var ctorName = ctors[i].name.getParameters()[0];
				var ctorExpr = makeIdent(ctorName);
				if (allFlagsExpr == null) {
					allFlagsExpr = ctorExpr;
				} else {
					allFlagsExpr = makeExpr(EBinop(OpOr, allFlagsExpr, ctorExpr));
				}
			}

			var flagChecks:Array<Expr> = [];
			for (ctor in ctors) {
				var ctorName = ctor.name.getParameters()[0];

				flagChecks.push(makeExpr(EIf( //
					makeExpr(EBinop(OpNotEq, // (e & x) != 0
						makeExpr(EParenthesis(makeExpr(EBinop(OpAnd, makeIdent('e'), makeIdent(ctorName))))), //
						makeInt('0'))), //
					makeExpr(ECall(makeExpr(EField(makeIdent('flags'), 'push')), [makeString(ctorName)])), //
					null //
				)));
			}

			// (e & ~allFlags) != 0
			var anyFlagSetExpr = makeExpr(EBinop(OpNotEq, //
				makeExpr(EParenthesis(makeExpr(EBinop(OpAnd, //
					makeIdent('e'), //
					makeExpr(EUnop(OpNegBits, false, makeIdent('allFlags'))))))), //
				makeInt('0')));

			// Std.string(e)
			var eToString = makeExpr(ECall(makeIdent('Std.string'), [makeIdent('e')]));

			toJsonField = {
				name: '__tojson',
				kind: FFun({
					args: [makeFuncArg('e', makeType(enumName))],
					ret: typeJsonValue,
					expr: makeExpr(EBlock([
						makeExpr(makeVar('allFlags', typeInt, allFlagsExpr)), // var allFlags:Int = ...
						makeExpr(EIf(anyFlagSetExpr, makeExpr(EReturn(makeExpr(ECall(makeIdent('VNumber'), [eToString])))), null)),
						makeExpr(makeVar('flags', makeType('Array', null, [TPType(makeType('String'))]), makeExpr(EArrayDecl([])))),
						makeExpr(EBlock(flagChecks)),
						makeExpr(makeVar('finalStr', null, makeExpr(ECall(makeExpr(EField(makeIdent('flags'), 'join')), [makeString(' ')])))),
						makeExpr(EReturn(makeExpr(ECall(makeIdent('VString'), [makeIdent('finalStr')]))))
					])),
					params: null
				}),
				doc: null,
				meta: [],
				access: [APublic, AStatic],
				pos: nullPos
			};
		} else {
			// For regular enums: simple switch statement
			var toJsonCases:Array<Case> = [];
			for (ctor in ctors) {
				var ctorName = ctor.name.getParameters()[0];
				toJsonCases.push({
					values: [makeIdent(ctorName)],
					expr: makeExpr(EReturn(makeExpr(ECall(makeIdent('VString'), [makeString(ctorName)])))),
					guard: null
				});
			}

			// return VNumber(Std.string(cast (e, Int)));
			var caseDefaultToJson:Expr = makeExpr(EReturn(makeExpr(ECall(makeIdent('VNumber'), [
				makeExpr(ECall(makeIdent('Std.string'), [
					makeExpr(ECast( //
						makeIdent('e'), //
						typeInt, //
					))
				]))
			]))));

			toJsonField = {
				name: '__tojson',
				kind: FFun({
					args: [makeFuncArg('e', makeType(enumName))],
					ret: typeJsonValue,
					expr: makeExpr(ESwitch(makeIdent('e'), toJsonCases, caseDefaultToJson)),
					params: null
				}),
				doc: null,
				meta: [],
				access: [APublic, AStatic],
				pos: nullPos
			};
		}

		// Generate __json method
		var jsonCases:Array<Case> = [
			{
				values: [makeExpr(ECall(makeIdent('VNumber'), [makeIdent('i')]))],
				expr: makeExpr(EReturn(makeExpr(ECall(makeExpr(EConst(CIdent('new ${enumName}'))),
					[makeExpr(ECall(makeIdent('Std.parseInt'), [makeIdent('i')]))])))),
				guard: null
			}
		];

		if (isBitFlags) {
			var partIdent = makeIdent('part');
			var partsIdent = makeIdent('parts');

			// var e = fromStringSingle(part);

			// (part in parts)
			var forExpr = makeExpr(EBinop(OpIn, partIdent, partsIdent));

			// For bitflags: parse space-separated string
			jsonCases.push({
				values: [makeExpr(ECall(makeIdent('VString'), [makeIdent('s')]))],
				expr: makeExpr(EBlock([
					makeExpr(makeVar('parts', null, makeExpr(ECall(makeExpr(EField(makeIdent('s'), 'split')), [makeString(' ')])))),
					makeExpr(makeVar('result', null, makeInt('0'))),
					makeExpr(EFor(forExpr, makeExpr(EBlock([
						makeExpr(makeVar('e', null, makeExpr(ECall(makeIdent('fromStringSingle'), [partIdent])))),
						makeExpr(EIf(makeExpr(EBinop(OpEq, makeIdent('e'), makeIdent('null'))),
							makeExpr(EThrow(makeExpr(EBinop(OpAdd, makeString('Unknown enum value: '), partIdent)))), null)),
						makeExpr(EBinop(OpAssignOp(OpOr), makeIdent('result'), makeIdent('e')))
					])))),
					makeExpr(EReturn(makeExpr(ECall(makeExpr(EConst(CIdent('new ${enumName}'))), [makeIdent('result')]))))
				])),
				guard: null
			});
		} else {
			// For regular enums: simple string lookup
			jsonCases.push({
				values: [makeExpr(ECall(makeIdent('VString'), [makeIdent('s')]))],
				expr: makeExpr(EBlock([
					makeExpr(makeVar('e', null, makeExpr(ECall(makeIdent('fromStringSingle'), [makeIdent('s')])))),
					makeExpr(EIf(makeExpr(EBinop(OpEq, makeIdent('e'), makeIdent('null'))),
						makeExpr(EThrow(makeExpr(EBinop(OpAdd, makeString('Unknown enum value: '), makeIdent('s'))))), null)),
					makeExpr(EReturn(makeIdent('e')))
				])),
				guard: null
			});
		}

		var caseDefault:Expr = makeExpr(EThrow(makeString('Only integer and string values are allowed for enum ${enumName}')));

		var jsonField:Field = {
			name: '__json',
			kind: FFun({
				args: [makeFuncArg('val', typeJsonValue)],
				ret: makeType(enumName),
				expr: makeExpr(ESwitch(makeIdent('val'), jsonCases, caseDefault)),
				params: null
			}),
			doc: null,
			meta: [],
			access: [APublic, AStatic],
			pos: nullPos
		};

		return [fromStringField, toJsonField, jsonField];
	}

	static function generateFieldSerialization(fieldType:FbsType, isVector:Bool, fieldName:String, varName:String, offsetName:String, converter:Converter,
			parentClassName:String):Null<Expr> {
		// reusable names and idents to avoid repeating string/ident construction in the AST
		var arrName = 'arr_${fieldName}';
		var offsetsName = 'offs_${fieldName}';
		var arrIdent = makeIdent(arrName);
		var offsetsIdent = makeIdent(offsetsName);
		var capName = capitalizeFieldName(fieldName);
		var startVecIdent = makeIdent('${parentClassName}.start${capName}Vector');
		var createVecIdent = makeIdent('${parentClassName}.create${capName}Vector');

		switch (fieldType) {
			case TPrimitive(TString):
				return serializeStringField(varName, offsetName, arrName, arrIdent, startVecIdent, isVector, parentClassName, fieldName);

			case TPrimitive(_):
				if (isVector) {
					var primitiveType = getPrimitiveTypeName(fieldType.getParameters()[0]);
					return serializePrimitiveVector(fieldType, varName, offsetName, arrName, arrIdent, startVecIdent, primitiveType, parentClassName,
						fieldName);
				}
				return null; // Primitive scalars don't need pre-serialization

			case TComposite(typeName):
				// Check if it's an enum, struct, or table
				var decl = converter.currentModule.declTypeRef[typeName];
				switch (decl) {
					case DEnum(_):
						return null; // Enums don't need pre-serialization
					case DStruct(_):
						// Structs are serialized inline, only vector structs need pre-serialization
						if (isVector) {
							return serializeStructField(typeName, varName, offsetName, arrName, arrIdent, startVecIdent, isVector, parentClassName, fieldName);
						}
						return null; // Single structs are serialized inline
					case DTable(_):
						return serializeTableField(typeName, varName, offsetName, arrName, arrIdent, offsetsName, offsetsIdent, createVecIdent, isVector,
							parentClassName, fieldName);
					default:
						return null;
				}
		}
	}

	static function serializeStringField(varName:String, offsetName:String, arrName:String, arrIdent:Expr, startVecIdent:Expr, isVector:Bool,
			parentClassName:String, fieldName:String):Expr {
		if (isVector) {
			// if (varName != null)
			var conditionExpr = makeExpr(EBinop(OpNotEq, makeIdent(varName), makeIdent('null')));

			// var arr_fieldName = varName.asArray();
			var declareArrExpr = makeExpr(makeVar(arrName, null, makeExpr(ECall(makeExpr(EField(makeIdent(varName), 'asArray')), []))));

			// FieldName.startFieldNameVector(builder, arr_fieldName.length)
			var startVectorExpr = makeExpr(ECall(startVecIdent, [makeIdent('builder'), makeExpr(EField(arrIdent, 'length'))]));

			// var i = arr_fieldName.length - 1
			var initIterExpr = makeExpr(makeVar('i', typeInt, makeExpr(EBinop(OpSub, makeExpr(EField(arrIdent, 'length')), makeInt('1')))));

			// builder.addOffset(builder.createString(arr_fieldName[i].asString()))
			var addStringExpr = makeExpr(ECall(makeIdent('builder.addOffset'), [
				makeExpr(ECall(makeIdent('builder.createString'), [
					makeExpr(ECall(makeIdent('Right'), [
						makeExpr(ECall(makeExpr(EField(makeExpr(EArray(arrIdent, makeIdent('i'))), 'asString')), []))
					]))
				]))
			]));

			// i--
			var decrementExpr = makeExpr(EUnop(OpDecrement, false, makeIdent('i')));

			// while (i >= 0) { addStringExpr; decrementExpr; }
			var whileBodyExpr = makeExpr(EBlock([addStringExpr, decrementExpr]));
			var whileExpr = makeExpr(EWhile(makeExpr(EBinop(OpGte, makeIdent('i'), makeInt('0'))), whileBodyExpr, false));

			// offsetName = builder.endVector()
			var assignOffsetExpr = makeExpr(EBinop(OpAssign, makeIdent(offsetName), makeExpr(ECall(makeIdent('builder.endVector'), []))));

			var blockExpr = makeExpr(EBlock([declareArrExpr, startVectorExpr, initIterExpr, whileExpr, assignOffsetExpr]));
			return makeExpr(EIf(conditionExpr, blockExpr, null));
		} else {
			// if (varName != null) offsetName = builder.createString(Right(varName.asString()))
			var conditionExpr = makeExpr(EBinop(OpNotEq, makeIdent(varName), makeIdent('null')));
			var createStringExpr = makeExpr(ECall(makeIdent('builder.createString'), [
				makeExpr(ECall(makeIdent('Right'), [
					// varName.asString()
					makeExpr(ECall(makeExpr(EField(makeIdent(varName), 'asString')), []))
				]))
			]));
			var assignExpr = makeExpr(EBinop(OpAssign, makeIdent(offsetName), createStringExpr));
			return makeExpr(EIf(conditionExpr, assignExpr, null));
		}
	}

	static function serializePrimitiveVector(fieldType:FbsType, varName:String, offsetName:String, arrName:String, arrIdent:Expr, startVecIdent:Expr,
			primitiveType:String, parentClassName:String, fieldName:String):Expr {
		// For primitive vectors, we use the createFieldNameVector method directly
		// if (varName != null)
		var conditionExpr = makeExpr(EBinop(OpNotEq, makeIdent(varName), makeIdent('null')));

		// var arr_fieldName = varName.asArray()
		var declareArrExpr = makeExpr(makeVar(arrName, null, makeExpr(ECall(makeExpr(EField(makeIdent(varName), 'asArray')), []))));

		// Convert JSON array to native array of appropriate type
		var nativeArrName = 'native_${arrName}';
		var nativeArrIdent = makeIdent(nativeArrName);
		var declareNativeArrExpr = makeExpr(makeVar(nativeArrName, makeType('Array<${getPrimitiveHaxeTypeName(fieldType.getParameters()[0])}>', null),
			makeExpr(EArrayDecl([]))));

		// var i = 0
		var initIterExpr = makeExpr(makeVar('i', typeInt, makeInt('0')));

		// native_arr_fieldName.push(valueConversion(arr_fieldName[i]))
		var pushValueExpr = makeExpr(ECall(makeExpr(EField(nativeArrIdent, 'push')), [
			getValueConversion(fieldType.getParameters()[0], makeExpr(EArray(arrIdent, makeIdent('i'))))
		]));

		// i++
		var incrementExpr = makeExpr(EUnop(OpIncrement, false, makeIdent('i')));

		// while (i < arr_fieldName.length) { pushValueExpr; incrementExpr; }
		var whileBodyExpr = makeExpr(EBlock([pushValueExpr, incrementExpr]));
		var whileExpr = makeExpr(EWhile(makeExpr(EBinop(OpLt, makeIdent('i'), makeExpr(EField(arrIdent, 'length')))), whileBodyExpr, false));

		// Use field name directly and create the proper method call
		var capFieldName = capitalizeFieldName(fieldName);
		var createVectorMethodName = '${parentClassName}.create${capFieldName}Vector';

		// offsetName = ParentClass.createFieldNameVector(builder, native_arr_fieldName)
		var assignOffsetExpr = makeExpr(EBinop(OpAssign, makeIdent(offsetName),
			makeExpr(ECall(makeIdent(createVectorMethodName), [makeIdent('builder'), nativeArrIdent]))));

		var blockExpr = makeExpr(EBlock([declareArrExpr, declareNativeArrExpr, initIterExpr, whileExpr, assignOffsetExpr]));
		return makeExpr(EIf(conditionExpr, blockExpr, null));
	}

	static function serializeStructField(typeName:String, varName:String, offsetName:String, arrName:String, arrIdent:Expr, startVecIdent:Expr, isVector:Bool,
			parentClassName:String, fieldName:String):Expr {
		// if (varName != null)
		var conditionExpr = makeExpr(EBinop(OpNotEq, makeIdent(varName), makeIdent('null')));

		if (isVector) {
			// var arr_fieldName = varName.asArray()
			var declareArrExpr = makeExpr(makeVar(arrName, null, makeExpr(ECall(makeExpr(EField(makeIdent(varName), 'asArray')), []))));

			// ParentClass.startFieldNameVector(builder, arr_fieldName.length)
			var startVectorExpr = makeExpr(ECall(startVecIdent, [makeIdent('builder'), makeExpr(EField(arrIdent, 'length'))]));

			// var i = arr_fieldName.length - 1
			var initIterExpr = makeExpr(makeVar('i', typeInt, makeExpr(EBinop(OpSub, makeExpr(EField(arrIdent, 'length')), makeInt('1')))));

			// TypeName.__json(arr_fieldName[i].asObject(), builder)
			var callJsonExpr = makeExpr(ECall(makeIdent('${typeName}.__json'), [
				makeExpr(ECall(makeExpr(EField(makeExpr(EArray(arrIdent, makeIdent('i'))), 'asObject')), [])),
				makeIdent('builder')
			]));

			// i--
			var decrementExpr = makeExpr(EUnop(OpDecrement, false, makeIdent('i')));

			// while (i >= 0) { callJsonExpr; decrementExpr; }
			var whileBodyExpr = makeExpr(EBlock([callJsonExpr, decrementExpr]));
			var whileExpr = makeExpr(EWhile(makeExpr(EBinop(OpGte, makeIdent('i'), makeInt('0'))), whileBodyExpr, false));

			// offsetName = builder.endVector()
			var assignOffsetExpr = makeExpr(EBinop(OpAssign, makeIdent(offsetName), makeExpr(ECall(makeIdent('builder.endVector'), []))));

			var blockExpr = makeExpr(EBlock([declareArrExpr, startVectorExpr, initIterExpr, whileExpr, assignOffsetExpr]));
			return makeExpr(EIf(conditionExpr, blockExpr, null));
		} else {
			// offsetName = TypeName.__json(varName.asObject(), builder)
			var callJsonExpr = makeExpr(ECall(makeIdent('${typeName}.__json'), [
				makeExpr(ECall(makeExpr(EField(makeIdent(varName), 'asObject')), [])),
				makeIdent('builder')
			]));
			var assignExpr = makeExpr(EBinop(OpAssign, makeIdent(offsetName), callJsonExpr));
			return makeExpr(EIf(conditionExpr, assignExpr, null));
		}
	}

	static function serializeTableField(typeName:String, varName:String, offsetName:String, arrName:String, arrIdent:Expr, offsetsName:String,
			offsetsIdent:Expr, createVecIdent:Expr, isVector:Bool, parentClassName:String, fieldName:String):Expr {
		// if (varName != null)
		var conditionExpr = makeExpr(EBinop(OpNotEq, makeIdent(varName), makeIdent('null')));

		if (isVector) {
			// var arr_fieldName = varName.asArray()
			var declareArrExpr = makeExpr(makeVar(arrName, null, makeExpr(ECall(makeExpr(EField(makeIdent(varName), 'asArray')), []))));

			// var offsets_fieldName = []
			var declareOffsetsExpr = makeExpr(makeVar(offsetsName, makeType('Array<Offset>'), makeExpr(EArrayDecl([]))));

			// var i = 0
			var initIterExpr = makeExpr(makeVar('i', typeInt, makeInt('0')));

			// offsets_fieldName.push(TypeName.__json(arr_fieldName[i].asObject(), builder))
			var pushOffsetExpr = makeExpr(ECall(makeExpr(EField(offsetsIdent, 'push')), [
				makeExpr(ECall(makeIdent('${typeName}.__json'), [
					makeExpr(ECall(makeExpr(EField(makeExpr(EArray(arrIdent, makeIdent('i'))), 'asObject')), [])),
					makeIdent('builder')
				]))
			]));

			// i++
			var incrementExpr = makeExpr(EUnop(OpIncrement, false, makeIdent('i')));

			// while (i < arr_fieldName.length) { pushOffsetExpr; incrementExpr; }
			var whileBodyExpr = makeExpr(EBlock([pushOffsetExpr, incrementExpr]));
			var whileExpr = makeExpr(EWhile(makeExpr(EBinop(OpLt, makeIdent('i'), makeExpr(EField(arrIdent, 'length')))), whileBodyExpr, false));

			// Use field name directly and create the proper method call
			var capFieldName = capitalizeFieldName(fieldName);
			var createVectorMethodName = '${parentClassName}.create${capFieldName}Vector';

			// offsetName = ParentClass.createFieldNameVector(builder, offsets_fieldName)
			var assignOffsetExpr = makeExpr(EBinop(OpAssign, makeIdent(offsetName),
				makeExpr(ECall(makeIdent(createVectorMethodName), [makeIdent('builder'), offsetsIdent]))));

			var blockExpr = makeExpr(EBlock([declareArrExpr, declareOffsetsExpr, initIterExpr, whileExpr, assignOffsetExpr]));
			return makeExpr(EIf(conditionExpr, blockExpr, null));
		} else {
			// offsetName = TypeName.__json(varName.asObject(), builder)
			var callJsonExpr = makeExpr(ECall(makeIdent('${typeName}.__json'), [
				makeExpr(ECall(makeExpr(EField(makeIdent(varName), 'asObject')), [])),
				makeIdent('builder')
			]));
			var assignExpr = makeExpr(EBinop(OpAssign, makeIdent(offsetName), callJsonExpr));
			return makeExpr(EIf(conditionExpr, assignExpr, null));
		}
	}

	static function generateFieldConversion(fieldType:FbsType, isVector:Bool, varName:String, converter:Converter):Null<Expr> {
		if (isVector)
			return null; // Vectors are handled in pre-serialization

		switch (fieldType) {
			case TPrimitive(primType):
				if (primType == TString)
					return null; // Strings are handled in pre-serialization
				return getValueConversion(primType, makeIdent(varName));

			case TComposite(typeName):
				var decl = converter.currentModule.declTypeRef[typeName];
				switch (decl) {
					case DEnum(enumObj):
						return makeExpr(ECall(makeIdent('${typeName}.__json'), [makeIdent(varName)]));
					case DStruct(_):
						// Structs are created inline
						return makeExpr(ECall(makeIdent('${typeName}.__json'), [
							makeExpr(ECall(makeExpr(EField(makeIdent(varName), 'asObject')), [])),
							makeIdent('builder')
						]));
					default:
						return null; // Tables are handled in pre-serialization
				}
		}
	}

	static function needsOffset(fieldType:FbsType, isVector:Bool, converter:Converter):Bool {
		if (isVector)
			return true; // All vectors need offsets

		switch (fieldType) {
			case TPrimitive(TString):
				return true;
			case TComposite(typeName):
				// Check what type of composite it is
				var decl = converter.currentModule.declTypeRef[typeName];
				switch (decl) {
					case DEnum(_):
						return false; // Enums don't need offsets
					case DStruct(_):
						return false; // Structs are serialized inline, no offset needed
					case DTable(_):
						return true; // Tables need offsets
					default:
						return false;
				}
			default:
				return false;
		}
	}

	static function getPrimitiveHaxeTypeName(primType:FbsPrimitiveType):String {
		return switch (primType) {
			case TBool: "Bool";
			case TByte | TUByte | TShort | TUShort | TInt | TUInt: "Int";
			case TLong | TULong: "haxe.Int64";
			case TFloat | TDouble: "Float";
			case TString: "String";
		};
	}

	static function getPrimitiveTypeName(primType:FbsPrimitiveType):String {
		return switch (primType) {
			case TBool: "Int8";
			case TByte: "Int8";
			case TUByte: "Int8";
			case TShort: "Int16";
			case TUShort: "Int16";
			case TInt: "Int32";
			case TUInt: "Int32";
			case TFloat: "Float32";
			case TLong: "Int64";
			case TULong: "Int64";
			case TDouble: "Float64";
			case TString: "String";
		};
	}

	static function getValueConversion(primType:FbsPrimitiveType, valueExpr:Expr):Expr {
		return switch (primType) {
			case TBool: makeExpr(ECall(makeExpr(EField(valueExpr, 'asBool')), []));
			case TByte | TUByte | TShort | TUShort | TInt | TUInt:
				makeExpr(ECall(makeExpr(EField(valueExpr, 'asInt')), []));
			case TLong | TULong:
				// For 64-bit integers, we might need special handling
				makeExpr(ECall(makeExpr(EField(valueExpr, 'asInt64')), []));
			case TFloat | TDouble:
				makeExpr(ECall(makeExpr(EField(valueExpr, 'asFloat')), []));
			case TString:
				makeExpr(ECall(makeExpr(EField(valueExpr, 'asString')), []));
		};
	}

	static function makeStructToJsonMethod(structObj:FbsStruct, converter:Converter):Field {
		var className = structObj.name;
		var fields = structObj.fields;

		// Generate expressions to build the StringMap
		var expressions:Array<Expr> = [];

		// var map = new haxe.ds.StringMap<Value>()
		expressions.push(makeExpr(makeVar('map', null, makeExpr(ENew(typeStringMapValue.getParameters()[0], [])))));

		// For each field, add to the map: map.set("fieldName", valueExpression)
		for (field in fields) {
			var fieldName = field.name;
			var fieldAccessExpr = makeExpr(ECall(makeExpr(EField(makeIdent('obj'), fieldName)), []));
			var valueExpr = generateFieldToJsonConversion(field.type, false, fieldAccessExpr, converter);

			expressions.push(makeExpr(ECall(makeExpr(EField(makeIdent('map'), 'set')), [makeString(fieldName), valueExpr])));
		}

		// return VObject(map)
		expressions.push(makeExpr(EReturn(makeExpr(ECall(makeIdent('VObject'), [makeIdent('map')])))));

		return {
			name: '__tojson',
			kind: FFun({
				args: [makeFuncArg('obj', makeType(className))],
				ret: typeJsonValue,
				expr: makeExpr(EBlock(expressions)),
				params: null
			}),
			doc: null,
			meta: [],
			access: [APublic, AStatic],
			pos: nullPos
		};
	}

	static function makeTableToJsonMethod(tableObj:FbsTable, converter:Converter):Field {
		var className = tableObj.name;
		var fields = tableObj.fields;

		// Generate expressions to build the StringMap
		var expressions:Array<Expr> = [];

		// var map = new haxe.ds.StringMap<Value>()
		expressions.push(makeExpr(makeVar('map', null, makeExpr(ENew(typeStringMapValue.getParameters()[0], [])))));

		// For each field, add to the map with null checking for nullable fields
		for (field in fields) {
			var fieldName = field.name;
			var fieldAccessExpr = makeExpr(ECall(makeExpr(EField(makeIdent('obj'), fieldName)), []));

			if (field.isVector) {
				// For vector fields, check if not null and convert each element
				var lengthCheckExpr = makeExpr(EBinop(OpGt, makeExpr(ECall(makeExpr(EField(makeIdent('obj'), fieldName + 'Length')), [])), makeInt('0')));

				var vectorConversionExpr = generateVectorToJsonConversion(field.type, fieldName, converter);

				expressions.push(makeExpr(EIf(lengthCheckExpr,
					makeExpr(ECall(makeExpr(EField(makeIdent('map'), 'set')), [makeString(fieldName), vectorConversionExpr])), null)));
			} else {
				// For non-vector fields
				switch (field.type) {
					case TPrimitive(TString):
						// String fields are nullable, check for null
						expressions.push(makeExpr(EIf(makeExpr(EBinop(OpNotEq, fieldAccessExpr, makeIdent('null'))),
							makeExpr(ECall(makeExpr(EField(makeIdent('map'), 'set')), [
								makeString(fieldName),
								generateFieldToJsonConversion(field.type, false, fieldAccessExpr, converter)
							])), null)));
					case TComposite(typeName):
						// Check if it's nullable (structs in tables can be null)
						var decl = converter.currentModule.declTypeRef[typeName];
						switch (decl) {
							case DStruct(_):
								// Struct fields in tables can be null
								expressions.push(makeExpr(EIf(makeExpr(EBinop(OpNotEq, fieldAccessExpr, makeIdent('null'))),
									makeExpr(ECall(makeExpr(EField(makeIdent('map'), 'set')), [
										makeString(fieldName),
										generateFieldToJsonConversion(field.type, false, fieldAccessExpr, converter)
									])), null)));
							case DTable(_):
								// Table fields can be null
								expressions.push(makeExpr(EIf(makeExpr(EBinop(OpNotEq, fieldAccessExpr, makeIdent('null'))),
									makeExpr(ECall(makeExpr(EField(makeIdent('map'), 'set')), [
										makeString(fieldName),
										generateFieldToJsonConversion(field.type, false, fieldAccessExpr, converter)
									])), null)));
							case DEnum(_):
								// Enums are not nullable, always add
								expressions.push(makeExpr(ECall(makeExpr(EField(makeIdent('map'), 'set')), [
									makeString(fieldName),
									generateFieldToJsonConversion(field.type, false, fieldAccessExpr, converter)
								])));
							default:
								// Default case, assume non-nullable
								expressions.push(makeExpr(ECall(makeExpr(EField(makeIdent('map'), 'set')), [
									makeString(fieldName),
									generateFieldToJsonConversion(field.type, false, fieldAccessExpr, converter)
								])));
						}
					default:
						// Primitive types (except string) are not nullable, always add
						expressions.push(makeExpr(ECall(makeExpr(EField(makeIdent('map'), 'set')), [
							makeString(fieldName),
							generateFieldToJsonConversion(field.type, false, fieldAccessExpr, converter)
						])));
				}
			}
		}

		// return VObject(map)
		expressions.push(makeExpr(EReturn(makeExpr(ECall(makeIdent('VObject'), [makeIdent('map')])))));

		return {
			name: '__tojson',
			kind: FFun({
				args: [makeFuncArg('obj', makeType(className))],
				ret: typeJsonValue,
				expr: makeExpr(EBlock(expressions)),
				params: null
			}),
			doc: null,
			meta: [],
			access: [APublic, AStatic],
			pos: nullPos
		};
	}

	static function generateFieldToJsonConversion(fieldType:FbsType, isVector:Bool, fieldExpr:Expr, converter:Converter):Expr {
		switch (fieldType) {
			case TPrimitive(primType):
				return switch (primType) {
					case TBool: makeExpr(ECall(makeIdent('VBool'), [fieldExpr]));
					case TByte | TUByte | TShort | TUShort | TInt | TUInt:
						makeExpr(ECall(makeIdent('VNumber'), [makeExpr(ECall(makeIdent('Std.string'), [fieldExpr]))]));
					case TLong | TULong:
						makeExpr(ECall(makeIdent('VNumber'), [makeExpr(ECall(makeIdent('Std.string'), [fieldExpr]))]));
					case TFloat | TDouble:
						makeExpr(ECall(makeIdent('VNumber'), [makeExpr(ECall(makeIdent('Std.string'), [fieldExpr]))]));
					case TString:
						makeExpr(ECall(makeIdent('VString'), [fieldExpr]));
				};
			case TComposite(typeName):
				var decl = converter.currentModule.declTypeRef[typeName];
				switch (decl) {
					case DEnum(_):
						// Call EnumType.__tojson(fieldExpr)
						return makeExpr(ECall(makeIdent('${typeName}.__tojson'), [fieldExpr]));
					case DStruct(_) | DTable(_):
						// Call StructType.__tojson(fieldExpr)
						return makeExpr(ECall(makeIdent('${typeName}.__tojson'), [fieldExpr]));
					default:
						return makeExpr(ECall(makeIdent('VString'), [makeExpr(ECall(makeIdent('Std.string'), [fieldExpr]))]));
				}
		}
	}

	static function generateVectorToJsonConversion(fieldType:FbsType, fieldName:String, converter:Converter):Expr {
		// var arr = []
		// var i = 0
		// while (i < obj.fieldNameLength()) {
		//   arr.push(convertElement(obj.fieldName(i)))
		//   i++
		// }
		// VArray(arr)

		var expressions:Array<Expr> = [];

		// var arr = []
		expressions.push(makeExpr(makeVar('arr', makeType('Array', null, [TPType(typeJsonValue)]), makeExpr(EArrayDecl([])))));

		// var i = 0
		expressions.push(makeExpr(makeVar('i', typeInt, makeInt('0'))));

		// Get element at index i
		var getElementExpr = makeExpr(ECall(makeExpr(EField(makeIdent('obj'), fieldName)), [makeIdent('i')]));
		var convertedElementExpr = generateFieldToJsonConversion(fieldType, false, getElementExpr, converter);

		// arr.push(convertedElement)
		var pushExpr = makeExpr(ECall(makeExpr(EField(makeIdent('arr'), 'push')), [convertedElementExpr]));

		// i++
		var incrementExpr = makeExpr(EUnop(OpIncrement, false, makeIdent('i')));

		// while condition: i < obj.fieldNameLength()
		var whileCondition = makeExpr(EBinop(OpLt, makeIdent('i'), makeExpr(ECall(makeExpr(EField(makeIdent('obj'), fieldName + 'Length')), []))));

		// while body
		var whileBody = makeExpr(EBlock([pushExpr, incrementExpr]));
		var whileExpr = makeExpr(EWhile(whileCondition, whileBody, false));

		expressions.push(whileExpr);

		// Return VArray(arr) - wrap in a block expression that evaluates to VArray(arr)
		return makeExpr(EBlock(expressions.concat([makeExpr(ECall(makeIdent('VArray'), [makeIdent('arr')]))])));
	}

	// Shorthand for creating expressions.
	static inline function makeExpr(exprDef:ExprDef):Expr {
		return {expr: exprDef, pos: nullPos};
	}

	// Shorthand for creating type.
	static inline function makeType(name:String, ?pack:Array<String>, ?params:Null<Array<TypeParam>> = null, ?sub:Null<Null<String>> = null):ComplexType {
		pack == null ? pack = [] : null;
		return TPath(cast {
			name: name,
			pack: pack,
			params: params,
			sub: sub
		});
	}

	static inline function makeFuncArg(name:String, ?type:Null<ComplexType> = null, ?opt:Null<Bool> = null, ?meta:Null<Metadata> = null,
			?value:Null<Null<Expr>> = null):FunctionArg {
		return {
			name: name,
			type: type,
			opt: opt,
			meta: meta,
			value: value
		};
	}

	static inline function makeVar(?name:Null<String> = null, ?type:Null<ComplexType> = null, ?expr:Null<Expr> = null):ExprDef {
		return EVars([{name: name, type: type, expr: expr}]);
	}

	// Shorthand for creating constants.
	static inline function makeIdent(name:String):Expr {
		return makeExpr(EConst(CIdent(name)));
	}

	static inline function makeInt(name:String):Expr {
		return makeExpr(EConst(CInt(name)));
	}

	static inline function makeFloat(name:String):Expr {
		return makeExpr(EConst(CFloat(name)));
	}

	static inline function makeString(name:String):Expr {
		return makeExpr(EConst(CString(name)));
	}

	static inline function makeIdentFromBool(value:Bool):Expr {
		return makeExpr(EConst(CIdent(if (value) "true" else "false")));
	}
}
