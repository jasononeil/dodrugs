package dodrugs;

import tink.CoreApi;

class InjectorInstance {
	var parent:Null<InjectorInstance>;
	var mappings:InjectorMappings;

	function new( parent:Null<InjectorInstance>, mappings:InjectorMappings ) {
		this.parent = parent;
		this.mappings = mappings;
	}

	public function getValueFromMappingID( id:String ):Outcome<Any,Error> {
		if ( mappings.exists(id) ) {
			return processMapping( id, mappings[id] );
		}
		else if ( this.parent!=null ) {
			return this.parent.getValueFromMappingID( id );
		}
		else {
			return Failure( new Error('The injector had no mapping for "$id"') );
		}
	}

	public function getOptionalValueFromMappingID( id:String, fallback:Any ):Any {
		return switch getValueFromMappingID( id ) {
			case Success(v): v;
			case Failure(_): fallback;
		}
	}

	function processMapping( id:String, mapping:InjectorMapping<Any> ):Outcome<Any,Error> {
		switch mapping {
			case Value( val ):
				return Success( val );
			case Function( fn ):
				return fn( this );
			case Singleton( fn ):
				switch fn( this ) {
					case Success( singleton ):
						mappings[id] = InjectorMapping.Value( singleton );
						return Success( singleton );
					case Failure( err ):
						return Failure( err );
				}
		}
	}
}
