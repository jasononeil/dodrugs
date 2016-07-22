import utest.ui.Report;
import utest.Runner;

class Test {
	static function main() {
		var runner = new Runner();
		runner.addCase( new TestMacroUtils() );
		runner.addCase( new TestClassInstantiation() );
		runner.addCase( new TestSingletons() );
		runner.addCase( new TestChildInjector() );
		runner.addCase( new TestExample() );
		Report.create( runner );
		runner.run();
	}

	public function new() {}
}
