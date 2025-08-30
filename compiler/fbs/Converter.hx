package fbs;

import fbs.Ast;
import fbs.Parser;

import haxe.macro.Expr;

using Lambda;

typedef HaxeModule = {
	className: String,
	toplevel: Array<String>,
	types: Array<TypeDefinition>,
	declTypeRef: Map<String, FbsDeclaration>,
	structSizeRef: Map<String, StructSize>,
	structPaddingRef: Map<String, StructPadding>
}

typedef StructSize = {
	minAlign:Int,
	finalSize:Int
}

typedef StructPadding = {
	byteIndex:Int,
	padding:Int
}

typedef FieldType = {
	type:ComplexType,
	alias:String,
	memSize:Int,
	defaultVal:String
};

class Converter {
	static var nullPos:Position = { min: 0, max: 0, file: "" };
	var currentModule:HaxeModule;

	public function new() {
		currentModule = {
			className: "",
			types: [],
			toplevel: [],
			declTypeRef: new Map<String, FbsDeclaration>(),
			structSizeRef: new Map<String, StructSize>(),
			structPaddingRef: new Map<String, StructPadding>()
		};
	}

	public function convert(parsedObj:ParsedObject):HaxeModule {
		storeDeclTypes(parsedObj);
		parsedObj.namespaces.map(function(decl:FbsDeclaration) {
			currentModule.toplevel.push(convertNamespace(decl));
		});
		currentModule.toplevel.push(convertImport());
		parsedObj.enums.map(function(decl:FbsDeclaration) {
			currentModule.types.push(convertEnum(decl));
		});
		parsedObj.structs.map(function(decl:FbsDeclaration) {
			currentModule.types.push(convertStruct(decl));
		});
		parsedObj.tables.map(function(decl:FbsDeclaration) {
			currentModule.types.push(convertTable(decl));
		});
		parsedObj.rootTypes.map(function(decl:FbsDeclaration) {
			currentModule.className = convertRootType(decl);
		});

		var printer:haxe.macro.Printer = new haxe.macro.Printer();
        for (t in currentModule.types){
			trace(printer.printTypeDefinition(t));
		};

		return currentModule;
	}

	function storeDeclTypes(parsedObj:ParsedObject):Void {
		for(field in Reflect.fields(parsedObj)) {
            for (decl in cast ( Reflect.field(parsedObj, field), Array<Dynamic>)) {
				switch cast(decl, FbsDeclaration) {
					case DNamespace(p):
						currentModule.declTypeRef.set(p[p.length - 1], decl);
					case DEnum(p):
						currentModule.declTypeRef.set(p.name, decl);
					case DUnion(p):
						currentModule.declTypeRef.set(p.name, decl);
					case DStruct(p):
						currentModule.declTypeRef.set(p.name, decl);
					case DTable(p):
						currentModule.declTypeRef.set(p.name, decl);
					case DRootType(p):
						currentModule.declTypeRef.set(p[p.length - 1], decl);
				}
            }

		}
	}

	function convertImport():String
	{
		return 'import flatbuffers.FlatBuffers;\nimport flatbuffers.FlatBuffers.ByteBuffer;\nimport flatbuffers.FlatBuffers.Offset;\nimport flatbuffers.FlatBuffers.Builder;\nimport flatbuffers.FlatBuffers.Long;\nimport flatbuffers.impl.FlatBuffersPure.Encoding;\nimport flatbuffers.impl.FlatBuffersPure.TableT;\nimport haxe.Int32;\nimport haxe.Int64;\nimport haxe.io.UInt8Array;\nimport haxe.io.UInt16Array;\nimport haxe.io.Int32Array;\n#if js\nimport flatbuffers.io.Float32Array;\nimport flatbuffers.io.Float64Array;\n#else\nimport haxe.io.Float32Array;\nimport haxe.io.Float64Array;\n#end\nimport haxe.ds.Either;';
	}

	function convertNamespace(decl:FbsDeclaration):String {
		// Haxe package paths must be lower case.
		var namespace:String = (cast decl.getParameters()[0]:Array<String>).map(function(s:String) {
			return s.charAt(0).toLowerCase() + s.substr(1);
		}).join(".");
		return 'package ${namespace};';
	}

	// Convert Enums.

