package testcases;

import dodrugs.*;

class MissingMapping1 {
	static function main() {
		var inj = Injector.create("app", [
			var _:Int = 28
		]);

		inj.get(String);
	}
}