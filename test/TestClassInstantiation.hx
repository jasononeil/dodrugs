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
	var blankInjector:DynamicInjector;

	function setup() {
		http = new Http( "/" );
		array = [0,1,2];
		array2 = [-1,3,366];
		blankInjector = @:privateAccess new DynamicInjector( null, {} );
		injector = @:privateAccess new Injector( "classInstantiationInjector", null, {
			"StdTypes.Int age": function(i,_) return 28,
			"String name": function(i,_) return "Jason",
			"haxe.Http": function(i,_) return http,
			"Array<StdTypes.Int>": function(i,_) return array,
			"Array<StdTypes.Int> leastFavouriteNumbers": function(i,_) return array2,
			"dodrugs.DynamicInjector": function(i,_) return blankInjector,
		});
	}

	function testInstantiateClassWithConstructorInjection() {
		var mapping = Injector.getInjectionMapping( InjectionTest_Constructor );
		var result:InjectionTest_Constructor = mapping.mappingFn( injector, "" );
		Assert.equals( "Jason", result.name );
		Assert.equals( 28, result.age );
		Assert.equals( http, result.httpRequest );
		Assert.equals( array, result.favouriteNumbers );
	}

	function testInstantiateSubClass() {
		var mapping = Injector.getInjectionMapping( InjectionTest_Constructor_Subclass );
		var result:InjectionTest_Constructor_Subclass = mapping.mappingFn( injector, "" );
		Assert.equals( "Jason", result.name );
		Assert.equals( 28, result.age );
		Assert.equals( http, result.httpRequest );
		Assert.equals( 0, result.favouriteNumbers.length );
	}

	function testInstantiateClassWithPropertyInjection() {
		var mapping = Injector.getInjectionMapping( InjectionTest_Properties );
		var result:InjectionTest_Properties = mapping.mappingFn( injector, "" );
		Assert.equals( "Jason", result.name );
		Assert.equals( 28, result.age );
		Assert.equals( http, result.httpRequest );
		Assert.equals( array, result.favouriteNumbers );
	}

	function testInstantiateClassWithMethodInjection() {
		var mapping = Injector.getInjectionMapping( InjectionTest_Method );
		var result:InjectionTest_Method = mapping.mappingFn( injector, "" );
		Assert.equals( "Jason", result.name );
		Assert.equals( 28, result.age );
		Assert.equals( http, result.httpRequest );
		Assert.equals( array, result.favouriteNumbers );
	}

	function testInstantiateClassWithPostInjection() {
		var mapping = Injector.getInjectionMapping( InjectionTest_Post );
		var result:InjectionTest_Post = mapping.mappingFn( injector, "" );
		Assert.equals( 1, result.postCalled );
	}

	function testInstantiateCombination() {
		var mapping = Injector.getInjectionMapping( InjectionTest_Combination );
		var result:InjectionTest_Combination = mapping.mappingFn( injector, "" );
		Assert.equals( "Jason", result.name );
		Assert.equals( 28, result.age );
		Assert.equals( http, result.httpRequest );
		Assert.equals( array, result.favouriteNumbers );
		Assert.equals( 1, result.postCalled );
	}

	function testInstantiateCombinationSubClass() {
		var mapping = Injector.getInjectionMapping( InjectionTest_Combination_Subclass );
		var result:InjectionTest_Combination_Subclass = mapping.mappingFn( injector, "" );
		Assert.equals( "Jason", result.name );
		Assert.equals( 29, result.age );
		Assert.equals( http, result.httpRequest );
		Assert.same( [3,33,333], result.favouriteNumbers );
		Assert.same( [-1,3,366], result.leastFavouriteNumbers );
		Assert.equals( 2, result.postCalled );
	}

	function testInstantiateClassWithDefaultValues() {
		var mapping = Injector.getInjectionMapping( InjectionTest_DefaultValues );
		var result:InjectionTest_DefaultValues = mapping.mappingFn( injector, "" );
		Assert.equals( "Felix", result.defaultPropertyString );
		Assert.equals( 1, result.defaultPropertyInt );
		Assert.equals( null, result.defaultPropertyNull );
		Assert.equals( "Felix", result.defaultConstructorString );
		Assert.equals( 1, result.defaultConstructorInt );
		Assert.equals( null, result.defaultConstructorNull );
		Assert.equals( null, result.defaultConstructorOptional );
		Assert.equals( "Felix", result.defaultMethodString );
		Assert.equals( 1, result.defaultMethodInt );
		Assert.equals( null, result.defaultMethodNull );
		Assert.equals( null, result.defaultMethodOptional );
	}

	function testInjectingTheInjector() {
		var mapping = Injector.getInjectionMapping( InjectionTest_InjectTheInjector );
		var result:InjectionTest_InjectTheInjector = mapping.mappingFn( injector, "" );
		Assert.equals( blankInjector, result.injectorInstance );
		Assert.equals( injector.name, result.injector.name );
	}
}
