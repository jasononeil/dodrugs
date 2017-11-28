package testcases;

import dodrugs.*;

class DuplicateInjectorName1 {
	static function main() {
		var inj1 = Injector.create("inj1", [
			var _:Int = 28
		]);

		var inj2 = Injector.create("inj2", [
			var _:Int = 28
		]);

		var inj3 = Injector.create("inj1", [
			var _:Int = 28
		]);
	}
}