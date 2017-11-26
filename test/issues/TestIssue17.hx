package issues;

import Test.TestHelper;
import dodrugs.Injector;
import utest.Assert;
import tink.core.Any;

@:keep
class TestIssue17 {
	public function new() {}

	function testUsingTinkCore() {
		// Importing tink.CoreApi will import tink.core.Any, and might conflict with our `Any` definition.
		// Previously this generated the error: `Any should be tink.core.Any`
		// The fact that this compiles is sufficient.
		var inj = Injector.create("TestIssue17", [
			var _:String = 'hello',
		]);
		Assert.equals("hello", inj.get(String));
	}
}
