package testcases;

import dodrugs.*;

class InvalidSyntax3 {
	static function main() {
		var myface;
		var inj = Injector.create("app", [
			var x:Int = 3,
			myface
		]);
	}
}