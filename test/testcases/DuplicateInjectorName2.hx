package testcases;

import dodrugs.*;

class DuplicateInjectorName2 {
	static function main() {
		var inj1 = Injector.create("parent_and_child", [
			var _:Int = 28
		]);

		var inj2 = Injector.create("parent2", [
			var _:Int = 28
		]);

		var inj3 = Injector.extend("parent_and_child", inj2, [
			var _:Int = 28
		]);
	}
}