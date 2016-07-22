import haxe.Http;

class InjectionTest_Constructor {
	public var name(default,null):String;
	public var age(default,null):Int;
	public var httpRequest(default,null):Http;
	public var favouriteNumbers(default,null):Array<Int>;

	@inject("name","age","","")
	public function new( name:String, age:Int, httpRequest:Http, favouriteNumbers:Array<Int> ) {
		this.name = name;
		this.age = age;
		this.httpRequest = httpRequest;
		this.favouriteNumbers = favouriteNumbers;
	}
}

class InjectionTest_Constructor_Subclass extends InjectionTest_Constructor {
	@inject("name","age","")
	public function new( name:String, age:Int, httpRequest:Http ) {
		super( name, age, httpRequest, [] );
	}
}

class InjectionTest_Properties {
	@inject("name") public var name:String;
	@inject("age") public var age:Int;
	@inject public var httpRequest:Http;
	@inject public var favouriteNumbers:Array<Int>;

	public function new() {}
}

class InjectionTest_Method {
	public var name(default,null):String;
	public var age(default,null):Int;
	public var httpRequest(default,null):Http;
	public var favouriteNumbers(default,null):Array<Int>;

	public function new() {}

	@inject("name","age","","")
	public function injectData( name:String, age:Int, httpRequest:Http, favouriteNumbers:Array<Int> ) {
		this.name = name;
		this.age = age;
		this.httpRequest = httpRequest;
		this.favouriteNumbers = favouriteNumbers;
	}
}

class InjectionTest_Post {
	public var postCalled = 0;
	public function new() {}

	@post
	public function doThisAfterInjection() {
		postCalled++;
	}
}

class InjectionTest_Combination {
	@inject("name") public var name:String;
	public var age(default,null):Int;
	public var httpRequest(default,null):Http;
	public var favouriteNumbers(default,null):Array<Int>;
	public var postCalled = 0;

	@inject
	public function new( favouriteNumbers:Array<Int> ) {
		this.favouriteNumbers = favouriteNumbers;
	}

	@inject("age")
	public function injectAge( age:Int ) {
		this.age = age;
	}

	@inject
	public function injectHttp( http:Http ) {
		this.httpRequest = http;
	}

	@post
	public function doThisAfterInjection() {
		postCalled++;
	}
}

class InjectionTest_Combination_Subclass extends InjectionTest_Combination {
	public var leastFavouriteNumbers(default,null):Array<Int>;

	@inject("leastFavouriteNumbers")
	public function new( leastFavouriteNumbers:Array<Int> ) {
		super( [3,33,333] );
		this.leastFavouriteNumbers = leastFavouriteNumbers;
	}

	@inject("age")
	override public function injectAge( age:Int ) {
		this.age = age + 1;
	}

	@post
	public function alsoDoThisAfterInjection() {
		postCalled++;
	}
}

class InjectionTest_DefaultValues {
	@inject("notfound1") public var defaultPropertyString = "Felix";
	@inject("notfound2") public var defaultPropertyInt = 1;
	@inject("notfound3") public var defaultPropertyNull:Null<Http>;
	public var defaultConstructorString:String;
	public var defaultConstructorInt:Int;
	public var defaultConstructorNull:Null<Http>;
	public var defaultConstructorOptional:Null<Http>;
	public var defaultMethodString:String;
	public var defaultMethodInt:Int;
	public var defaultMethodNull:Null<Http>;
	public var defaultMethodOptional:Null<Http>;

	@inject("notfound4","notfound5","notfound6","notfound7")
	public function new( str:String="Felix", int:Int=1, nullValue:Null<Http>, ?optionalValue:Http ) {
		this.defaultConstructorString = str;
		this.defaultConstructorInt = int;
		this.defaultConstructorNull = nullValue;
		this.defaultConstructorOptional = optionalValue;
	}

	@inject("notfound8","notfound9","notfound10","notfound11")
	public function injectData( str:String="Felix", int:Int=1, nullValue:Null<Http>, ?optionalValue:Http ) {
		this.defaultMethodString = str;
		this.defaultMethodInt = int;
		this.defaultMethodNull = nullValue;
		this.defaultMethodOptional = optionalValue;
	}
}

class InjectionTest_InjectTheInjector {
	@inject public var injectorInstance:dodrugs.DynamicInjector;
	@inject public var injector:dodrugs.Injector<"classInstantiationInjector">;
	public function new() {}
}
