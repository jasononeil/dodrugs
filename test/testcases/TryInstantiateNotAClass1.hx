package testcases;

import dodrugs.*;

class TryInstantiateNotAClass1 {
	static function main() {
		var inj1 = Injector.create("inj1", [
			haxe.CallStack.StackItem
		]);
	}
}