	function convertEnum(decl:FbsDeclaration):TypeDefinition {
		var enumObj:FbsEnum = decl.getParameters()[0];
		var fields:Array<Field> = enumObj.ctors.mapi(function(i:Int, ctor:FbsEnumCtor):Field {
			var fieldVal = 0;
			if (ctor.value != null) {
				fieldVal = Std.parseInt(ctor.value);
			} else {
				fieldVal = i;
			}
			return {
				name: ctor.name.getParameters()[0],
				kind: FVar(null, { expr: EConst(CInt(Std.string(fieldVal))), pos: nullPos }),
				doc: null,
				meta: [],
				access: [],
				pos: nullPos
			}
		});
		// Determine base type for the enum abstract. Use Int64 for long/ulong, otherwise Int.
		var baseType:ComplexType = makeType("Int");
		// Detect bit_flags metadata
		var isBitFlags:Bool = false;
		if (enumObj.metadata != null) {
			for (m in enumObj.metadata) {
				if (m.key == "bit_flags") {
					isBitFlags = true;
					break;
				}
			}
		}

		switch enumObj.type {
			case TPrimitive(TLong) | TPrimitive(TULong):
				if (isBitFlags) {
					haxe.macro.Context.error("64-bit (bit_flags) enums are currently unsupported; remove (bit_flags) or use a 32-bit enum type.", nullPos);
				}
				baseType = makeType("Int64", ["haxe"]);
			case _:
		}

		// If enum has metadata with key "bit_flags", produce a bit-flags style abstract.
		var enumMetaParams:Array<Expr> = [];
		var isBitFlags:Bool = false;
		if (enumObj.metadata != null) {
			for (m in enumObj.metadata) {
				if (m.key == "bit_flags") {
					isBitFlags = true;
					enumMetaParams.push(makeIdent("bit_flags"));
					break;
				}
			}
		}

		// inline constructor: Haxe handles from/to conversions for abstracts, so provide
		// an inline constructor that assigns the underlying value.
		var newField:Field = {
			name: 'new',
			kind: FFun({
				args: [makeFuncArg('i', makeType('Int'))],
				ret: null,
				expr: makeExpr(EBlock([
					makeExpr(EBinop(OpAssign, makeIdent('this'), makeIdent('i')))
				])),
				params: null
			}),
			doc: null,
			// mark inline via metadata so generated code is `inline function new(i:Int) { ... }`
			meta: [{ name: 'inline', params: [], pos: nullPos }],
			access: [APublic],
			pos: nullPos
		};

		var methods = [newField];

		if (isBitFlags) {
			return convertEnumBitFlags(enumObj, fields, methods);
		}

		var allFields:Array<Field> = Lambda.array(Lambda.flatten([
			fields,
			methods
		]));

		return {
			pack: [],
			name: enumObj.name,
			pos: nullPos,
			meta: [],
			params: [],
			isExtern: false,
			kind: TDAbstract(baseType, [AbEnum], [baseType], [baseType]),
			fields: allFields
		}
	}

	// Convert enum declared with (bit_flags) into an abstract that supports bitwise ops.
	function convertEnumBitFlags(enumObj:FbsEnum, fieldsConst:Array<Field>, methods:Array<Field>):TypeDefinition {
		var baseType = makeType("Int");
		var name:String = enumObj.name;
		// Build constant fields: for bit_flags, missing values (or ordinal-style 0,1,2...) become 1<<index.
		var constFields:Array<Field> = enumObj.ctors.mapi(function(i:Int, ctor:FbsEnumCtor):Field {
			var fieldVal:Int;
			if (ctor.value != null) {
				fieldVal = Std.parseInt(ctor.value);
				// If the enum explicitly used ordinal values (0,1,2,...), convert to bit masks.
				if (fieldVal == i) fieldVal = 1 << i;
			} else {
				fieldVal = 1 << i;
			}
			return {
				name: ctor.name.getParameters()[0],
				kind: FVar(null, { expr: EConst(CInt(Std.string(fieldVal))), pos: nullPos }),
				doc: null,
				meta: [],
				access: [],
				pos: nullPos
			};
		});

		// Operator declarations: or and and
		var opOr:Field = {
			name: 'or',
			kind: FFun({
				args: [makeFuncArg('a', makeType(name)), makeFuncArg('b', makeType(name))],
				ret: makeType(name),
				expr: null,
				params: null
			}),
			doc: null,
			meta: [{name: ':op', params: [makeIdent('a|b')], pos: nullPos}],
			access: [APublic, AStatic],
			pos: nullPos
		};

		var opAnd:Field = {
			name: 'and',
			kind: FFun({
				args: [makeFuncArg('a', makeType(name)), makeFuncArg('b', makeType(name))],
				ret: makeType(name),
				expr: null,
				params: null
			}),
			doc: null,
			meta: [{name: ':op', params: [makeIdent('a&b')], pos: nullPos}],
			access: [APublic, AStatic],
			pos: nullPos
		};

		var allFields:Array<Field> = Lambda.array(Lambda.flatten([
			constFields,
			methods,
			[opOr, opAnd]
		]));

		return {
			pack: [],
			name: name,
			pos: nullPos,
			meta: [],
			params: [],
			isExtern: false,
			kind: TDAbstract(baseType, [AbEnum], [baseType], [baseType]),
			fields: allFields
		}
	}

	// Convert Structs.

