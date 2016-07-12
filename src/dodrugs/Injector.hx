package dodrugs;

/**
The main class for setting up and interacting with an injector.

Because of the way we have set up the `@:genericBuild` macro, the API documentaton is split between `InjectorStatics` and `InjectorInstance`.

Static methods:

- `Injector.create()` - See `InjectorStatics.create()`
- `Injector.extend()` - See `InjectorStatics.extend()`
- `Injector.getInjectionId()` - See `InjectorStatics.getInjectionId()`
- `Injector.getInjectionMapping()` - See `InjectorStatics.getInjectionMapping()`

Instance methods:

- `myInjector.getFromID()` - See `InjectorInstance.getFromID()`
- `myInjector.tryGetFromID()` - See `InjectorInstance.tryGetFromID()`
- `myInjector.get()` - See `InjectorInstance.get()`
**/
@:genericBuild(dodrugs.InjectorBuildMacro.build())
class Injector<Const> {
	// Haxe 3.2 and Haxe 3.3 treat static macros on a @:genericBuild class differently.
	// In haxe 3.3, calling `Injector.create` will run @:genericBuild with no type params, and our macro will point it to InjectorStatics, where the `create` macro is found.
	// In haxe 3.2, calling `Injector.create` will not run @:genericBuild, but will attempt to run the macros on this class.
	// So we need the macros both here, and on InjectorStatics.
	// The API documentation is found on the InjectorStatics class.
	#if (haxe_ver <= 3.201)
		@:noUsing
		public static macro function create( name:String, mappings:haxe.macro.Expr ):haxe.macro.Expr {
			var parent = macro null;
			return InjectorMacro.generateNewInjector( name, parent, mappings );
		}

		@:noUsing
		public static macro function extend( name:String, parent:haxe.macro.Expr, mappings:haxe.macro.Expr ):haxe.macro.Expr {
			return InjectorMacro.generateNewInjector( name, parent, mappings );
		}

		public static macro function getInjectionId( typeExpr:haxe.macro.Expr ):haxe.macro.Expr {
			var id = InjectorMacro.getInjectionIdFromExpr( typeExpr );
			return macro $v{id};
		}

		public static macro function getInjectionMapping( mappingExpr:haxe.macro.Expr ):haxe.macro.Expr {
			var mapping = InjectorMacro.processMappingExpr( mappingExpr );
			return macro { id:$v{mapping.field}, mappingFn:${mapping.expr} };
		}
	#end
}
