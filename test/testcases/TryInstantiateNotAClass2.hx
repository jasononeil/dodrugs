package testcases;

import dodrugs.*;

class TryInstantiateNotAClass2 {
	static function main() {
		var inj1 = Injector.create("inj1", [
			sys.db.Connection
		]);
	}
}