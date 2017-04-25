import dodrugs.Injector;
import utest.Assert;
import Example;

@:keep
class TestExample {
	public function new() {}

	function testExampleRuns() {
		var injector = Example.setupInjector();
		var person = Example.buildPerson(injector);

		Assert.equals("Jason", injector.get(var name:String));
		Assert.equals(28, injector.get(var age:Int));
		Assert.equals("Jason", person.name);
		Assert.equals(28, person.age);
		Assert.same([0,1,2], person.favouriteNumbers);
		Assert.same([-1,3,366], person.leastFavouriteNumbers);

		// Check that this was picked up as a singleton.
		var person2 = Example.buildPerson(injector);
		Assert.equals(person, person2);
	}

	function testSecondInjector() {
		var arr = [];
		var inj = Injector.create( "test-example-2", [
			var name:String = "Anna",
			var age:Int = 26,
			var _:Array<Int> = arr,
			@:toClass Person
		]);
		var person = inj.get(var _:Person);

		Assert.equals("Anna", person.name);
		Assert.equals(26, person.age);
		Assert.same([], person.favouriteNumbers);
		// Because leastFavouriteNumbers is not supplied, it will supply the wildcard "_:Array<Int>"
		// So both favouriteNumbers and leastFavouriteNumbers will end up with the same value.
		Assert.same([], person.leastFavouriteNumbers);
		Assert.equals(person.favouriteNumbers, person.leastFavouriteNumbers);

		// Check that this was treated as a @:toClass not @:toSingleton
		var person2 = inj.get(Person);
		Assert.notEquals(person, person2);
	}
}
