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
}