	function convertStruct(decl:FbsDeclaration):TypeDefinition {
		var structObj:FbsStruct = decl.getParameters()[0];
		var enumCast:String = "";
		var funcFields:haxe.Constraints.Function = function():Array<Field> {
			return structObj.fields.map(function(field:FbsStructField) {
				var fieldType:FieldType;
				switch field.type {
					case TPrimitive(_):
						fieldType = convertType(field.type.getParameters()[0]);
						enumCast = "";
					case TComposite(t):
						fieldType = {type: makeType(t), alias: t, memSize: 0, defaultVal: '0'};
						switch currentModule.declTypeRef[t] {
							case DEnum(p):
								fieldType.alias = convertType(p.type.getParameters()[0]).alias;
								fieldType.memSize = convertType(p.type.getParameters()[0]).memSize;
								enumCast = "cast ";
							case DStruct(_):
							default:
								enumCast = "";
						}
				}
				return {
					name: field.name,
					kind: FFun({
						args: [],
						ret: fieldType.type,
						expr: convertStructRet(field, fieldType, enumCast),
						params: null
					}),
					doc: null,
					meta: [],
					access: [APublic],
					pos: nullPos
				}
			});
		}
		var allFields:Array<Field> = Lambda.array(Lambda.flatten([
			makeBbVars(),
			[makeCon()],
			[makeInitFunc(structObj.name)],
			[convertStructCreate(structObj)],
			funcFields()
		]));
		return {
			pack: [],
			name: structObj.name,
			pos: nullPos,
			meta: [],
			params: null,
			isExtern: false,
			kind: TDClass(null, null, false),
			fields: allFields
		};
	}

	function convertStructRet(field:FbsStructField, fieldType:FieldType, enumCast:String):Expr {
		var args:Array<Expr>;
		var ident:String = "this.bb_pos";
		args = [
			makeExpr(
				EBinop(
					OpAdd,
					makeIdent(ident),
					makeInt(Std.string(currentModule.structPaddingRef.get(field.name).byteIndex))
				)
			)
		];
		return makeExpr(EBlock([
			makeExpr(EReturn(
				makeExpr(ECall(
						makeIdent('${enumCast}this.bb.read${fieldType.alias}'),
						args
				))
			))
		]));
	}

	function convertStructCreate(structObj:FbsStruct):Field {
		var fieldType:FieldType;
		var args:Array<FunctionArg> = structObj.fields.map(function(field:FbsStructField) {
			switch field.type {
				case TPrimitive(_):
					fieldType = convertType(field.type.getParameters()[0]);
				case TComposite(t):
					fieldType = {type: makeType(t), alias: t, memSize: 0, defaultVal: '0'};
					switch currentModule.declTypeRef[t] {
						case DEnum(p):
							fieldType.alias = convertType(p.type.getParameters()[0]).alias;
							fieldType.memSize = convertType(p.type.getParameters()[0]).memSize;
						case DStruct(_):
						default:
					}
			}
			return makeFuncArg(field.name, fieldType.type);
		});
		args.unshift(makeFuncArg("builder", makeType("Builder")));

		var memSizeList:Array<Int> = structObj.fields.map(function(field:FbsStructField) {
			switch field.type {
				case TPrimitive(_):
					return convertType(field.type.getParameters()[0]).memSize;
				case TComposite(t):
					switch currentModule.declTypeRef[t] {
						case DEnum(p):
							return convertType(p.type.getParameters()[0]).memSize;
						default:
							return null;
					}
			}
		});
		var minAlign:Int = memSizeList.fold(function(a:Int, b:Int) {
			return Std.int(Math.max(a, b));
		}, 0);

		var expr:Array<Expr> = [];
		var byteIndex:Int = 0;
		var enumCast:String = "";
		for (i in 0...structObj.fields.length) {
			var fieldType:FieldType;
			switch (cast structObj.fields[i].type:FbsType) {
				case TPrimitive(_):
					fieldType = convertType(structObj.fields[i].type.getParameters()[0]);
					enumCast = "";
				case TComposite(t):
					fieldType = {type: makeType(t), alias: t, memSize: 0, defaultVal: '0'};
					switch currentModule.declTypeRef[t] {
						case DEnum(p):
							fieldType.alias = convertType(p.type.getParameters()[0]).alias;
							fieldType.memSize = convertType(p.type.getParameters()[0]).memSize;
							enumCast = "cast ";
						case DUnion(_):
						case DStruct(_):
						case DTable(_):
						default:
						enumCast = "";
					}
			}
			var padding:Int = 0;

			if(fieldType.memSize + (byteIndex % minAlign) > minAlign) {
				padding = (Math.ceil(byteIndex / minAlign) * minAlign) - byteIndex;
				byteIndex += padding;
				currentModule.structPaddingRef.set(structObj.fields[i].name, {
					byteIndex: byteIndex,
					padding: padding
				});
			} else {
				currentModule.structPaddingRef.set(structObj.fields[i].name, {
					byteIndex: byteIndex,
					padding: padding
				});
			}

			byteIndex += fieldType.memSize;
			// Padding.
			if(padding != 0) {
				expr.unshift(makeExpr(
					ECall(makeIdent('builder.pad'), [makeIdent(Std.string(padding))])
				));
			}
			expr.unshift(makeExpr(
				ECall(makeIdent('builder.write${fieldType.alias}'), [makeIdent('${enumCast}${structObj.fields[i].name}')])
			));

		}
		// Check if final buffer is divisible by minimum alignment (1, 2. 4 or 8), if not round up to the nearest divisible number.
		var finalSize:Int = Std.int(Math.ceil(byteIndex / minAlign) * minAlign);
		var endPadding:Int = finalSize - byteIndex;
		if(endPadding != 0) {
			expr.unshift(makeExpr(
				ECall(makeIdent('builder.pad'), [makeIdent(Std.string(endPadding))])
			));
		}

		// builder.prep();
		expr.unshift(makeExpr(
			ECall(makeIdent('builder.prep'), [makeIdent(Std.string(minAlign)), makeIdent(Std.string(finalSize))])
		));
		// return builder.offset();
		expr.push(makeExpr(
			EReturn(makeExpr(
				ECall(makeIdent('builder.offset'), [])
			))
		));

		currentModule.structSizeRef.set(structObj.name, {minAlign: minAlign, finalSize: finalSize});

		return {
				name: 'create${structObj.name}',
				kind: FFun({
					args: args,
					ret: makeType('Offset'),
					expr: makeExpr(EBlock(expr)),
					params: null
				}),
				doc: null,
				meta: [],
				access: [APublic, AStatic],
				pos: nullPos
		};
	}

