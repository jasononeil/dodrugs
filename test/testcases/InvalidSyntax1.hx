package testcases;

import dodrugs.*;

class InvalidSyntax1 {
	static function main() {
		var myVar = "my variable";
		var inj = Injector.create("app", [
			myVar
		]);
	}
}