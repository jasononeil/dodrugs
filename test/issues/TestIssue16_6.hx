package issues;

import dodrugs.*;

class TestIssue16_6 {
	static function main() {
		var inj = Injector.create("exampleInjector", [
			var _:MyOtherClass = @:toSingletonClass MyTestClass
		]);
	}
}

class MyOtherClass {
    public function new() {}
}

class MyTestClass {
    public function new() {}
}