	// Convert Unions.

	function convertUnion(decl:FbsDeclaration):TypeDefinition {
		return null;
	}

	// Convert Tables.

	function convertTable(decl:FbsDeclaration):TypeDefinition {
		var structObj:FbsTable = decl.getParameters()[0];
		var fieldsLength:Int = structObj.fields.length;

		var args:Array<FunctionArg> = [];
		var defaultRet:Expr = makeIdent('null');
		var vtable_offset:Int = 2;

		var funcFields:Array<Array<Field>> = structObj.fields.map(function(field:FbsTableField) {
			var retExpr:Expr;
			var fieldType:FieldType;
			var elem_size:Int = 0;
			defaultRet = makeIdent('null');
			args = [];
			switch (field.type) {
				case TPrimitive(_):
					fieldType = convertType(field.type.getParameters()[0]);
					switch(fieldType.alias) {
						case "String":
							fieldType.alias = "__string";
						case "Int64":
							fieldType.alias = 'read' + fieldType.alias;
							fieldType.defaultVal = "Int64.make(0, 0)";
						default:
							fieldType.alias = 'read' + fieldType.alias;
					}
					if(field.isVector) {
						args.unshift(makeFuncArg("index", makeType('Int')));
						retExpr = makeExpr(EReturn(
							makeExpr(ETernary(
								makeIdent('offset != 0'), makeIdent('this.bb.${fieldType.alias}(this.bb.__vector(this.bb_pos + offset) + index * ${fieldType.memSize})'), makeIdent("0") //TODO
							))
						));
					} else {
						// Non-vector scalar field: for booleans we must return Bool and convert
						// the underlying byte to a boolean. Strings remain nullable.
						switch (cast field.type:FbsType) {
							case TPrimitive(TBool):
								retExpr = makeExpr(EReturn(
									makeExpr(ETernary(
										makeIdent('offset != 0'), makeIdent('(this.bb.readInt8(this.bb_pos + offset) != 0)'), makeIdent('false')
									))
								));
							default:
								retExpr = makeExpr(EReturn(
									makeExpr(ETernary(
										makeIdent('offset != 0'), makeIdent('this.bb.${fieldType.alias}(this.bb_pos + offset)'), makeIdent(fieldType.defaultVal)
									))
								));
						}
					}
				case TComposite(t):
					fieldType = {type: makeType(t), alias: t, memSize: 0, defaultVal: '0'};
					var retCall:Expr = makeIdent('(obj != null ? obj : new ${t}()).__init(this.bb_pos + offset, this.bb)');

					if(field.isVector) {
						// Figure out type of composite by searching the current modules decleration type reference map for the type.
						switch currentModule.declTypeRef[t] {
							case DEnum(p):
								args = [makeFuncArg("index", makeType('Int'))];
								retCall = makeIdent('cast (this.bb.read${convertType(p.type.getParameters()[0]).alias}(this.bb.__vector(this.bb_pos + offset) + index))');
								// Maybe use unsafe cast instead of .getIndex() since it's an abstract.
								defaultRet = makeIdent('cast ${t}.${p.ctors[0].name.getParameters()[0]}');
							case DUnion(_):
							case DStruct(p):
								args = [makeFuncArg("obj", makeType('Null<${t}>'), true)];
								elem_size = currentModule.structSizeRef[p.name].finalSize;
								retCall = makeIdent('(obj != null ? obj : new ${t}()).__init(this.bb.__vector(this.bb_pos + offset) + index * ${elem_size}, this.bb)');
								args.unshift(makeFuncArg("index", makeType('Int')));
							case DTable(_):
								args = [makeFuncArg("obj", makeType('Null<${t}>'), true)];
								args.unshift(makeFuncArg("index", makeType('Int')));
								retCall = makeIdent('(obj != null ? obj : new ${t}()).__init(this.bb.__indirect(this.bb.__vector(this.bb_pos + offset) + index * 4), this.bb)');
							default:
						}
					} else {
						// Figure out type of composite by searching the current modules decleration type reference map for the type.
						switch currentModule.declTypeRef[t] {
							case DEnum(p):
								retCall = makeIdent('cast (this.bb.read${convertType(p.type.getParameters()[0]).alias}(this.bb_pos + offset))');
								// Maybe use unsafe cast instead of .getIndex() since it's an abstract.
								defaultRet = makeIdent('cast ${t}.${p.ctors[0].name.getParameters()[0]}');
							case DUnion(_):
							case DStruct(p):
								args = [makeFuncArg("obj", makeType('Null<${t}>'), true)];
								elem_size = currentModule.structSizeRef[p.name].finalSize;
							case DTable(_):
								args = [makeFuncArg("obj", makeType('Null<${t}>'), true)];
								retCall = makeIdent('(obj != null ? obj : new ${t}()).__init(this.bb.__indirect(this.bb_pos + offset), this.bb)');
							default:
						}
					}
					retExpr = makeExpr(EReturn(
							makeExpr(ETernary(
								makeIdent('offset != 0'), retCall, defaultRet
							))
					));
			}

			vtable_offset += 2;
			if(field.isVector) {
				var vecFieldArray:Array<Field>;
				// Determine return type for vector element getter
				var vecElemRet:ComplexType = null;
				switch (field.type) {
					case TPrimitive(_):
						var primElem = (cast field.type.getParameters()[0]:FbsPrimitiveType);
						switch primElem {
							case TString:
								vecElemRet = makeType('Null', null, [TPType(makeType('String'))]);
							case TBool:
								vecElemRet = makeType('Bool');
							case _:
								vecElemRet = fieldType.type;
						}
					case TComposite(_):
						vecElemRet = makeType('Null', null, [TPType(fieldType.type)]);
				}

				vecFieldArray = [{
					name: field.name,
					kind: FFun({
						args: args,
						ret: vecElemRet,
						expr: makeExpr(EBlock([
							makeExpr(makeVar(
								'offset', makeType('Int'), makeIdent('this.bb.__offset(this.bb_pos, ${vtable_offset})')
							)),
							retExpr
						])),
						params: null
					}),
					doc: null,
					meta: [],
					access: [APublic],
					pos: nullPos
				},
				{
					name: '${field.name}Length',
					kind: FFun({
						args: [],
						ret: makeType('Null', null, [TPType(makeType("Int"))]),
						expr: makeExpr(EBlock([
								makeExpr(makeVar(
									'offset', makeType('Int'), makeIdent('this.bb.__offset(this.bb_pos, ${vtable_offset})')
								)),
							makeExpr(EReturn(
								makeExpr(ETernary(
									makeIdent('offset != 0'), makeIdent('this.bb.__vector_len(this.bb_pos + offset)'), makeIdent(fieldType.defaultVal)
								))
							))
						])),
						params: null
					}),
					doc: null,
					meta: [],
					access: [APublic],
					pos: nullPos
				}];
				switch field.type {
					case TPrimitive(t):
						var typeAlias:String = convertType(t).alias;
							switch typeAlias {
								case "Int8":
									typeAlias = "U" + typeAlias;
								case "Int16":
									typeAlias = "U" + typeAlias;
								default:
							}
						vecFieldArray.push({
							name: '${field.name}Array',
							kind: FFun({
								args: [],
								ret: makeType('Null', null, [TPType(makeType('${typeAlias}Array'))]),
								expr: makeExpr(EBlock([
										makeExpr(makeVar(
											'offset', makeType('Int'), makeIdent('this.bb.__offset(this.bb_pos, ${vtable_offset})')
										)),
									makeExpr(EReturn(
										makeExpr(ETernary(
											makeIdent('offset != 0'), makeIdent('${typeAlias}Array.fromBytes(this.bb.bytes().view.buffer, this.bb.bytes().view.byteOffset + this.bb.__vector(this.bb_pos + offset), this.bb.__vector_len(this.bb_pos + offset))'), makeIdent('null')
										))
									))
								])),
								params: null
							}),
							doc: null,
							meta: [],
							access: [APublic],
							pos: nullPos
						});
					case TComposite(t):
						switch currentModule.declTypeRef[t] {
							case DEnum(p):
								var typeAlias:String = convertType(p.type.getParameters()[0]).alias;
								switch typeAlias {
									case "Int8":
										typeAlias = "U" + typeAlias;
									case "Int16":
										typeAlias = "U" + typeAlias;
									default:
								}
								vecFieldArray.push({
								name: '${field.name}Array',
								kind: FFun({
									args: [],
									ret: makeType('Null', null, [TPType(makeType('${typeAlias}Array'))]),
									expr: makeExpr(EBlock([
										makeExpr(makeVar(
											'offset', makeType('Int'), makeIdent('this.bb.__offset(this.bb_pos, ${vtable_offset})')
										)),
										makeExpr(EReturn(
											makeExpr(ETernary(
												makeIdent('offset != 0'), makeIdent('${typeAlias}Array.fromBytes(this.bb.bytes().view.buffer, this.bb.bytes().view.byteOffset + this.bb.__vector(this.bb_pos + offset), this.bb.__vector_len(this.bb_pos + offset))'), makeIdent('null')
											))
										))
									])),
									params: null
								}),
								doc: null,
								meta: [],
								access: [APublic],
								pos: nullPos
							});
							default:
						}
				}
				return vecFieldArray;
			} else {
				// Determine the Haxe return type for this field getter.
				var retType:ComplexType = null;
				switch (field.type) {
					case TPrimitive(_):
						var prim = (cast field.type.getParameters()[0]:FbsPrimitiveType);
						switch prim {
							case TString:
								retType = makeType('Null', null, [TPType(makeType('String'))]);
							case TBool:
								retType = makeType('Bool');
							case _:
								retType = fieldType.type;
						}
					case TComposite(_):
						retType = makeType('Null', null, [TPType(fieldType.type)]);
				}

				return [{
					name: field.name,
					kind: FFun({
						args: args,
						ret: retType,
						expr: makeExpr(EBlock([
							makeExpr(makeVar(
								'offset', makeType('Int'), makeIdent('this.bb.__offset(this.bb_pos, ${vtable_offset})')
							)),
							retExpr
						])),
						params: null
					}),
					doc: null,
					meta: [],
					access: [APublic],
					pos: nullPos
				}];
			}
		});

		var funcStartFields:Field = {
			name: 'start${structObj.name}',
			kind: FFun({
				args: [makeFuncArg("builder", makeType("Builder"))],
				ret: makeType('Void'),
				expr: makeExpr(EBlock([
					makeExpr(ECall(
						makeIdent('builder.startObject'),
						[makeIdent(Std.string(fieldsLength))]
					))
				])),
				params: null
			}),
			doc: null,
			meta: [],
			access: [APublic, AStatic],
			pos: nullPos
		}

		var funcAddFields:Array<Array<Field>> = structObj.fields.mapi(function(i:Int, field:FbsTableField) {
			var fieldType:FieldType;
			var expr:Expr;
			var fieldName:String = field.name; // Field name to have "Offset" added if needed.
			var enumCast:String = "";

			switch (field.type) {
				case TPrimitive(_):
					fieldType = convertType(field.type.getParameters()[0]);
					var typeCast = "";
					if(!field.isVector) {
						switch((cast field.type.getParameters()[0]:FbsPrimitiveType)) {
							case TBool:
								typeCast = " ? 1 : 0";
							case TLong:
								fieldType.defaultVal = "builder.createLong(0, 0)";
							case TULong:
								fieldType.defaultVal = "builder.createLong(0, 0)";
							case TString:
								fieldName += "Offset";
								fieldType.alias = "Offset";
								fieldType.type = makeType("Offset");
								fieldType.defaultVal = "0";
							default:
						}
					} else {
						if(!~/Offset/i.match(fieldName)) {
							fieldName += "Offset";
							fieldType.alias = "Offset";
							fieldType.type = makeType("Offset");
						}
					}
					expr = makeExpr(EBlock([
						makeExpr(ECall(
							makeIdent('builder.addField${fieldType.alias}'),
							[makeIdent(Std.string(i)), makeIdent(fieldName + typeCast), makeIdent(fieldType.defaultVal)]
						))
					]));
				case TComposite(t):
					fieldType = {type: makeType(t), alias: "Offset", memSize: 0, defaultVal: "0"};
					// Figure out type of composite by searching the current modules decleration type reference map for the type.
					if(!field.isVector) {
						switch currentModule.declTypeRef[t] {
							case DEnum(p):
								fieldType.alias = convertType(p.type.getParameters()[0]).alias;
								// Maybe use unsafe cast instead of .getIndex() since it's an abstract.
								fieldType.defaultVal = 'cast ${t}.${p.ctors[0].name.getParameters()[0]}';
								enumCast = "cast ";
							case DUnion(_):
							case DStruct(_):
								fieldType.type = makeType("Offset");
								fieldType.alias = "Struct";
								fieldName += "Offset";
							case DTable(_):
								fieldType.type = makeType("Offset");
								fieldName += "Offset";
							default:
						}
					} else {
						if(!~/Offset/i.match(fieldName)) {
							fieldName += "Offset";
							fieldType.alias = "Offset";
							fieldType.type = makeType("Offset");
						}
					}
					expr = makeExpr(EBlock([
						makeExpr(ECall(
							makeIdent('builder.addField${fieldType.alias}'),
							[makeIdent(Std.string(i)), makeIdent('${enumCast}${fieldName}'), makeIdent(fieldType.defaultVal)]
						))
					]));
			}

			var addFieldArray:Array<Field>;
			// Create add fields be default.
			addFieldArray = [{
				name: 'add${field.name.charAt(0).toUpperCase() + field.name.substr(1)}',
				kind: FFun({
					args: [makeFuncArg("builder", makeType("Builder")), makeFuncArg(fieldName, fieldType.type)],
					ret: makeType('Void'),
					expr: expr,
					params: null
				}),
				doc: null,
				meta: [],
				access: [APublic, AStatic],
				pos: nullPos
			}];
			// Only create these fields if vector.
			if(field.isVector) {
				// elem_size: The size of each element in the array.
				var elem_size:String = "";
				// num_elems: The number of elements in the array
				var num_elems:String = "";
				// Skip create field if struct or table.
				var skipCreate:Bool = false;

				switch(field.type) {
					case TComposite(t):
						switch currentModule.declTypeRef[t] {
							case DEnum(p):
								// Size of enum underlying type.
								elem_size = Std.string(convertType(p.type.getParameters()[0]).memSize);
								num_elems = "0";
								fieldType.memSize = convertType(p.type.getParameters()[0]).memSize;
								fieldType.alias = convertType(p.type.getParameters()[0]).alias;
								fieldType.type = makeType('Array<${p.name}>');
								elem_size = Std.string(convertType(p.type.getParameters()[0]).memSize);
								num_elems = Std.string(convertType(p.type.getParameters()[0]).memSize);
							case DUnion(p):
								fieldType.type = makeType('Array<${p.name}>');
							case DStruct(p):
								// Combined size of all fields in struct.
								elem_size = Std.string(currentModule.structSizeRef[p.name].finalSize);
								num_elems = Std.string(currentModule.structSizeRef[p.name].minAlign);
								fieldType.type = makeType('Array<${p.name}>');
								skipCreate = true;
							case DTable(p):
								elem_size = Std.string(4);
								num_elems = Std.string(4);
								// For vectors of tables we expect an array of Offsets (not table instances).
								fieldType.type = makeType('Array<Offset>');
								fieldType.alias = 'Offset';
								skipCreate = false;
							default:
						}
					case TPrimitive(t):
						switch t {
							case TString:
								fieldType.alias = "Offset";
								fieldType.type = makeType('Array<${convertType(t).type.getParameters()[0].name}>');
							default:
								fieldType.alias = convertType(t).alias;
								fieldType.type = makeType('Array<${convertType(t).type.getParameters()[0].name}>');
						}
						elem_size = Std.string(fieldType.memSize);
						num_elems = Std.string(fieldType.memSize);
				}
				if(!skipCreate) {
					var elemExpr = switch (fieldType.alias) {
						case 'Offset': 'data[i]';
						case _: switch (cast field.type:FbsType) {
							case TPrimitive(TBool): '(data[i] ? 1 : 0)';
							case _: 'cast data[i]';
						}
					};

					addFieldArray.push({
						name: 'create${field.name.charAt(0).toUpperCase() + field.name.substr(1)}Vector',
						kind: FFun({
							args: [makeFuncArg("builder", makeType("Builder")), makeFuncArg("data", fieldType.type)],
							ret: makeType('Offset'),
								expr: makeExpr(EBlock([
									makeExpr(ECall(
										makeIdent('builder.startVector'),
										[makeIdent(elem_size), makeIdent('data.length'), makeIdent(num_elems)]
									)),
									makeIdent('var i:Int = data.length - 1'),
									// Use elemExpr computed above.
									makeIdent('while (i >= 0) { builder.add${fieldType.alias}(' + elemExpr + '); i--; }'),
									makeIdent('return builder.endVector()')
								])),
							params: null
						}),
						doc: null,
						meta: [],
						access: [APublic, AStatic],
						pos: nullPos
					});
				}
				addFieldArray.push({
					name: 'start${field.name.charAt(0).toUpperCase() + field.name.substr(1)}Vector',
					kind: FFun({
						args: [makeFuncArg("builder", makeType("Builder")), makeFuncArg("numElems", makeType("Int"))],
						ret: makeType('Void'),
						expr: makeExpr(EBlock([
							makeExpr(ECall(
								makeIdent('builder.startVector'),
								[makeIdent(elem_size), makeIdent("numElems"), makeIdent(num_elems)]
							))
						])),
						params: null
					}),
					doc: null,
					meta: [],
					access: [APublic, AStatic],
					pos: nullPos
				});
			}
			return addFieldArray;
		});

		var funcEndFields:Field = {
			name: 'end${structObj.name}',
			kind: FFun({
				args: [makeFuncArg("builder", makeType("Builder"))],
				ret: makeType('Offset'),
				expr: makeExpr(EBlock([
						makeExpr(makeVar(
							'offset', makeType('Int'), makeIdent('builder.endObject()')
						)),
					makeExpr(EReturn(
						makeIdent('offset')
					))
				])),
				params: null
			}),
			doc: null,
			meta: [],
			access: [APublic, AStatic],
			pos: nullPos
		}

		var allFields:Array<Field> = Lambda.array(Lambda.flatten([
			makeBbVars(),
			[makeCon()],
			[makeInitFunc(structObj.name)],
			[convertTableGetRoot(structObj)],
			Lambda.flatten(funcFields),
			[funcStartFields],
			Lambda.flatten(funcAddFields),
			[funcEndFields]
		]));

		return {
			pack: [],
			name: structObj.name,
			pos: nullPos,
			meta: [],
			params: null,
			isExtern: false,
			kind: TDClass(null, null, false),
			fields: allFields
		};
	}

