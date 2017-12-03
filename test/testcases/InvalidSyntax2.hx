package testcases;

import dodrugs.*;

class InvalidSyntax2 {
	static function main() {
		var inj = Injector.create("app", something);
	}

	static function something(y) {
		return y;
	}
}