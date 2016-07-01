import utest.Assert;
import Example.Person;
import dodrugs.*;

@:keep
class TestSingletons {
	public function new() {}

	function testSingleton() {
		var injector = Injector.create( "singleton test", [
			( age:Int ).toValue( 28 ),
			( name:String ).toValue( "Jason" ),
			( _:Array<Int> ).toValue( [1,2,3] ),
			( leastFavouriteNumbers:Array<Int> ).toValue( [7,13,21] ),
			Person.named( "class mapping" ).toClass( Person ),
			Person.named( "singleton mapping" ).toSingleton( Person )
		] );

		var p1 = injector.get( Person.named("class mapping") );
		var p2 = injector.get( Person.named("class mapping") );
		Assert.notEquals( p1, p2 );
		var p3 = injector.get( Person.named("singleton mapping") );
		var p4= injector.get( Person.named("singleton mapping") );
		Assert.equals( p3, p4 );
	}
}