	function convertTableGetRoot(structObj:FbsTable):Field {
		return {
				name: 'getRootAs${structObj.name}',
				kind: FFun({
					args: [makeFuncArg("bb", makeType("ByteBuffer")), makeFuncArg("obj", makeType(structObj.name), true)],
					ret: makeType(structObj.name),
					expr: makeExpr(
						EBlock([
							makeExpr(EReturn(
								makeIdent('obj != null ? obj.__init(bb.readInt32(bb.position()) + bb.position(), bb) : new ${structObj.name}().__init(bb.readInt32(bb.position()) + bb.position(), bb)')
							))
						])
					),
					params: null
				}),
				doc: null,
				meta: [],
				access: [APublic, AStatic],
				pos: nullPos
		};
	}

	// Convert Root Type.

	function convertRootType(decl:FbsDeclaration):String {
		var structObj:Array<String> = decl.getParameters()[0];
		return structObj[0];
	}

	// Utils.
	function convertType(type:FbsPrimitiveType):FieldType {
		return switch(type) {
			case TBool: {type: makeType("Bool"), alias: "Int8", memSize: 1, defaultVal: "0"};// Bool/Int8
			case TByte: {type: makeType("Int"), alias: "Int8", memSize: 1, defaultVal: "0"}; // Int8
			case TUByte: {type: makeType("Int"), alias: "Int8", memSize: 1, defaultVal: "0"}; // Int8
			case TShort: {type: makeType("Int"), alias: "Int16", memSize: 2, defaultVal: "0"}; // Int16
			case TUShort: {type: makeType("Int"), alias: "Int16", memSize: 2, defaultVal: "0"}; // Int16
			case TInt: {type: makeType("Int"), alias: "Int32", memSize: 4, defaultVal: "0"}; // Int32
			case TUInt: {type: makeType("Int"), alias: "Int32", memSize: 4, defaultVal: "0"}; // Int32
			case TFloat: {type: makeType("Float"), alias: "Float32", memSize: 4, defaultVal: "0.0"}; // Float32
			case TLong: {type: makeType("Int64"), alias: "Int64", memSize: 8, defaultVal: "0"}; // Int64
			case TULong: {type: makeType("Int64"), alias: "Int64", memSize: 8, defaultVal: "0"}; // Int64
			case TDouble: {type: makeType("Float"), alias: "Float64", memSize: 8, defaultVal: "0.0"}; // Float64
			case TString: {type: makeType("String"), alias: "String", memSize: 4, defaultVal: "null"}; // String
		}
	}

