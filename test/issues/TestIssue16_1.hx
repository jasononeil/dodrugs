package issues;

import dodrugs.*;

class TestIssue16_Main_1 {
	static function main() {
		var inj = Injector.create("exampleInjector", [
			var _:{age: Int} = 28
		]);
	}
}