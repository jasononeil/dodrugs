package issues;

import dodrugs.*;

class TestIssue16_Main_4 {
	static function main() {
		var inj = Injector.create("exampleInjector", [
			var _:String = @:toSingletonFunction function (inj, id) return 28
		]);
	}
}