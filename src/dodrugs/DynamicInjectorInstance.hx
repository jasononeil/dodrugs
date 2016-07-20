package dodrugs;

import tink.core.Any;

/**
DynamicInjectorInstance supplies the basic injection infrastructure to record mappings and provide values.

It is `Dynamic` in the sense that it doesn't hold any information about which injector you are using, and provides no compile-time safety for checking if a value is injected as expected.

In general you should use `Injector<"my_id">` instead of `DynamicInjector`.
**/
class DynamicInjectorInstance {
	var parent:Null<DynamicInjectorInstance>;
	var mappings:InjectorMappings;

	function new( parent:Null<DynamicInjectorInstance>, mappings:InjectorMappings ) {
		this.parent = parent;
		this.mappings = mappings;
		if ( !mappings.exists('dodrugs.DynamicInjectorInstance') )
			mappings.set( 'dodrugs.DynamicInjectorInstance', function(_,_) return this );
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
