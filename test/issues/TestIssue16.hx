package issues;

import Test.TestHelper;
import utest.Assert;

@:keep
class TestIssue16 {
	public function new() {}

	#if sys

	function testErrorMessageForValueMapping() {
		var result = TestHelper.attemptToCompile('issues/Issue16_1.hx');
		Assert.equals(1, result.code);
		Assert.stringContains('Int should be { age : Int }', result.stderr);

		var result = TestHelper.attemptToCompile('issues/Issue16_2.hx');
		Assert.equals(1, result.code);
		Assert.stringContains('Int should be String', result.stderr);

	}

	function testErrorMessageForFunctionMapping() {
		var result = TestHelper.attemptToCompile('issues/Issue16_3.hx');
		Assert.equals(1, result.code);
		Assert.stringContains('Int should be String', result.stderr);

		var result = TestHelper.attemptToCompile('issues/Issue16_4.hx');
		Assert.equals(1, result.code);
		Assert.stringContains('Int should be String', result.stderr);
	}

	function testErrorMessageForClassMapping() {
		var result = TestHelper.attemptToCompile('issues/Issue16_5.hx');
		Assert.equals(1, result.code);
		Assert.stringContains('issues.MyTestClass should be issues.MyOtherClass', result.stderr);

		var result = TestHelper.attemptToCompile('issues/Issue16_6.hx');
		Assert.equals(1, result.code);
		Assert.stringContains('issues.MyTestClass should be issues.MyOtherClass', result.stderr);
	}

	#end
}