	// Shorthand for creating expressions.
	static inline function makeExpr(exprDef:ExprDef):Expr {
		return {expr: exprDef, pos: nullPos};
	}
	// Shorthand for creating type.
	static inline function makeType(name:String, ?pack:Array<String>, ?params:Null<Array<TypeParam>> = null, ?sub:Null<Null<String>> = null):ComplexType {
		pack == null ? pack = [] : null;
		return TPath(cast { name: name, pack: pack, params: params, sub: sub });
	}
	static inline function makeFuncArg(name:String, ?type:Null<ComplexType> = null, ?opt:Null<Bool> = null, ?meta:Null<Metadata> = null, ?value:Null<Null<Expr>> = null):FunctionArg {
		return {name: name, type: type, opt: opt, meta: meta, value: value};
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

	// Shorthand for constructor.
	static inline function makeCon():Field {
		return {
				name: "new",
				kind: FFun({
					args: [],
					ret: null,
					expr: makeExpr(EBlock([])),
					params: null
				}),
				doc: null,
				meta: [],
				access: [APublic],
				pos: nullPos
		};
	}

	static inline function makeInitFunc(returnType:String):Field {
		return {
				name: "__init",
				kind: FFun({
					args: [makeFuncArg("i", makeType("Int")), makeFuncArg("bb", makeType("ByteBuffer"))],
					ret: makeType(returnType),
					expr: makeExpr(EBlock([
						makeExpr(EBinop(
							OpAssign, makeIdent("this.bb_pos"), makeIdent("i")
						)),
						makeExpr(EBinop(
							OpAssign, makeIdent("this.bb"), makeIdent("bb")
						)),
						makeExpr(EReturn(
							makeIdent("this")
						))
					])),
					params: null
				}),
				doc: null,
				meta: [],
				access: [APublic],
				pos: nullPos
		};
	}

	// Shorthand for standard ByteBuffer fields.
	static inline function makeBbVars():Array<Field> {
		return [{
				name: "bb",
				kind: FVar(makeType("ByteBuffer"), null),
				doc: null,
				meta: [],
				access: [],
				pos: nullPos
		}, {
				name: "bb_pos",
				kind: FVar(makeType("Int"), null),
				doc: null,
				meta: [],
				access: [],
				pos: nullPos
		}];
	}
}
