package testcases;

import dodrugs.*;

class InvalidSyntax3 {
	static function main() {
		var inj = Injector.create("app", [
			var x:Int = 3,
			{other: "type"}
		]);
	}
}