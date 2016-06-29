import utest.Assert;
import dodrugs.Injector;
import dodrugs.InjectorMapping;
import dodrugs.InjectorInstance;
import haxe.ds.ArraySort;
import haxe.ds.StringMap;
using tink.CoreApi;

@:keep
class MacroUtils {
	public function new() {}

	function testInjectionIDs() {
		// Test Injection IDs for standard types.
		Assert.equals( "String", Injector.getInjectionId(String) );
		Assert.equals( "StdTypes.Int", Injector.getInjectionId(Int) );
		Assert.equals( "StringBuf", Injector.getInjectionId(StringBuf) );
		Assert.equals( "StdTypes.Int", Injector.getInjectionId("Int") );
		Assert.equals( "StringBuf", Injector.getInjectionId("StringBuf") );
		// Test injection IDs for types in packages.
		Assert.equals( "haxe.ds.ArraySort", Injector.getInjectionId(ArraySort) );
		Assert.equals( "haxe.crypto.Sha1", Injector.getInjectionId(haxe.crypto.Sha1) );
		// Test injection IDs that have type parameters
		Assert.equals( "Array<String>", Injector.getInjectionId("Array<String>") );
		Assert.equals( "haxe.ds.StringMap<StdTypes.Int>", Injector.getInjectionId("StringMap<Int>") );
		// Test injection IDs that have a name
		Assert.equals( "haxe.ds.ArraySort quicksort", Injector.getInjectionId(ArraySort.named("quicksort")) );
		Assert.equals( "haxe.crypto.Sha1 myhash", Injector.getInjectionId(haxe.crypto.Sha1.named("myhash")) );
		Assert.equals( "StdTypes.Int sessionExpiry", Injector.getInjectionId(Int.named("sessionExpiry")) );
		Assert.equals( "Array<StdTypes.Int> magicNumbers", Injector.getInjectionId("Array<Int>".named("magicNumbers")) );
		// Test the `ECheckType` syntax:
		Assert.equals( "StringBuf", Injector.getInjectionId((_:StringBuf)) );
		Assert.equals( "Array<String>", Injector.getInjectionId((_:Array<String>)) );
		Assert.equals( "StdTypes.Int sessionExpiry", Injector.getInjectionId((sessionExpiry:Int)) );
		Assert.equals( "Array<StdTypes.Int> magicNumbers", Injector.getInjectionId((magicNumbers:Array<Int>)) );
	}

	function testUniqueNames() {
		var i1:Injector<"test_1"> = null;
		var i2:Injector<"test_1"> = null;
		var i3:Injector<"test_2"> = null;
		var i4:InjectorInstance = null;
		var i5 = Injector.create( "test_1", [] );

		Assert.equals( "dodrugs.InjectorInstance", Type.getClassName(Type.getClass(i5)) );
		Assert.equals( "test_1", i5.name );

		// Compile Time Error:
		// var i6 = Injector.create( "test_1", [] );
	}

	function testGetInjectionMapping() {
		var result = Injector.getInjectionMapping( Int.toValue(3600) );
		Assert.same( "StdTypes.Int", result.id );
		Assert.same( 3600, result.mappingFn(null,"") );

		var fn = function(inj,id) return null;
		var result = Injector.getInjectionMapping( "Array<Int>".named("test").toFunction(fn) );
		Assert.equals( "Array<StdTypes.Int> test", result.id );
		Assert.equals( fn, result.mappingFn );

		// Just test these don't throw errors.
		// We'll check the class instantiation functions in `ClassInstantiation.hx`
		var result = Injector.getInjectionMapping( Test.toClass(Test) );
		var result = Injector.getInjectionMapping( haxe.remoting.Connection.toSingleton(haxe.remoting.HttpConnection) );
	}
}
