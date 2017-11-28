package testcases;

import dodrugs.*;

class MissingMapping3 {
	static function main() {
		var inj = Injector.create("app", [
			var age:Int = 28
		]);

		inj.get(GetThing);
	}
}

class GetThing {
	public function new(name: String, age: Int) {}
}