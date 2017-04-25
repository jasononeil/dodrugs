import dodrugs.UntypedInjector;
import utest.Assert;

@:keep
class TestUntypedInjector {

	var parentInj:UntypedInjector;
	var childInj:UntypedInjector;

	public function new() {}

	function setup() {
		parentInj = @:privateAccess new UntypedInjector(null, {
			'integer': function (inj, id) return 0,
			'string': function (inj, id) return 'jason',
			'self': function (inj, id) return {inj: inj, id: id},
			'String.String': function (inj, id) return 'wildcard fallback',
			'singleton': function (inj:UntypedInjector, id:String) {
				@:privateAccess return inj._getSingleton(function (inj, id) {
					return {num: "3.14159"};
				}, id);
			}
		});
		childInj = @:privateAccess new UntypedInjector(parentInj, {
			'Array.Array<StdTypes.Int>': function (inj, id) return [1,2,3],
			'integer': function (inj, id) return 5,
			'string': function (inj, id) return "O'Neil",
			'String.String withName': function (inj, id) return 'named injection'
		});
	}

	function testItMapsItself() {
		Assert.equals(childInj, childInj.getFromId('dodrugs.UntypedInjector.UntypedInjector'));
		Assert.equals(parentInj, parentInj.getFromId('dodrugs.UntypedInjector.UntypedInjector'));
	}

	function testGetFromId() {
		// Check basic usage, with child holding different to parent.
		Assert.equals(0, parentInj.getFromId('integer'));
		Assert.equals(5, childInj.getFromId('integer'));
		Assert.equals("jason", parentInj.getFromId('string'));
		Assert.equals("O'Neil", childInj.getFromId('string'));
		// Check that if it does not exist, it throws.
		Assert.raises(function () parentInj.getFromId('Array.Array<StdTypes.Int>'), String);
		// And a child can add one that is not on the parent.
		Assert.same([1,2,3], childInj.getFromId('Array.Array<StdTypes.Int>'));
		// Check that the mapping functions are passed the injector and ID.
		var result1:{inj:UntypedInjector, id:String} = parentInj.getFromId('self');
		Assert.equals(parentInj, result1.inj);
		Assert.equals('self', result1.id);
		// Check that if a child lacks a mapping, it falls back to the parent.
		var result2:{inj:UntypedInjector, id:String} = childInj.getFromId('self');
		Assert.same(result1, result2);
		// Check fallback to wildcard mapping.
		Assert.equals('wildcard fallback', parentInj.getFromId('String.String withName'));
		Assert.equals('named injection', childInj.getFromId('String.String withName'));
	}

	function testTryGetFromId() {
		Assert.same([10,20,30], parentInj.tryGetFromId('Array.Array<StdTypes.Int>', [10,20,30]));
		Assert.same([1,2,3], childInj.tryGetFromId('Array.Array<StdTypes.Int>', [10,20,30]));
	}

	function testGetSingleton() {
		// Test that the child also uses the same singleton as the parent.
		// We don't want the child creating it's own singleton, and the parent doing that.
		// (We may add such functionality in future, see https://github.com/jasononeil/dodrugs/issues/11)
		var obj1:{num:String} = childInj.getFromId('singleton');
		var obj2:{num:String} = parentInj.getFromId('singleton');
		Assert.equals(obj1, obj2);
		Assert.equals("3.14159", obj1.num);
	}

	function testGet() {
		// These are mostly tested in parts by other things, so we'll just test the two basic syntaxes.
		Assert.equals('wildcard fallback', parentInj.get(String));
		Assert.equals('wildcard fallback', parentInj.get(var _:String));
		Assert.equals('wildcard fallback', parentInj.get(var withName:String));
		Assert.equals('wildcard fallback', childInj.get(String));
		Assert.equals('wildcard fallback', childInj.get(var _:String));
		Assert.equals('named injection', childInj.get(var withName:String));
		Assert.equals(childInj, childInj.get(UntypedInjector));
		Assert.equals(parentInj, parentInj.get(dodrugs.UntypedInjector));
		Assert.equals(childInj, childInj.get(var someName:UntypedInjector));
		Assert.equals(parentInj, parentInj.get(var someName:dodrugs.UntypedInjector));
	}

	function testTryGet() {
		Assert.same([10,20,30], parentInj.tryGet(var _:Array<Int>, [10,20,30]));
		Assert.same([1,2,3], childInj.tryGet(var _:Array<Int>, [10,20,30]));

		Assert.notNull(parentInj.tryGet(UntypedInjector, null));
		Assert.isNull(parentInj.tryGet(StringBuf, null));
	}
}
