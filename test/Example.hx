import dodrugs.*;

class Example {
	static function main() {
		var injector = setupInjector();
		var person = buildPerson( injector );
		trace( 'I am ${person.name}, I am ${person.age} years old and I have ${person.favouriteNumbers.length} favourite numbers' );
	}

	public static function setupInjector() {
		var array = [0,1,2];
		var array2 = [-1,3,366];
		return Injector.create( "exampleInjector", [
			var age:Int = 28,
			var name:String = "Jason",
			var _:Array<Int> = array,
			var leastFavouriteNumbers:Array<Int> = array2,
			var _:Person = @:toClass Person
		]);
	}

	public static inline function buildPerson(injector:Injector<"exampleInjector">) {
		return injector.get(var _:Person);
	}
}

class Person {
	public var name:String;
	public var age:Int;
	public var favouriteNumbers:Array<Int>;
	public var leastFavouriteNumbers:Null<Array<Int>>;

	public function new(name:String, age:Int, anArray:Array<Int>, ?leastFavouriteNumbers:Array<Int>) {
		this.name = name;
		this.age = age;
		this.favouriteNumbers = anArray;
		this.leastFavouriteNumbers = leastFavouriteNumbers;
	}
}
