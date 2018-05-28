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
			'String': function (inj, id) return 'wildcard fallback',
			'singleton': function (inj:UntypedInjector, id:String) {
				@:privateAccess return inj._getSingleton(inj, function (inj, id) {
					return {num: "3.14159"};
				}, id);
			}
		});
		childInj = @:privateAccess new UntypedInjector(parentInj, {
			'Array<StdTypes.Int>': function (inj, id) return [1,2,3],
			'integer': function (inj, id) return 5,
			'string': function (inj, id) return "O'Neil",
			'String withName': function (inj, id) return 'named injection'
		});
	}

	function testItMapsItself() {
		Assert.equals(childInj, childInj.getFromId('dodrugs.UntypedInjector'));
		Assert.equals(parentInj, parentInj.getFromId('dodrugs.UntypedInjector'));
	}

	function testGetFromId() {
		// Check basic usage, with child holding different to parent.
		Assert.equals(0, parentInj.getFromId('integer'));
		Assert.equals(5, childInj.getFromId('integer'));
		Assert.equals("jason", parentInj.getFromId('string'));
		Assert.equals("O'Neil", childInj.getFromId('string'));
		// Check that if it does not exist, it throws.
		Assert.raises(function () parentInj.getFromId('Array<StdTypes.Int>'), String);
		// And a child can add one that is not on the parent.
		Assert.same([1,2,3], childInj.getFromId('Array<StdTypes.Int>'));
		// Check that the mapping functions are passed the injector and ID.
		var result1:{inj:UntypedInjector, id:String} = parentInj.getFromId('self');
		Assert.equals(parentInj, result1.inj);
		Assert.equals('self', result1.id);
		// Check that if a child lacks a mapping, it falls back to the parent.
		// Note: the mapping function will be called with the injector that made the request (so the child, not the parent).
		// This means result1 != result2.
		var result2:{inj:UntypedInjector, id:String} = childInj.getFromId('self');
		Assert.equals(childInj, result2.inj);
		Assert.equals('self', result2.id);
		// Check fallback to wildcard mapping.
		Assert.equals('wildcard fallback', parentInj.getFromId('String withName'));
		Assert.equals('named injection', childInj.getFromId('String withName'));
	}

	function testTryGetFromId() {
		Assert.same([10,20,30], parentInj.tryGetFromId('Array<StdTypes.Int>', [10,20,30]));
		Assert.same([1,2,3], childInj.tryGetFromId('Array<StdTypes.Int>', [10,20,30]));
	}

	function testGetSingletonWhenParentCalledFirst() {
		// When a parent is called first, singletons are scoped to it and all future children
		// (We may add such functionality in future, see https://github.com/jasononeil/dodrugs/issues/11)
		var obj1:{num:String} = parentInj.getFromId('singleton');
		var obj2:{num:String} = childInj.getFromId('singleton');
		Assert.equals(obj1, obj2);
		Assert.equals("3.14159", obj1.num);
	}

	function testGetSingletonWhenChildCalledFirst() {
		// When a singleton is loaded on a child before it is loaded on a parent, it is scoped to itself
		// (We may add such functionality in future, see https://github.com/jasononeil/dodrugs/issues/11)
		var obj1:{num:String} = childInj.getFromId('singleton');
		var obj2:{num:String} = parentInj.getFromId('singleton');
		Assert.notEquals(obj1, obj2);
		Assert.equals("3.14159", obj1.num);
		Assert.equals("3.14159", obj2.num);
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
