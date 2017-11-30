package dodrugs;

/**
Injector is a macro powered dependency injector.

### Setting up an injector

You create a new Injector using `Injector.create()` or `Injector.extend()`.

- Each injector has a unique name, for example `Injector<"my_app">`.
- Each injector can only be created once in your entire code base.
- The mappings must be provided when `Injector.create()` or `Injector.extend()` is called. You cannot modify the mappings later.

This way the compiler knows exactly which mappings are available for `Injector<"my_app">`, and it will let you know if you try to use mappings that aren't available.

### Injection Strings

At runtime, we store injector mappings as strings.

These strings are usually made up of the type name, a space, and then name used for this mapping.
The type name includes the package, the module name, and the type name.
For example, a String with the ID "sessionName" will use the injection string "String.String sessionName".
And an Int with the ID "sessionExpiry" will use the injection string "StdTypes.Int sessionExpiry".

All of the type parameters are included in the injection strings.
For example "Array.Array<StdTypes.Int> favouriteNumbers".

The type names are fully qualified, and include the module name.
For example instead of "Connection dbCnx" we would get "sys.db.Connection.Connection dbCnx".

If the injection mapping is just for the type, without a specific name, we just use the typename.
For example, "String.String", "StdTypes.Int", "Array.Array<StdTypes.Int>" or "sys.db.Connection.Connection".

### Generating Injection Strings

These strings can be used directly, for example, in `UntypedInjector.getFromId()`.
But usually, you will want to use special macro-powered syntax.

Valid formats include:

- Using a type name directly: `String` becomes "String.String"
- Using an imported type: `Manager` becomes "sys.db.Manager.Manager"
- Using a full type path: `sys.db.Connection` becomes "sys.db.Connection.Connection"
- Wrapping a type name in quotes: `"String"` becomes "String.String"
- Using quotes for types with parameters: `"StringMap<Connection>"` becomes "haxe.ds.StringMap.StringMap<sys.db.Connection.Connection>"

You can then add a particular name to the ID:

- `String.withId('assetPath')` becomes "String assetPath"
- `"StringBuf".withId('output')` becomes "StringBuf output"
- `sys.db.Connection.withId('inputServer')` becomes "sys.db.Connection inputServer"
- `"Array<Int>".withId('favouriteNumbers')` becomes "Array<Int> favouriteNumbers"

We also support the `ECheckType` syntax of `(name:type)`:

- `(assetPath:String)` becomes "String assetPath"
- `(db:Option<sys.db.Connection>)` becomes "haxe.ds.Option<sys.db.Connection> db"
- `(_:StringMap<Int>)` becomes "haxe.ds.StringMap<StdTypes.Int>" (the "_" means no name).

Please note for the ECheckType syntax you need to wrap the expression in brackets, as shown above.

### Injection Mappings

You can set up the mappings for your injector in both `Injector.create()` and `Injector.extend()`.

Valid formats:

- `MyClass` - map a class to itself.
- `path.toMyClass` - map a class to itself using the full class path.
- `$mappingString.toClass( SomeClass )` - map a class.
- `$mappingString.toSingleton( SomeClass )` - map a singleton.
- `$mappingString.toValue( myValue )` - map a value.
- `$mappingString.toFunction( function(injector,id):Any {} )` - map a function.

Where `$mappingString` is any of the valid formats described above in "Generating Injection Strings".

### Example

```haxe
var appInjector = Injector.create( "my_app", [
	Person,
	GenericMailApi.toClass( SmtpApi ),
	UploadApi.toSingleton( UploadApi ),
	Connection.toValue( mysqlCnx )
] );
$type(appInjector); // Injector<"my_app">
var person = appInjector.get( Person );
var mailApi = appInjector.get( "myapp.api.GenericMailApi" );
var uploadApiSingleton = appInjector.get( UploadApi );
var cnx = appInjector.get( sys.db.Connection );

// Now let's build a child injector.
var context = getCurrentHttpContext();
var requestInjector = Injector.extend( "current_request", appInjector, [
	HttpContext.toValue( context ),
	HttpRequest.toValue( context.httpRequest ),
	HttpResponse.toValue( context.httpResponse ),
	UFHttpSession.toValue( context.currentSession ),
	UFAuthUser.toValue( context.currentUser ),
	String.withId("userId").toValue( context.currentUserId )
] );
$type(appInjector); // Injector<"current_request">
requestInjector.get( String.withId("userId") );
requestInjector.get( (userId:String) );
requestInjector.get( Person ); // from the parent injector.
```

**/
#if !macro
	@:build(dodrugs.InjectorMacro.buildInjector())
#end
class Injector<Const> extends UntypedInjector {

	/**
	Create a new Injector with the given name and mappings.

	@param name The name of this injector. This must be unique and created only once in the entire codebase.
	@param mappings An array of mapping expressions describing the mappings this injector will provide. See the documentation above.
	@return An `Injector<$name>`, a unique type that extends `UntypedInjector` but safely provides the given mappings.
	**/
	@:noUsing
	public static macro function create( name:String, mappings:haxe.macro.Expr ):haxe.macro.Expr {
		var parent = macro null;
		return InjectorMacro.generateNewInjector( name, parent, mappings );
	}

	/**
	Create a new child Injector, which falls back to the parent injector when a mapping is not found.

	@param name The name of this injector. This must be unique and created only once in the entire codebase.
	@param parent The injector that will be used as the parent. Please note this must be the parent `Injector` object, not the name of the parent injector.
	@param mappings An array of mapping expressions describing the mappings this injector will provide. See the documentation above.
	@return An `Injector<$name>`, a unique type that extends `UntypedInjector` but safely provides the given mappings.
	**/
	@:noUsing
	public static macro function extend( name:String, parent:haxe.macro.Expr, mappings:haxe.macro.Expr ):haxe.macro.Expr {
		return InjectorMacro.generateNewInjector( name, parent, mappings );
	}

