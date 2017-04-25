import dodrugs.Injector;
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

	function getUfrontInjector<T>() {
		return Injector.create("ufront-app-injector", [
			var age:Int = 26,
		]);
	}
}
