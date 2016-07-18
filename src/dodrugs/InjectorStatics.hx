package dodrugs;

/**
These are the static methods available for `Injector`.

They can be used as:

```
Injector.create( name, [] );
Injector.extend( parent, name, [] );
Injector.getInjectionString( type );
Injector.getInjectionMapping( mappings );
```
**/
class InjectorStatics {
	/**
	Create a new Injector.

	For an explanation of the valid mapping formats, see the documentation for `getInjectionString` and `getInjectionMapping`.
	Example:

	```
	Injector.createInjector("uniqueName", [
	  Person,
	  GenericMailApi.toClass( SmtpApi ),
	  UploadApi.toSingleton( UploadApi ),
	  Connection.toValue( mysqlCnx )
	]);
	```

	@param name The name of this injector. This must be unique and created only once in the entire codebase.
	@param mappings An array of mapping expressions describing the mappings this injector will provide.
	@return An `Injector<$name>`, a unique type that extends `InjectorInstance` but safely provides the given mappings.
	**/
	@:noUsing
	public static macro function create( name:String, mappings:haxe.macro.Expr ):haxe.macro.Expr {
		var parent = macro null;
		return InjectorMacro.generateNewInjector( name, parent, mappings );
	}

	/**
	Create a new child Injector that falls back to the given parent Injector.
	**/
	@:noUsing
	public static macro function extend( name:String, parent:haxe.macro.Expr, mappings:haxe.macro.Expr ):haxe.macro.Expr {
		return InjectorMacro.generateNewInjector( name, parent, mappings );
	}

	/**
	Get the injection string for a particular type and or name.

	Valid formats include:

	- Using a type name directly: `String` becomes "String"
	- Using an imported type: `Manager` becomes "sys.db.Manager"
	- Using a full type path: `sys.db.Connection` becomes "sys.db.Connection"
	- Wrapping a type name in quotes: `"String"` becomes "String"
	- Using quotes for types with parameters: `"StringMap<Connection>"` becomes "haxe.ds.StringMap<sys.db.Connection>"

	You can then add a particular name to the ID:

	- `String.named('assetPath')` becomes "String assetPath"
	- `"StringBuf".named('output')` becomes "StringBuf output"
	- `sys.db.Connection.named('inputServer')` becomes "sys.db.Connection inputServer"
	- `"Array<Int>".named('favouriteNumbers')` becomes "Array<Int> favouriteNumbers"

	We also support the `ECheckType` syntax of `(name:type)`:

	- `(assetPath:String)` becomes "String assetPath"
	- `(db:Option<sys.db.Connection>)` becomes "haxe.ds.Option<sys.db.Connection> db"
	- `(_:StringMap<Int>)` becomes "haxe.ds.StringMap<StdTypes.Int>" (the "_" means no name).

	@param typeExpr The expression describing the type.
	@return (String) The injection ID in the format `${fully.qualified.TypePath} ${name}` or `${fully.qualified.TypePath}`.
	**/
	public static macro function getInjectionString( typeExpr:haxe.macro.Expr ):haxe.macro.Expr {
		var id = InjectorMacro.getInjectionStringFromExpr( typeExpr );
		return macro $v{id};
	}

	/**
	Process the injection mapping and return an object with the mapping ID and mapping function.

	Valid formats:

	- `MyClass`
	- `path.toMyClass`
	- `$mappingID.toClass( SomeClass )`
	- `$mappingID.toSingleton( SomeClass )`
	- `$mappingID.toValue( myValue )`
	- `$mappingID.toFunction( function(injector,id):Any {} )`

	Where `$mappingID` is any of the valid formats described in `getInjectionString`.

	@param The mapping expression.
	@return An object with the mapping details: `{ id:String, mappingFn:(Injector->String->Any) }`
	**/
	public static macro function getInjectionMapping( mappingExpr:haxe.macro.Expr ):haxe.macro.Expr {
		var mapping = InjectorMacro.processMappingExpr( null, mappingExpr );
		return macro { id:$v{mapping.field}, mappingFn:${mapping.expr} };
	}
}
