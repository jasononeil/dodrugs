package dodrugs;

@:genericBuild(dodrugs.InjectorBuildMacro.build())
class Injector<Const> {
	/**
	Create a new Injector.

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
	Get the injection ID string for a particular type and or name.

	Valid formats include:

	- Standalone types: `Int`, `String` or `sys.db.Connection`
	- A type and a name: `(assetPath:String)`
	- A type with parameters, but no name: `(_:Option<Connecton>)`
	- A type with parameters and a name: `(db:Option<Connecton>)`

	@param typeExpr The expression describing the type.
	@return (String) The injection ID in the format `${fully.qualified.TypePath} ${name}` or `${fully.qualified.TypePath}`.
	**/
	public static macro function getInjectionId( typeExpr:haxe.macro.Expr ):haxe.macro.Expr {
		var id = InjectorMacro.getInjectionIdFromExpr( typeExpr );
		return macro $v{id};
	}

	/**
	Transform the mapping rule expression into the mapping function used at runtime.

	Valid formats:

	- `MyClass`
	- `Value(myValue)`
	- `Class(MyClass)`
	- `Singleton(MyClass)`
	- `Function(function(inj:Injector,mappingID:String):Any { ... })`
	**/
	public static macro function getInjectionMapping( mappingExpr:haxe.macro.Expr ):haxe.macro.Expr {
		return InjectorMacro.getInjectionMappingFromExpr( mappingExpr );
	}
}
