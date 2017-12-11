package issues;

import dodrugs.Injector;
import utest.Assert;

@:keep
// Incorrect behaviour: if we try to instantiate "MyDb", when a mapping is definitely provided,
// it will still generate code to instantiate "MyDb" and all of it's dependencies, but will fail
// to instantiate "Connection" because it is an interface, not a class.
//
// Expected behaviour: if a mapping is provided, use that mapping and don't try to isntantiate the
// interface.
class TestIssue20 {
	public function new() {}

	function testWhenDbIsProvided() {
		var myDb = new MyDb(new MyConnection());
		var inj = Injector.create("TestIssue20a", [
			var _:MyDb = myDb
		]);
		Assert.equals("Done", inj.instantiate(MyDb).run());
	}

	function testWhenConnectionIsProvided() {
		var cnx = new MyConnection();
		var inj = Injector.create("TestIssue20b", [
			var cnx:Connection = cnx
		]);
		Assert.equals("Done", inj.instantiate(MyDb).run());
	}
}

class MyDb {
	var cnx: Connection;
	public function new(cnx: Connection) {
		this.cnx = cnx;
	}

	public function run() return this.cnx.run();
}

interface Connection {
	public function run(): String;
}

class MyConnection implements Connection {
	public function new() {}
	public function run() return 'Done';
}