import utest.Assert;
import InjectionTestClasses;
import dodrugs.*;
import dodrugs.InjectorMapping;
import haxe.Http;
using tink.CoreApi;

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
		injector = @:privateAccess new InjectorInstance( null, [
			"StdTypes.Int age" => Value(28),
			"String name" => Value("Jason"),
			"haxe.Http" => Value(http),
			"Array<StdTypes.Int>" => Value(array),
			"Array<StdTypes.Int> leastFavouriteNumbers" => Value(array2),
		]);
	}

	function testInstantiateClassWithConstructorInjection() {
		var action = Injector.getInjectionMapping( Class(InjectionTest_Constructor) );
		switch action {
			case Function(fn):
				var result:InjectionTest_Constructor = fn( injector ).sure();
				Assert.equals( "Jason", result.name );
				Assert.equals( 28, result.age );
				Assert.equals( http, result.httpRequest );
				Assert.equals( array, result.favouriteNumbers );
			case _:
				Assert.fail( 'Expected action to be a Function()' );
		}
	}

	function testInstantiateSubClass() {
		var action = Injector.getInjectionMapping( Class(InjectionTest_Constructor_Subclass) );
		switch action {
			case Function(fn):
				var result:InjectionTest_Constructor_Subclass = fn( injector ).sure();
				Assert.equals( "Jason", result.name );
				Assert.equals( 28, result.age );
				Assert.equals( http, result.httpRequest );
				Assert.equals( 0, result.favouriteNumbers.length );
			case _:
				Assert.fail( 'Expected action to be a Function()' );
		}
	}

	function testInstantiateClassWithPropertyInjection() {
		var action = Injector.getInjectionMapping( Class(InjectionTest_Properties) );
		switch action {
			case Function(fn):
				var result:InjectionTest_Properties = fn( injector ).sure();
				Assert.equals( "Jason", result.name );
				Assert.equals( 28, result.age );
				Assert.equals( http, result.httpRequest );
				Assert.equals( array, result.favouriteNumbers );
			case _:
				Assert.fail( 'Expected action to be a Function()' );
		}
	}

	function testInstantiateClassWithMethodInjection() {
		var action = Injector.getInjectionMapping( Class(InjectionTest_Method) );
		switch action {
			case Function(fn):
				var result:InjectionTest_Method = fn( injector ).sure();
				Assert.equals( "Jason", result.name );
				Assert.equals( 28, result.age );
				Assert.equals( http, result.httpRequest );
				Assert.equals( array, result.favouriteNumbers );
			case _:
				Assert.fail( 'Expected action to be a Function()' );
		}
	}

	function testInstantiateClassWithPostInjection() {
		var action = Injector.getInjectionMapping( Class(InjectionTest_Post) );
		switch action {
			case Function(fn):
				var result:InjectionTest_Post = fn( injector ).sure();
				Assert.equals( 1, result.postCalled );
			case _:
				Assert.fail( 'Expected action to be a Function()' );
		}
	}

	function testInstantiateCombination() {
		var action = Injector.getInjectionMapping( Class(InjectionTest_Combination) );
		switch action {
			case Function(fn):
				var result:InjectionTest_Combination = fn( injector ).sure();
				Assert.equals( "Jason", result.name );
				Assert.equals( 28, result.age );
				Assert.equals( http, result.httpRequest );
				Assert.equals( array, result.favouriteNumbers );
				Assert.equals( 1, result.postCalled );
			case _:
				Assert.fail( 'Expected action to be a Function()' );
		}
	}

	function testInstantiateCombinationSubClass() {
		var action = Injector.getInjectionMapping( Class(InjectionTest_Combination_Subclass) );
		switch action {
			case Function(fn):
				var result:InjectionTest_Combination_Subclass = fn( injector ).sure();
				Assert.equals( "Jason", result.name );
				Assert.equals( 29, result.age );
				Assert.equals( http, result.httpRequest );
				Assert.same( [3,33,333], result.favouriteNumbers );
				Assert.same( [-1,3,366], result.leastFavouriteNumbers );
				Assert.equals( 2, result.postCalled );
			case _:
				Assert.fail( 'Expected action to be a Function()' );
		}
	}

	function testInstantiateClassWithDefaultValues() {
		var action = Injector.getInjectionMapping( Class(InjectionTest_DefaultValues) );
		switch action {
			case Function(fn):
				var result:InjectionTest_DefaultValues = fn( injector ).sure();
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
			case _:
				Assert.fail( 'Expected action to be a Function()' );
		}
	}
}
