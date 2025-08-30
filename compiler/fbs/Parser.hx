package fbs;

import fbs.Token;
import fbs.Ast;
import fbs.Lexer;

typedef ParsedObject = {
	namespaces: Array<FbsDeclaration>,
	enums: Array<FbsDeclaration>,
	unions: Array<FbsDeclaration>,
	structs: Array<FbsDeclaration>,
	tables: Array<FbsDeclaration>,
	rootTypes: Array<FbsDeclaration>
}

class Parser extends hxparse.Parser<hxparse.LexerTokenSource<FbsToken>, FbsToken> implements hxparse.ParserBuilder {

	var moduleName:String;
	var parsedObject:ParsedObject = {
		namespaces: [],
		enums: [],
		unions: [],
		structs: [],
		tables: [],
		rootTypes: []
	};

	public function new(input:byte.ByteData, sourceName:String) {
		moduleName = sourceName;
		super(new hxparse.LexerTokenSource(new Lexer(input, sourceName), Lexer.tok));
	}

	// Parse FlatBuffer IDL.
	public function parse():ParsedObject {
		while(true) {
			switch stream {
				case [{def: TComment(s)}]:
				case [{def: TKeyword(FbsNamespace)}, ns = namespaceParse([])]:
					parsedObject.namespaces.push(ns);
				case [{def: TKeyword(FbsEnum)}, en = enumParse(null)]:
					parsedObject.enums.push(en);
				case [{def: TKeyword(FbsUnion)}, un = unionParse(null)]:
					parsedObject.unions.push(un);
				case [{def: TKeyword(FbsStruct)}, str = structParse(null)]:
					parsedObject.structs.push(str);
				case [{def: TKeyword(FbsTable)}, tb = tableParse(null)]:
					parsedObject.tables.push(tb);
				case [{def: TIdent("root_type")}, rt = rootTypeParse([])]:
					parsedObject.rootTypes.push(rt);
				case [{def: TEof}]:
					break;
				case _:
					trace(this.peek(0).def);
					junk();
					break;
			}
		}
		return parsedObject;
	}

	// Namespace

	function namespaceParse(arr:Array<String>):FbsDeclaration {
		while (true) {
			switch stream {
				case [{def: TSemicolon}]: break;
				case [{def: TDot}]: 
				case [{def: TIdent(s)}]: arr.push(s);
			}
		}
		return DNamespace(arr);
	}


	// Enums

	function enumParse(decl:FbsDeclaration):FbsDeclaration {
		while (true) {
			switch stream {
				case [{def: TIdent(s)}, {def: TColon}, t = type(), meta = metadata(), {def: TLBrace}, props = enumProps([])]:
					decl = DEnum({
						name: s, 
						type: t,
						ctors: props,
						metadata: meta
					});	
					this.last.def == TRBrace ? break : continue;
			}
		}
		return decl;
	}
	
	function enumProps(arr:Array<FbsEnumCtor>):Array<FbsEnumCtor> {
		while (true) {
			switch stream {
				case [{def: TRBrace}]: break;
				case [{def: TComma}]:
				case [{def: TIdent(s)}, val = enumNext(), meta = metadata()]: 
					arr.push({
						name: TIdentifier(s),
						value: val,
						metadata: meta
					});
					this.last.def == TRBrace ? break : continue;
			}
		}
		return arr;
	}

	function enumNext():String {
		return switch stream {
			case [{def: TAssign}, {def: TNumber(v)}, close = enumClose()]: v;
			case [close = enumClose()]: close;
		} 
	}

	function enumClose():String {
		return switch stream {
			case [{def: TRBrace}]: null;
			case [{def: TComma}]: null;
		} 
	}


	// Unions

	function unionParse(decl:FbsDeclaration) {
		while (true) {
			switch stream {
				case [{def: TIdent(s)}, meta = metadata(), {def: TLBrace}, val = unionNext([])]: 
					
				decl = DUnion({
					name: s, 
					values: val,
					metadata: meta
				});
				break;
			}
		}
		return decl;
	}

	function unionNext(arr:Array<String>):Array<String> {
		while (true) {
			switch stream {
				case [{def: TRBrace}]: break;
				case [{def: TIdent(s)}]: arr.push(s);
				case [{def: TComma}]: 
			}
		}
		return arr;
	}

	// Structs

	function structParse(decl:FbsDeclaration):FbsDeclaration {
		while (true) {
			switch stream {
				case [{def: TIdent(s)}, meta = metadata(), {def: TLBrace}, f = structFields([])]:
				decl = DStruct({
					name: s, 
					fields: f,
					metadata: meta
				}); 
				break;
			}
		}
		return decl;
	}

	function structFields(arr:Array<FbsStructField>):Array<FbsStructField> {
		while (true) {
			switch stream {
				case [{def: TRBrace}]: break;
				case [{def: TComment(s)}]:
				case [{def: TIdent(s)}, {def: TColon}, t = type(), meta = metadata(), {def: TSemicolon}]: 
					arr.push({
						name: s,
						type: t,
						metadata: meta
					});
			}
		}
		return arr;
	}
	

	// Tables

	function tableParse(decl:FbsDeclaration):FbsDeclaration {
		while (true) {
			switch stream {
				case [{def: TRBrace}]: break;
				case [{def: TIdent(s)}, meta = metadata(), {def: TLBrace}, f = tableFields([])]:
					decl = DTable({
						name: s, 
						fields: f,
						metadata: meta
					}); 
					break;
			}
		}
		return decl;
	}

