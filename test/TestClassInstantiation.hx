import utest.Assert;
import InjectionTestClasses;
import dodrugs.*;
import haxe.Http;

@:keep
class TestClassInstantiation {
	public function new() {}

	var http:Http;
	var array:Array<Int>;
	var array2:Array<Int>;
	var injector:Injector<"classInstantiationInjector">;
	var blankInjector:UntypedInjector;

	function setup() {
		http = new Http("/");
		array = [0,1,2];
		array2 = [-1,3,366];
		blankInjector = @:privateAccess new UntypedInjector( null, {} );
		injector = @:privateAccess new Injector( "classInstantiationInjector", null, {
			"StdTypes.Int age": function(i,_) return 28,
			"String name": function(i,_) return "Jason",
			"haxe.Http": function(i,_) return http,
			"Array<StdTypes.Int>": function(i,_) return array,
			"Array<StdTypes.Int> leastFavouriteNumbers": function(i,_) return array2,
			"dodrugs.UntypedInjector": function(i,_) return blankInjector,
		});
	}

	function testInstantiateClassWithConstructorInjection() {
		var mapping = Injector.getInjectionMapping(var _:InjectionTest_Constructor = @:toClass InjectionTest_Constructor);
		var result:InjectionTest_Constructor = mapping.mappingFn(injector, "");
		Assert.equals("Jason", result.name);
		Assert.equals(28, result.age);
		Assert.equals(http, result.httpRequest);
		Assert.equals(array, result.favouriteNumbers);
	}

	function testInstantiateSubClass() {
		var mapping = Injector.getInjectionMapping(var _:InjectionTest_Constructor_Subclass = @:toClass InjectionTest_Constructor_Subclass);
		var result:InjectionTest_Constructor_Subclass = mapping.mappingFn(injector, "");
		Assert.equals("Jason", result.name);
		Assert.equals(28, result.age);
		Assert.equals(http, result.httpRequest);
		Assert.equals(0, result.favouriteNumbers.length);
	}

	function testInstantiateClassWithDefaultValues() {
		var mapping = Injector.getInjectionMapping(var _:InjectionTest_DefaultValues = @:toClass InjectionTest_DefaultValues);
		var result:InjectionTest_DefaultValues = mapping.mappingFn(injector, "");
		Assert.equals("Felix", result.defaultConstructorString);
		Assert.equals(1, result.defaultConstructorInt);
		Assert.equals(null, result.defaultConstructorNull);
		Assert.equals(null, result.defaultConstructorOptional);
	}

	function testInjectingTheInjector() {
		var mapping = Injector.getInjectionMapping(var _:InjectionTest_InjectTheInjector = @:toClass InjectionTest_InjectTheInjector);
		var result:InjectionTest_InjectTheInjector = mapping.mappingFn(injector, "");
		Assert.equals(blankInjector, result.injectorInstance);
		Assert.equals(injector.name, result.injector.name);
	}
}
