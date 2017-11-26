package issues;

import dodrugs.*;

class TestIssue16_Main_3 {
	static function main() {
		var inj = Injector.create("exampleInjector", [
			var _:String = @:toFunction function (inj, id) return 28
		]);
	}
}