	function tableFields(arr:Array<FbsTableField>):Array<FbsTableField> {
		while (true) {
			switch stream {
				case [{def: TRBrace}]: break;
				case [{def: TComment(s)}]:
				case [{def: TIdent(s)}, {def: TColon}, t = typeVector(), tn = tableNext(), meta = metadata(), {def: TSemicolon}]: 
					arr.push({
						name: s,
						type: t.type,
						isVector: t.isVector,
						defaultValue: tn,
						metadata: meta
					});
			}
		}
		return arr;
	}

	function tableNext():String {
		// Return an assigned default value if present, but do NOT consume the trailing
		// semicolon here; the outer caller (tableFields) is responsible for matching it.
		return switch stream {
			case [{def: TAssign}, {def: TNumber(v) | TBool(v) | TIdent(v)}]: v;
			case _: null;
		}
	}

	// Root Type

	function rootTypeParse(arr:Array<String>):FbsDeclaration {
		while (true) {
			switch stream {
				case [{def: TSemicolon}]: break;
				case [{def: TIdent(s)}]: arr.push(s);
			}
		}
		return DRootType(arr);
	}

	// Utils

	function metadata():FbsMetadata {
		return switch stream {
			case [{def: TLPar}, entries = metadataEntries([])]: entries;
			case _: []; // No metadata
		}
	}

	function metadataEntries(arr:Array<FbsMetadataEntry>):FbsMetadata {
		while (true) {
			switch stream {
				case [{def: TRPar}]: break;
				case [{def: TIdent(s)}, val = metadataValue()]: 
					arr.push({
						key: s,
						value: val
					});
				case [{def: TComma}]:
			}
		}
		return arr;
	}

	function metadataValue():Null<FbsValue> {
		return switch stream {
			case [{def: TColon}, val = value()]: val;
			case _: null; // No value, just a key
		}
	}

	function value():FbsValue {
		return switch stream {
			case [{def: TBool(v)}]: VScalar(TBoolConstant(v));
			case [{def: TNumber(v)}]: 
				if (v.indexOf('.') != -1 || v.toLowerCase().indexOf('e') != -1) {
					VScalar(TFloatConstant(v));
				} else {
					VScalar(TIntegerConstant(v));
				}
			case [{def: TString(v)}]: VString(v);
			case [{def: TLBrace}, obj = objectValue([])]: VObject(obj);
			case [{def: TLBrack}, arr = arrayValue([])]: VArray(arr);
		}
	}

	function objectValue(arr:Array<{key:String, value:FbsValue}>):Array<{key:String, value:FbsValue}> {
		while (true) {
			switch stream {
				case [{def: TRBrace}]: break;
				case [{def: TIdent(key)}, {def: TColon}, val = value()]:
					arr.push({key: key, value: val});
				case [{def: TComma}]:
			}
		}
		return arr;
	}

	function arrayValue(arr:Array<FbsValue>):Array<FbsValue> {
		while (true) {
			switch stream {
				case [{def: TRBrack}]: break;
				case [val = value()]:
					arr.push(val);
				case [{def: TComma}]:
			}
		}
		return arr;
	}

	function type():FbsType {
		return switch stream {
			case [{def: TIdent("bool")}]: TPrimitive(TBool);
			case [{def: TIdent("byte")}]: TPrimitive(TByte);
			case [{def: TIdent("ubyte")}]: TPrimitive(TUByte);
			case [{def: TIdent("short")}]: TPrimitive(TShort);
			case [{def: TIdent("ushort")}]: TPrimitive(TUShort);
			case [{def: TIdent("int")}]: TPrimitive(TInt);
			case [{def: TIdent("uint")}]: TPrimitive(TUInt);
			case [{def: TIdent("float")}]: TPrimitive(TFloat);
			case [{def: TIdent("long")}]: TPrimitive(TLong);
			case [{def: TIdent("ulong")}]: TPrimitive(TULong);
			case [{def: TIdent("double")}]: TPrimitive(TDouble);
			case [{def: TIdent("int8")}]: TPrimitive(TByte);
			case [{def: TIdent("uint8")}]: TPrimitive(TUByte);
			case [{def: TIdent("int16")}]: TPrimitive(TShort);
			case [{def: TIdent("uint16")}]: TPrimitive(TUShort);
			case [{def: TIdent("int32")}]: TPrimitive(TInt);
			case [{def: TIdent("uint32")}]: TPrimitive(TUInt);
			case [{def: TIdent("int64")}]: TPrimitive(TLong);
			case [{def: TIdent("uint64")}]: TPrimitive(TULong);
			case [{def: TIdent("float32")}]: TPrimitive(TFloat);
			case [{def: TIdent("float64")}]: TPrimitive(TDouble);
			case [{def: TIdent("string")}]: TPrimitive(TString);
			case [{def: TIdent(s)}]: TComposite(s);
		}
	}

	function typeVector():{type:FbsType, isVector:Bool} {
		return switch stream {
			case [{def: TLBrack}, t = typeNext()]: {type: t, isVector: true};
			case [t = type()]: {type: t, isVector: false}; 
		}
	}

	function typeNext():FbsType {
		var fieldType:Null<FbsType> = null;
		while (true) {
			switch stream {
				case [t = type()]: fieldType = t;
				case [{def: TRBrack}]: break;
			}
		}
		return fieldType;
	}

}