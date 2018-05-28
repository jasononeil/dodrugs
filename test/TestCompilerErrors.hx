import Test.TestHelper;
import utest.Assert;

@:keep
class TestCompilerErrors {
	public function new() {}

	#if sys

	function testDuplicateInjectorName() {
		var result = TestHelper.attemptToCompile('testcases/DuplicateInjectorName1.hx');
		Assert.equals(1, result.code);
		Assert.stringContains('An Injector named "inj1" was previously created here', result.stderr);
		Assert.stringContains('And a different Injector named "inj1" is being created here', result.stderr);
		Assert.stringContains('Error: duplicate Injector name used', result.stderr);

		var result = TestHelper.attemptToCompile('testcases/DuplicateInjectorName2.hx');
		Assert.equals(1, result.code);
		Assert.stringContains('An Injector named "parent_and_child\" was previously created here', result.stderr);
		Assert.stringContains('And a different Injector named "parent_and_child\" is being created here', result.stderr);
		Assert.stringContains('Error: duplicate Injector name used', result.stderr);
	}

	function testMapAClassThatIsNotAClass() {
		var result = TestHelper.attemptToCompile('testcases/TryInstantiateNotAClass1.hx');
		Assert.equals(1, result.code);
		Assert.stringContains('haxe.CallStack.StackItem is not a class', result.stderr);

		var result = TestHelper.attemptToCompile('testcases/TryInstantiateNotAClass2.hx');
		Assert.equals(1, result.code);
		Assert.stringContains('The type Connection has no constructor', result.stderr);
	}

	function testMissingMappings() {
		var result = TestHelper.attemptToCompile('testcases/MissingMapping1.hx');
		Assert.equals(1, result.code);
		Assert.stringContains('Mapping "String" is required here', result.stderr);
		Assert.stringContains('Please make sure you provide a mapping for "String" here', result.stderr);

		var result = TestHelper.attemptToCompile('testcases/MissingMapping2.hx');
		Assert.equals(1, result.code);
		Assert.stringContains('Mapping "StdTypes.Int with ID favouriteNumber" is required here', result.stderr);
		Assert.stringContains('Please make sure you provide a mapping for "StdTypes.Int with ID favouriteNumber" here', result.stderr);

		var result = TestHelper.attemptToCompile('testcases/MissingMapping3.hx');
		Assert.equals(1, result.code);
		Assert.stringContains('Mapping "testcases.MissingMapping3.GetThing" is required here', result.stderr);
		Assert.stringContains('Please make sure you provide a mapping for "testcases.MissingMapping3.GetThing" here', result.stderr);
	}

	function testInvalidMappingSyntax() {
		var result = TestHelper.attemptToCompile('testcases/InvalidSyntax1.hx');
		Assert.equals(1, result.code);
		Assert.stringContains('Failed to understand type notMyVar', result.stderr);
		Assert.stringContains('Perhaps use the format `var notMyVar:MyType = notMyVar`', result.stderr);
		Assert.stringContains('Unknown identifier : notMyVar', result.stderr);

		var result = TestHelper.attemptToCompile('testcases/InvalidSyntax2.hx');
		Assert.equals(1, result.code);
		Assert.stringContains('Injector rules should be provided using Array syntax, with each mapping being an array item.', result.stderr);

		var result = TestHelper.attemptToCompile('testcases/InvalidSyntax3.hx');
		Assert.equals(1, result.code);
		Assert.stringContains('Failed to understand type myface', result.stderr);
		Assert.stringContains('Perhaps use the format `var myface:MyType = myface`', result.stderr);
		Assert.stringContains('Unknown type for myface', result.stderr);
	}

	function testWrongMappingTypes() {
		var result = TestHelper.attemptToCompile('issues/Issue16_1.hx');
		Assert.equals(1, result.code);
		Assert.stringContains('Int should be { age : Int }', result.stderr);
	}
	#end
}
