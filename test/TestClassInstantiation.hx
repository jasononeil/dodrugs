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
			"String.String name": function(i,_) return "Jason",
			"haxe.Http.Http": function(i,_) return http,
			"Array.Array<StdTypes.Int>": function(i,_) return array,
			"Array.Array<StdTypes.Int> leastFavouriteNumbers": function(i,_) return array2,
			"dodrugs.DynamicInjector.DynamicInjector": function(i,_) return blankInjector,
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

	function testInstantiateClassWithDefaultValues() {
		var mapping = Injector.getInjectionMapping( InjectionTest_DefaultValues );
		var result:InjectionTest_DefaultValues = mapping.mappingFn( injector, "" );
		Assert.equals( "Felix", result.defaultConstructorString );
		Assert.equals( 1, result.defaultConstructorInt );
		Assert.equals( null, result.defaultConstructorNull );
		Assert.equals( null, result.defaultConstructorOptional );
	}

	function testInjectingTheInjector() {
		var mapping = Injector.getInjectionMapping( InjectionTest_InjectTheInjector );
		var result:InjectionTest_InjectTheInjector = mapping.mappingFn( injector, "" );
		Assert.equals( blankInjector, result.injectorInstance );
		Assert.equals( injector.name, result.injector.name );
	}
}
