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
}
