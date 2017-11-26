package issues;

import dodrugs.*;

class TestIssue16_Main_2 {
	static function main() {
		var inj = Injector.create("exampleInjector", [
			var _:String = 28
		]);
	}
}