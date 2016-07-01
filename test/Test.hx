import utest.ui.Report;
import utest.Runner;

class Test {
	static function main() {
		var runner = new Runner();
		runner.addCase( new MacroUtils() );
		runner.addCase( new ClassInstantiation() );
		runner.addCase( new TestSingletons() );
		runner.addCase( new TestExample() );
		Report.create( runner );
		runner.run();
	}

	public function new() {}
}
