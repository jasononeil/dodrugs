import dodrugs.Injector;
import utest.Assert;

@:keep
class TestChildInjector {
	public function new() {}

	function testParentInjector() {
		var ufInjector = getUfrontInjector();
		var myInjector = getMyInjector(ufInjector);

		Assert.equals( "Anna", myInjector.get(String.named("name")) );
		Assert.equals( 26, myInjector.get(Int.named("age")) );
	}

	function getMyInjector(parent:Injector<"ufront-app-injector">) {
		return Injector.extend( "my-app-injector", parent, [
			(name:String).toValue("Anna"),
		]);
	}

	function getUfrontInjector<T>() {
		return Injector.create( "ufront-app-injector", [
			Int.named("age").toValue(26),
		]);
	}
}
