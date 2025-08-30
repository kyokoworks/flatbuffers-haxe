
package fbs;

enum FbsPrimitiveType {
	TBool;
	TByte;
	TUByte;
	TShort;
	TUShort;
	TInt;
	TUInt;
	TFloat;
	TLong;
	TULong;
	TDouble;
	TString;
}

enum FbsType {
	TPrimitive(t:FbsPrimitiveType);
	TComposite(t:String);
}

enum FbsPropertyName {
	TIdentifier(s:String);
	TStringLiteral(s:String);
	TNumericLiteral(s:String);
}

enum FbsScalar {
  TBoolConstant(s:String);
  TIntegerConstant(s:String);
  TFloatConstant(s:String);
}

enum FbsValue {
	VScalar(s:FbsScalar);
	VString(s:String);
	VObject(obj:Array<{key:String, value:FbsValue}>);
	VArray(arr:Array<FbsValue>);
}

typedef FbsMetadataEntry = {
	key: String,
	value: Null<FbsValue>
}

typedef FbsMetadata = Array<FbsMetadataEntry>;

typedef FbsEnum = {
	name: String,
	type: FbsType,
	ctors: Array<FbsEnumCtor>,
	metadata: FbsMetadata
}

typedef FbsEnumCtor = {
	name: FbsPropertyName,
	value: Null<String>,
	metadata: FbsMetadata
}

typedef FbsUnion = {
	name: String,
	values: Array<String>,
	metadata: FbsMetadata
}
typedef FbsStruct = {
	name: String,
	fields: Array<FbsStructField>,
	metadata: FbsMetadata
}

typedef FbsStructField = {
	name: String,
	type: FbsType,
	metadata: FbsMetadata
}

typedef FbsTable = {
	name: String,
	fields: Array<FbsTableField>,
	metadata: FbsMetadata
}

typedef FbsTableField = {
	name: String,
	type: FbsType,
	isVector: Bool,
	defaultValue: Null<String>,
	metadata: FbsMetadata
}

enum FbsDeclaration {
	DNamespace(ns:Array<String>);
	DEnum(en:FbsEnum);
	DUnion(un:FbsUnion);
	DStruct(str:FbsStruct);
	DTable(tb:FbsTable);
	DRootType(rt:Array<String>);
}