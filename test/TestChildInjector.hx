import dodrugs.Injector;
import utest.Assert;

@:keep
class TestChildInjector {
	public function new() {}

	function testUfrontScenario() {
		// I want to test the use case for Ufront.
		// A library defined "ufront-app-injector", which extends a user defined "my-app-injector".
		// So the library injector extends an injector it has no knowledge of.
		var myInjector = getMyInjector();
		var ufInjector = getUfrontInjector( myInjector );

		Assert.equals( "Anna", ufInjector.get(String.named("name")) );
		Assert.equals( 26, ufInjector.get(Int.named("age")) );
	}

	function getMyInjector() {
		return Injector.create( "my-app-injector", [
			(name:String).toValue("Anna"),
		]);
	}

	function getUfrontInjector( parent ) {
		return Injector.extend( "ufront-app-injector", parent, [
			Int.named("age").toValue(26),
		]);
	}
}
