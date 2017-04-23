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

class InjectionTest_DefaultValues {
	public var defaultConstructorString:String;
	public var defaultConstructorInt:Int;
	public var defaultConstructorNull:Null<Http>;
	public var defaultConstructorOptional:Null<Http>;

	@inject("notfound4","notfound5","notfound6","notfound7")
	public function new( str:String="Felix", int:Int=1, nullValue:Null<Http>, ?optionalValue:Http ) {
		this.defaultConstructorString = str;
		this.defaultConstructorInt = int;
		this.defaultConstructorNull = nullValue;
		this.defaultConstructorOptional = optionalValue;
	}
}

class InjectionTest_InjectTheInjector {
	public var injectorInstance:dodrugs.DynamicInjector;
	public var injector:dodrugs.Injector<"classInstantiationInjector">;
	public function new(injectorInstance, injector) {
		this.injectorInstance = injectorInstance;
		this.injector = injector;
	}
}
