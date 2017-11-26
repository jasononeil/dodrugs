import utest.Assert;
import Example.Person;
import dodrugs.*;

@:keep
class TestSingletons {
	public function new() {}

	function testClassSingleton() {
		var injector = Injector.create("singleton test", [
			var age:Int = 28,
			var name:String = "Jason",
			var _:Array<Int> = [1,2,3],
			var leastFavouriteNumbers:Array<Int> = [7,13,21],
			var classMapping:Person = @:toClass Person,
			var singletonMapping:Person = @:toSingletonClass Person
		]);

		var p1 = injector.get(var classMapping:Person);
		var p2 = injector.get(var classMapping:Person);
		Assert.notEquals(p1, p2);
		var p3 = injector.get(var singletonMapping:Person);
		var p4= injector.get(var singletonMapping:Person);
		Assert.equals(p3, p4);
	}

	function testSingletonOnChildInjector() {
		var parent = Injector.create("singleton test parent", [
			var age:Int = 28,
			var name:String = "Jason",
			var _:Array<Int> = [1,2,3],
			var leastFavouriteNumbers:Array<Int> = [7,13,21],
			Person
		]);
		var child1 = Injector.extend("singleton test child 1", parent, [
			Group
		]);
		var child2 = Injector.extend("singleton test child 2", parent, [
			Group
		]);

		// The singleton should belong to the injector it was mapped on.

		// "Person" was mapped on the parent, so both children should use the same singleton.
		var p1 = child1.get(var p:Person);
		var p2 = child2.get(var p:Person);
		Assert.equals(p1, p2);

		// "Group" was mapped on the children, so each child should have a separate singleton.
		var g1a = child1.get(var g:Group);
		var g1b = child1.get(var g:Group);
		var g2a = child2.get(var g:Group);
		var g2b = child2.get(var g:Group);
		Assert.equals(g1a, g1b);
		Assert.equals(g2a, g2b);
		Assert.notEquals(g1a, g2a);
	}
}

class Group {
	public function new() {}
}