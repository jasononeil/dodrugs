import utest.Assert;
import InjectionTestClasses;
import dodrugs.*;
import dodrugs.InjectorMapping;
import haxe.Http;
using tink.CoreApi;

@:keep
class ClassInstantiation {
	public function new() {}

	var http:Http;
	var array:Array<Int>;
	var array2:Array<Int>;
	var injector:InjectorInstance;

	function setup() {
		http = new Http( "/" );
		array = [0,1,2];
		array2 = [-1,3,366];
		injector = @:privateAccess new InjectorInstance( null, {
			"StdTypes.Int age": function(i,_) return 28,
			"String name": function(i,_) return "Jason",
			"haxe.Http": function(i,_) return http,
			"Array<StdTypes.Int>": function(i,_) return array,
			"Array<StdTypes.Int> leastFavouriteNumbers": function(i,_) return array2,
		});
	}

	function testInstantiateClassWithConstructorInjection() {
		var action = Injector.getInjectionMapping( Class(InjectionTest_Constructor) );
		var result:InjectionTest_Constructor = action( injector, "" );
		Assert.equals( "Jason", result.name );
		Assert.equals( 28, result.age );
		Assert.equals( http, result.httpRequest );
		Assert.equals( array, result.favouriteNumbers );
	}

	function testInstantiateSubClass() {
		var action = Injector.getInjectionMapping( Class(InjectionTest_Constructor_Subclass) );
		var result:InjectionTest_Constructor_Subclass = action( injector, "" );
		Assert.equals( "Jason", result.name );
		Assert.equals( 28, result.age );
		Assert.equals( http, result.httpRequest );
		Assert.equals( 0, result.favouriteNumbers.length );
	}

	function testInstantiateClassWithPropertyInjection() {
		var action = Injector.getInjectionMapping( Class(InjectionTest_Properties) );
		var result:InjectionTest_Properties = action( injector, "" );
		Assert.equals( "Jason", result.name );
		Assert.equals( 28, result.age );
		Assert.equals( http, result.httpRequest );
		Assert.equals( array, result.favouriteNumbers );
	}

	function testInstantiateClassWithMethodInjection() {
		var action = Injector.getInjectionMapping( Class(InjectionTest_Method) );
		var result:InjectionTest_Method = action( injector, "" );
		Assert.equals( "Jason", result.name );
		Assert.equals( 28, result.age );
		Assert.equals( http, result.httpRequest );
		Assert.equals( array, result.favouriteNumbers );
	}

	function testInstantiateClassWithPostInjection() {
		var action = Injector.getInjectionMapping( Class(InjectionTest_Post) );
		var result:InjectionTest_Post = action( injector, "" );
		Assert.equals( 1, result.postCalled );
	}

	function testInstantiateCombination() {
		var action = Injector.getInjectionMapping( Class(InjectionTest_Combination) );
		var result:InjectionTest_Combination = action( injector, "" );
		Assert.equals( "Jason", result.name );
		Assert.equals( 28, result.age );
		Assert.equals( http, result.httpRequest );
		Assert.equals( array, result.favouriteNumbers );
		Assert.equals( 1, result.postCalled );
	}

	function testInstantiateCombinationSubClass() {
		var action = Injector.getInjectionMapping( Class(InjectionTest_Combination_Subclass) );
		var result:InjectionTest_Combination_Subclass = action( injector, "" );
		Assert.equals( "Jason", result.name );
		Assert.equals( 29, result.age );
		Assert.equals( http, result.httpRequest );
		Assert.same( [3,33,333], result.favouriteNumbers );
		Assert.same( [-1,3,366], result.leastFavouriteNumbers );
		Assert.equals( 2, result.postCalled );
	}

	function testInstantiateClassWithDefaultValues() {
		var action = Injector.getInjectionMapping( Class(InjectionTest_DefaultValues) );
		var result:InjectionTest_DefaultValues = action( injector, "" );
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
}
