package testcases;

import dodrugs.*;

class MissingMapping2 {
	static function main() {
		var inj = Injector.create("app", [
			var age:Int = 28
		]);

		inj.get(var favouriteNumber: Int);
	}
}