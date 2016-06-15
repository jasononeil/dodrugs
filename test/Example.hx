import dodrugs.*;

import haxe.DynamicAccess;

class Example {
	static function main() {
		var injector = setupInjector();
		var action = Injector.getInjectionMapping( Class(Person) );
		var person:Person = action( injector, "" );
		trace( 'I am ${person.name}, I am ${person.age} years old and I have ${person.favouriteNumbers.length} favourite numbers' );
	}

	static function setupInjector() {
		var array = [0,1,2];
		var array2 = [-1,3,366];
		var rules:DynamicAccess<InjectorMapping<tink.core.Any>> = {
			"StdTypes.Int age": function(i,_) return 28,
			"String name": function(i,_) return "Jason",
			"Array<StdTypes.Int>": function(i,_) return array,
			"Array<StdTypes.Int> leastFavouriteNumbers": function(i,_) return array2,
		};
		return @:privateAccess new InjectorInstance( null, rules );
	}
}

class Person {
	public var ready = false;
	public var name:String;
	@inject("age") public var age:Int;
	public var favouriteNumbers:Array<Int>;
	@inject("leastFavouriteNumbers") public var leastFavouriteNumbers:Array<Int>;

	@inject("name")
	public function new( name:String ) {
		this.name = name;
	}

	@inject
	public function setFavouriteNumbers( arr:Array<Int> ) {
		this.favouriteNumbers = arr;
	}

	@post
	public function afterInjection() {
		this.ready = true;
	}
}
