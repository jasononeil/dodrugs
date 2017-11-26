package issues;

import dodrugs.*;

class TestIssue16_Main_5 {
	static function main() {
		var inj = Injector.create("exampleInjector", [
			var _:MyOtherClass = @:toClass MyTestClass
		]);
	}
}

class MyOtherClass {
    public function new() {}
}

class MyTestClass {
    public function new() {}
}