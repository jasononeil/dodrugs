import haxe.Http;

class InjectionTest_Constructor {
	public var name(default,null):String;
	public var age(default,null):Int;
	public var httpRequest(default,null):Http;
	public var favouriteNumbers(default,null):Array<Int>;

	public function new(name:String, age:Int, httpRequest:Http, favouriteNumbers:Array<Int>) {
		this.name = name;
		this.age = age;
		this.httpRequest = httpRequest;
		this.favouriteNumbers = favouriteNumbers;
	}
}

class InjectionTest_Constructor_Subclass extends InjectionTest_Constructor {
	public function new(name:String, age:Int, httpRequest:Http) {
		super(name, age, httpRequest, []);
	}
}

class InjectionTest_DefaultValues {
	public var defaultConstructorString:String;
	public var defaultConstructorInt:Int;
	public var defaultConstructorNull:Null<StringBuf>;
	public var defaultConstructorOptional:Null<StringBuf>;

	public function new(notFound1:String="Felix", notFound2:Int=1, notFound3:Null<StringBuf>, ?notFound4:StringBuf) {
		this.defaultConstructorString = notFound1;
		this.defaultConstructorInt = notFound2;
		this.defaultConstructorNull = notFound3;
		this.defaultConstructorOptional = notFound4;
	}
}

class InjectionTest_InjectTheInjector {
	public var injectorInstance:dodrugs.UntypedInjector;
	public var injector:dodrugs.Injector<"classInstantiationInjector">;
	public function new(injectorInstance, injector) {
		this.injectorInstance = injectorInstance;
		this.injector = injector;
	}
}
