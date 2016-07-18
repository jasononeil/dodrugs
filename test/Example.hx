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
			Person,
			Int.named("age").toValue(28),
			(name:String).toValue("Jason"),
			"Array<Int>".toValue(array),
			"Array<Int>".named("leastFavouriteNumbers").toValue(array2),
		]);
	}

	public static function buildPerson( injector:Injector<"exampleInjector"> ) {
		return injector.get( Person );
	}
}

class Person {
	public var ready = false;
	public var name:String;
	@inject("age") public var age:Int;
	public var favouriteNumbers:Array<Int>;
	@inject("leastFavouriteNumbers") public var leastFavouriteNumbers:Null<Array<Int>>;

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
