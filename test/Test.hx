import utest.ui.Report;
import utest.Runner;

class Test {
	static function main() {
		var runner = new Runner();
		runner.addCase( new MacroUtils() );
		runner.addCase( new ClassInstantiation() );
		Report.create( runner );
		runner.run();
	}

	public function new() {}
}
