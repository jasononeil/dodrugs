import dodrugs.Injector;
import Example.Person;
import utest.Assert;

@:keep
class TestChildInjector {
	public function new() {}

	function testParentInjector() {
		var ufInjector = getUfrontInjector();
		var myInjector = getMyInjector(ufInjector);

		Assert.equals("Anna", myInjector.get(var name:String));
		Assert.equals(26, myInjector.get(var age:Int));
	}

	function getMyInjector(parent:Injector<"ufront-app-injector">) {
		return Injector.extend("my-app-injector", parent, [
			var name:String = "Anna"
		]);
	}

	function getUfrontInjector() {
		return Injector.create("ufront-app-injector", [
			var age:Int = 26,
		]);
	}

	function testQuickExtend() {
		var ufInjector = getUfrontInjector();
		var myInjector = ufInjector.quickExtend([
			var name: String = "Anna"
		]);

		Assert.equals("Anna", myInjector.get(var name:String));
		Assert.equals(26, myInjector.get(var age:Int));
	}

	function testParentNeedsChildMapping() {
		var parent = Injector.create('parent which needs child', [
			var _:Array<Int> = [1,2,3],
			Person
		]);
		var child1 = Injector.extend("child 1 which supplies parent", parent, [
			var age:Int = 30,
			var name:String = "Jason",
		]);
		var child2 = Injector.extend("child 2 which supplies parent", parent, [
			var age:Int = 27,
			var name:String = "Anna",
		]);
		var person1 = child1.get(Person);
		var person2 = child2.get(Person);
		Assert.equals('Jason', person1.name);
		Assert.equals('Anna', person2.name);
		Assert.equals(30, person1.age);
		Assert.equals(27, person2.age);
	}

	function testGetWith() {
		var ufInjector = getUfrontInjector();
		Assert.equals(26, ufInjector.get(var age:Int));

		var getWithResult = ufInjector.getWith(var age:Int, [
			var age:Int = 30
		]);
		Assert.equals(30, getWithResult);

		Assert.equals(26, ufInjector.get(var age:Int));
	}

	function testInstantiate() {
		var injWithNoPersonSupplied = Injector.create("test-instantiate-when-class-not-provided", [
			var age: Int = 30,
			var name: String = 'Jason',
			var _: Array<Int> = [1, 2, 3]
		]);
		var preSuppliedPerson = new Person('Anna', 27, [1, 2, 3]);
		var injWithPersonSupplied = Injector.create("test-instantiate-when-class-is-provided", [
			var age: Int = 30,
			var name: String = 'Jason',
			var _: Array<Int> = [1, 2, 3],
			var _:Person = preSuppliedPerson
		]);

		var person1 = injWithNoPersonSupplied.instantiate(Person);
		Assert.equals('Jason', person1.name);
		Assert.equals(30, person1.age);

		var person2 = injWithPersonSupplied.instantiate(Person);
		Assert.equals('Anna', person2.name);
		Assert.equals(27, person2.age);

	}
}
