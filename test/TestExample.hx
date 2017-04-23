import dodrugs.Injector;
import utest.Assert;
import Example;

@:keep
class TestExample {
	public function new() {}

	function testExampleRuns() {
		var injector = Example.setupInjector();
		var person = Example.buildPerson( injector );

		Assert.equals( "Jason", injector.get((name:String)) );
		Assert.equals( 28, injector.get((age:Int)) );
		Assert.equals( "Jason", person.name );
		Assert.equals( 28, person.age );
		Assert.same( [0,1,2], person.favouriteNumbers );
		Assert.same( [-1,3,366], person.leastFavouriteNumbers );
	}

	function testSecondInjector() {
		var inj = Injector.create( "test-example-2", [
			(name:String).toValue("Anna"),
			Int.withId("age").toValue(26),
			"Array<Int>".toValue([]),
			Person
		]);
		var person = inj.get( Person );

		Assert.equals( "Anna", person.name );
		Assert.equals( 26, person.age );
		Assert.same( [], person.favouriteNumbers );
		Assert.equals( null, person.leastFavouriteNumbers );
	}
}
