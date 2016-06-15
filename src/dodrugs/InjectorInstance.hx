package dodrugs;

import tink.core.Any;

class InjectorInstance {
	var parent:Null<InjectorInstance>;
	var mappings:InjectorMappings;

	function new( parent:Null<InjectorInstance>, mappings:InjectorMappings ) {
		this.parent = parent;
		this.mappings = mappings;
	}

	public function getValueFromMappingID( id:String ):Any {
		return
			if ( mappings.exists(id) ) mappings[id]( this, id )
			else if ( this.parent!=null ) this.parent.getValueFromMappingID( id )
			else throw 'The injection had no mapping for "$id"';
	}

	public function getOptionalValueFromMappingID( id:String, fallback:Any ):Any {
		return
			try getValueFromMappingID( id )
			catch (e:Dynamic) fallback;
	}

	function getSingleton( mapping:InjectorMapping<Any>, id:String ):Any {
		var val = mappings[id]( this, id );
		mappings[id] = function(_, _) return val;
		return val;
	}

	// Macro helpers

	/**
	Get a value from the injector.

	This essentially is a shortcut for:

	`injector.getValueFromMappingID( Injector.getInjectionID(MyClass) );`

	@param request The object to request. See `Injector.getInjectionId()` for a description of valid formats.
	@return The requested object, with all injections applied.
	@throws (String) An error if the injection cannot be completed.

	TODO: Support a `var cnx:Connection = injector.get()` format using Context.getExpectedType().
	**/
	public macro function get( ethis:haxe.macro.Expr, typeExpr:haxe.macro.Expr ):haxe.macro.Expr {
		var id = InjectorMacro.getInjectionIdFromExpr( typeExpr );
		var complexType = InjectorMacro.getComplexTypeFromIdExpr( typeExpr );
		return macro ($ethis.getValueFromMappingID($v{id}):$complexType);
	}
}
