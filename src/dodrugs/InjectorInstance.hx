package dodrugs;

import tink.core.Any;

/**
InjectorInstance is the implementation class used for each `Injector`.

Every time you see a `Injector<"name">`, it will be an InjectorInstance object.

To create a new InjectorInstance, use `Injector.create()` or `Injector.extend()`.
See `InjectorStatics` for documentation.
**/
class InjectorInstance {
	public var name(default,null):String;
	var parent:Null<InjectorInstance>;
	var mappings:InjectorMappings;

	function new( name:String, parent:Null<InjectorInstance>, mappings:InjectorMappings ) {
		this.name = name;
		this.parent = parent;
		this.mappings = mappings;
		// Map a copy of the injector itself, if it doesn't already exist
		if ( !mappings.exists('dodrugs.NamedInjectorInstance<"$name">') )
			mappings.set( 'dodrugs.NamedInjectorInstance<"$name">', function(_,_) return this );
	}

	/**
	Retrieve a value based on the current injector mappings.

	@param id The string identifier representing the mapping you wish to retrieve.
	@return The value supplied by the injector mapping. It is typed as `Any`, which can then be cast into the relevant type.
	@throws (String) An error message if no mapping was found for this ID.
	**/
	public inline function getFromID( id:String ):Any {
		return _get( id );
	}

	function _get( id:String ):Any {
		return
			if ( mappings.exists(id) ) mappings[id]( this, id )
			else if ( this.parent!=null ) this.parent.getFromID( id )
			else throw 'The injection had no mapping for "$id"';
	}

	/**
	Retrieve a value based on the current injector mappings, and if no mapping is found, use the fallback value.

	@param id The string identifier representing the mapping you wish to retrieve.
	@return The value supplied by the injector mapping, or if no mapping was found, the fallback value. The return value will have the same type as the fallback value.
	**/
	public inline function tryGetFromID<T>( id:String, fallback:T ):T {
		return _tryGet( id, fallback );
	}

	function _tryGet( id:String, fallback:Any ):Any {
		return
			try getFromID( id )
			catch (e:Dynamic) fallback;
	}

	function _getSingleton( mapping:InjectorMapping<Any>, id:String ):Any {
		var val = mapping( this, id );
		mappings[id] = function(_, _) return val;
		return val;
	}

	// Macro helpers

	/**
	Get a value from the injector.

	This essentially is a shortcut for:

	`injector.getFromID( Injector.getInjectionString(MyClass) );`

	@param typeExpr The object to request. See `InjectorStatics.getInjectionString()` for a description of valid formats.
	@return The requested object, with all injections applied. The return object will be correctly typed as the type you are requesting.
	@throws (String) An error if the injection cannot be completed.
	**/
	public macro function get( ethis:haxe.macro.Expr, typeExpr:haxe.macro.Expr ):haxe.macro.Expr {
		var injectionString = InjectorMacro.getInjectionStringFromExpr( typeExpr );
		var complexType = InjectorMacro.getComplexTypeFromIdExpr( typeExpr );
		// Get the Injector ID based on the current type of "this", and mark the current injection string as "required".
		switch haxe.macro.Context.typeof(ethis) {
			case TInst( _, [TInst(_.get() => { kind: KExpr({ expr: EConst(CString(injectorID)) }) },[])] ):
				InjectorMacro.markInjectionStringAsRequired( injectorID, injectionString, typeExpr.pos );
			case _:
		}

		return macro ($ethis.getFromID($v{injectionString}):$complexType);
	}
}
