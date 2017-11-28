import utest.ui.Report;
import utest.Runner;
import issues.*;
using haxe.io.Path;

class Test {
	static function main() {
		var runner = new Runner();
		runner.addCase( new TestUntypedInjector() );
		runner.addCase( new TestMacroUtils() );
		runner.addCase( new TestClassInstantiation() );
		runner.addCase( new TestSingletons() );
		runner.addCase( new TestChildInjector() );
		runner.addCase( new TestExample() );
		runner.addCase( new TestIssue17() );

		// Compilation errors - we test these by running the Haxe compiler, so they're only available on sys platforms.
		#if sys
		runner.addCase( new TestIssue16() );
		runner.addCase( new TestCompilerErrors() );
		#end

		Report.create( runner );
		runner.run();
	}

	public function new() {}
}

class TestHelper {
	public static function attemptToCompile(file: String): {code: Int, stdout: String, stderr: String} {
		#if sys
		var process = new sys.io.Process('haxe', [
			'-lib', 'tink_macro',
			'-cp', 'test/',
			'-cp', 'src',
			'--interp', file
		]);
		var code = process.exitCode(true);
		var stdout = process.stdout.readAll().toString();
		var stderr = process.stderr.readAll().toString();
		return {
			code: code,
			stderr: stderr,
			stdout: stdout,
		};
		#end
	}
}