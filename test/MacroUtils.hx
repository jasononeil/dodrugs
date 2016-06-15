import utest.Assert;
import dodrugs.Injector;
import dodrugs.InjectorMapping;
import haxe.ds.ArraySort;
using tink.CoreApi;

@:keep
class MacroUtils {
	public function new() {}

	function testInjectionIDs() {
		Assert.equals( "String", Injector.getInjectionId(String) );
		Assert.equals( "StdTypes.Int", Injector.getInjectionId(Int) );
		Assert.equals( "StringBuf", Injector.getInjectionId(StringBuf) );
		Assert.equals( "haxe.ds.ArraySort", Injector.getInjectionId(ArraySort) );
		Assert.equals( "haxe.crypto.Sha1", Injector.getInjectionId(haxe.crypto.Sha1) );
		Assert.equals( "StdTypes.Int sessionExpiry", Injector.getInjectionId((sessionExpiry:Int)) );
		Assert.equals( "Array<String>", Injector.getInjectionId((_:Array<String>)) );
		Assert.equals( "Array<StdTypes.Int> magicNumbers", Injector.getInjectionId((magicNumbers:Array<Int>)) );
	}

	function testUniqueNames() {
		var i1:Injector<"test_1"> = null;
		var i2:Injector<"test_1"> = null;
		var i3:Injector<"test_2"> = null;
		var i4:Injector<Dynamic> = null;
		var i5 = Injector.create( "test_1", [] );

		Assert.equals( "dodrugs.instances.InjectorInstance_test_1", Type.getClassName(Type.getClass(i5)) );

		// Compile Time Error:
		// var i6 = Injector.create( "test_1", [] );
	}

	function testMapValue() {
		var val = Injector.getInjectionMapping( Value(3600) );
		Assert.same( 3600, val(null,"") );

		var fn = function(inj,id) return inj.getValueFromMappingID("test");
		var val = Injector.getInjectionMapping( Function(fn) );
		Assert.equals( fn, val );

		// Just test these don't throw errors.
		// We'll check the class instantiation functions in `ClassInstantiation.hx`
		var val = Injector.getInjectionMapping( Class(Test) );
		var val = Injector.getInjectionMapping( Singleton(Test) );
	}
}
