package dodrugs;

import tink.core.Any;

class InjectorInstance {
	public var name(default,null):String;
	var parent:Null<InjectorInstance>;
	var mappings:InjectorMappings;

	function new( name:String, parent:Null<InjectorInstance>, mappings:InjectorMappings ) {
		this.name = name;
		this.parent = parent;
		this.mappings = mappings;
	}

	public inline function getFromID( id:String ):Any {
		return _get( id );
	}

	function _get( id:String ):Any {
		return
			if ( mappings.exists(id) ) mappings[id]( this, id )
			else if ( this.parent!=null ) this.parent.getFromID( id )
			else throw 'The injection had no mapping for "$id"';
	}

	public inline function tryGetFromID( id:String, fallback:Any ):Any {
		return _tryGet( id, fallback );
	}

	function _tryGet( id:String, fallback:Any ):Any {
		return
			try getFromID( id )
			catch (e:Dynamic) fallback;
	}

	function _getSingleton( mapping:InjectorMapping<Any>, id:String ):Any {
		var val = mappings[id]( this, id );
		mappings[id] = function(_, _) return val;
		return val;
	}

	// Macro helpers

	/**
	Get a value from the injector.

	This essentially is a shortcut for:

	`injector.getFromID( Injector.getInjectionID(MyClass) );`

	@param request The object to request. See `Injector.getInjectionId()` for a description of valid formats.
	@return The requested object, with all injections applied.
	@throws (String) An error if the injection cannot be completed.
	**/
	public macro function get( ethis:haxe.macro.Expr, typeExpr:haxe.macro.Expr ):haxe.macro.Expr {
		var id = InjectorMacro.getInjectionIdFromExpr( typeExpr );
		var complexType = InjectorMacro.getComplexTypeFromIdExpr( typeExpr );
		return macro ($ethis.getFromID($v{id}):$complexType);
	}
}