	/**
	Get the injection string for a particular type.

	See "Generating Injection Strings" in the documentation above for a list of valid syntaxes.

	@param typeExpr The expression describing the type.
	@return (String) The injection ID in the format `${fully.qualified.TypePath} ${name}` or `${fully.qualified.TypePath}`.
	**/
	public static macro function getInjectionString( typeExpr:haxe.macro.Expr ):haxe.macro.Expr {
		var id = InjectorMacro.getInjectionStringFromExpr( typeExpr );
		return macro $v{id};
	}

	/**
	Process the injection mapping and return an object with the mapping ID and mapping function.

	@param mappingExpr The mapping expression.
	@return An object with the mapping details: `{ id:String, mappingFn:InjectorMapping }`
	**/
	public static macro function getInjectionMapping( mappingExpr:haxe.macro.Expr ):haxe.macro.Expr {
		var mapping = InjectorMacro.processMappingExpr( null, mappingExpr );
		return macro { id:$v{mapping.field}, mappingFn:${mapping.expr} };
	}

	/**
	The unique name/ID of this injector.
	**/
	public var name(default,null):String;

	function new( name:String, parent:Null<UntypedInjector>, mappings:InjectorMappings ) {
		super( parent, mappings );
		this.name = name;
		if ( !mappings.exists('dodrugs.Injector.Injector<"$name">') )
			mappings.set( 'dodrugs.Injector.Injector<"$name">', function(_,_) return this );
	}

	#if macro
	static var temporaryId = 0;
	#end

	/**
	If you would like to extend an Injector and use it immediately, and don't care about using it later, you can use `quickExtend()`.

	This will return a new child injector, with additional mappings ready to use.

	The unique injector name is automatically generated, making it inconvenient to use this in a separate function at a later time - it's designed to be extended and used immediately.

	@param mappings An array of mapping expressions describing the mappings this injector will provide. See the documentation above.
	@return An `Injector<$temporary_name>`, a unique injector that extends the parent with a few extra mappings.
	**/
	public macro function quickExtend(ethis:haxe.macro.Expr, mappings: haxe.macro.Expr): haxe.macro.Expr {
		return InjectorMacro.generateNewInjector( '__dodrugs_temporary_injector_${temporaryId++}', ethis, mappings);
	}

	/**
	Quickly extend an injector with extra mappings, and then make a `get()` request.

	This is useful if you would like to add one or two extra mappings required for a particular injection to be successful, or to customise an injection just this once.

	@param typeExpr The object to request. See `InjectorStatics.getInjectionString()` for a description of valid formats.
	@param extraMappings An array of extra mappings to use while fetching the requested type.
	@return The requested object, with all injections applied. The return object will be correctly typed as the type you are requesting.
	**/
	public macro function getWith(ethis: haxe.macro.Expr, typeExpr: haxe.macro.Expr, extraMappings:haxe.macro.Expr): haxe.macro.Expr {
		var newInjector = InjectorMacro.generateNewInjector( '__dodrugs_temporary_injector_${temporaryId++}', ethis, extraMappings);
		return macro $newInjector.get($typeExpr);
	}

	/**
	Instantiate a specific class using the values in the injector.

	The difference between using `instantiate()` as opposed to `get()` is that if a mapping does not already exist, a `quickExtend()` child injector will be created with a rule to instantiate the requested class.

	@param typeExpr The class you are requesting an instance of. Providing anything other than a class (such as an interface, a value, a function etc) will result in unspecified behaviour.
	@return An instance of the requested class, with all injections applied. The return object will be correctly typed as the type you are requesting.
	**/
	public macro function instantiate(ethis: haxe.macro.Expr, typeExpr: haxe.macro.Expr): haxe.macro.Expr {
		var injectionString = InjectorMacro.getInjectionStringFromExpr(typeExpr);
		var ct = InjectorMacro.getComplexTypeFromIdExpr(typeExpr);
		var ifAlreadyThere = macro (@:privateAccess $ethis.mappings).exists($v{injectionString});
		// Note, we use `getFromId` rather than `get` to avoid setting metadata saying that we require the mapping here, as we do not - if it's not there we extend and supply ourselves.
		var getExisting = macro ($ethis.getFromId($v{injectionString}): $ct);
		var getWithNewMapping = macro $ethis.getWith($typeExpr, [$typeExpr]);
		return macro $ifAlreadyThere ? $getExisting : $getWithNewMapping;
	}

	/**
	Instantiate a specific class using the values in the injector, as well as some extra mappings.

	This is essentially the same as calling `injector.quickExtend([...extraMappings]).instantiate(MyClass);`

	@param typeExpr The class you are requesting an instance of. Providing anything other than a class (such as an interface, a value, a function etc) will result in unspecified behaviour.
	@param extraMappings An array of extra mappings to use while instantiating the requested class.
	@return An instance of the requested class, with all injections applied. The return object will be correctly typed as the type you are requesting.
	**/
	public macro function instantiateWith(ethis: haxe.macro.Expr, typeExpr: haxe.macro.Expr, extraMappings: haxe.macro.Expr): haxe.macro.Expr {
		var newInjector = InjectorMacro.generateNewInjector( '__dodrugs_temporary_injector_${temporaryId++}', ethis, extraMappings);
		return macro $newInjector.instantiate($typeExpr);
	}
}
