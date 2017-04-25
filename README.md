DoDrugs (A macro-powered dependency injector for Haxe)
======================================================

DoDrugs is a dependency injection (*get it!!*) library for Haxe.

Unlike doing actual drugs, it is safe, because it uses macros to check all of your dependencies at compiletime.

## Usage

### Installation and boilerplate:

Installation:

	haxelib install dodrugs

Add it to your build hxml file:

	-lib dodrugs

And this import:

	import dodrugs.Injector;

### Set up your injector and its mappings in one place:

All of your dependencies must be defined in one go:

```haxe
var appInjector = Injector.create("myapp", [
	// Map a plain value.
	// When the Injector is asked for a String named "apiKey", we
	// will return the String "my secret". Same for the other values.
	var apiKey:String = "my secret",
	var sessionExpiry:Int = 3600,
	var mysqlCnx:Connection = existingMysqlCnx,

	// Map a class.
	// When the injector is asked for a `MailApi` class named `mailApi`,
	// we will build a new instance of the `MyMailApi` class using the
	// Injector and return the new instance.
	var mailApi:MailApi = @:toClass MyMailApi,

	// Map a singleton.
	// If it's a singleton, we will use the same instance each time
	// it is requested, rather than build multiple instances of the class.
	// The first time an `IMailer` named "mailer" is requested, we will
	// build a new SmtpMailer instance. We'll use that same instance for
	// all future requests too.
	var mailer:IMailer = @:toSingletonClass SmtpMailer,

	// Map a function.
	// Provide a function that returns executes and returns a value each time.
	// In this example, when a `ReactComponent` named `page` is requested,
	// we will run the JSX snippet and return the value.
	var page:ReactComponent = @:toFunction function (inj, id) {
		return jsx('<Page></Page>');
	}

	// Map a singleton function.
	// Provide a function that executes and returns a value the first time,
	// and keeps that value for future requests. In this example, when a
	// `Connection` named "cnx" is requested the first time, we create the
	// connection, then we will re-use that connection for all future requests.
	var cnx:Connection = @:toSingletonFunction function (inj, id) {
		return Mysql.connect({/**/});
	}

	// Use a wildcard mapping.
	// If you want your mapping to match any request for a `Connection`,
	// regardless of it's name, use `var _:Connection` to create
	// a wildcard mapping.
	var _:Connection = existingMysqlCnx,
	var _:MailApi = @:toClass MyMailApi,

	// Simple singleton mappings.
	// The most common type of mapping for APIs and Services is probably
	// `@:toSingletonClass`. If a mapping is simply `MyMailApi` we will
	// treat it the same as `var _:MyMailApi = @:toSingletonClass MyMailApi`.
	MyMailApi,
	SmtpMailer,

	// Simple class mappings.
	// If you would like to map a class to itself, but not as a singleton,
	// you can provide the class name and `@:toClass` metadata.
	// `@:toClass MyMailApi` is treated the same as
	// `var _:MyMailApi = @:toClass MyMailApi`
	@:toClass MyMailApi,
	@:toClass SmtpMailer
]);

$type(appInjector); // Injector<"myapp">
```

### Ask for some things rom the injector:

Constructor injection:

```haxe

class InjectAConnection {
	// Inject a Connection called "cnx", or fallback to any Connection.
	public function new(cnx:sys.db.Connection) {
		this.cnx = cnx;
	}
}

class InjectAString {
	// Inject a String called "assetPath", or fallback to any String.
	public function new(assetPath:String) {
		this.path = assetPath;
	}
}

class InjectBothAConnectionAndAString {
	// You can inject as many things as you want in the constructor.
	public function new(cnx:Connection, assetPath:String) {
		this.cnx = cnx;
		this.path = assetPath;
	}
}
```

Manual injection:

```haxe
// Request a class, no matter what name:
var cnx = appInjector.get(Connection);
var mailer = appInjector.get(ufront.mail.UFMailer);

// or:
var cnx = appInjector.get(var _:Connection);
var mailer = appInjector.get(var _:ufront.mail.UFMailer);

// Request a value with a specific name:
var sessionName = appInjector.get(var sessionName:String));
var sessionExpiry = appInjector.get(var sessionExpiry:Int);

// Type parameters:
var myArray = appInjector.get(var _:Array<String>);
var magicNumbers = appInjector.get(var _:magicNumbers:Array<Int>);

// Please note the following will not work, because
// it is not valid Haxe syntax:
//     var myArray = appInjector.get(Array<String>);
// If you need type parameters, you need to use the "var" syntax.
```

### Feel safe:

DoDrugs will not let you compile if a dependency that is required is not supplied.

You will get an error message like this:

	test/Example.hx:30: lines 30-35 : Warning : Mapping "Array.Array<StdTypes.Int>" is required here
	test/Example.hx:11: lines 11-15 : Please make sure you provide a mapping for "Array.Array<StdTypes.Int>" here

## Concepts

 1. #### Each injector has a unique name, and we know exactly what mappings it has at compile time, so we can be sure it has all the mappings it needs.

	This is how we add compile time safety.

	Anytime you have an `Injector<"app">` it will only be able to use the mappings available when `Injector.create("app", [])` was used.

	The idea of having a String as a type parameter is pretty odd, but it was the most light-weight way I could find to track injections accurately.

 2. #### We only offer constructor injection and manual injection.

 	Unlike [minject](https://github.com/massiveinteractive/minject/), another popular dependency injection library for Haxe, we do not support `@inject` injection points on variables or methods, and we do not have `@post` injection hooks.  You can only inject into the constructor, and everything will be available immediately.

	If you really would prefer property injection points, you can use [tink_lang](https://haxetink.github.io/tink_lang/#/declaration-sugar/property-declaration?id=direct-initialization) to automatically make variables things that are set in the constructor:

	```haxe
	@:tink class Person {
		var name:String = ("Stranger"); // Will become a constructor argument, default value is "Stranger".
		var age:Int = _;                // Will become a constructor argument, with no default value.
		function new() {}
	}
	```

 3. #### Avoid reflection.

	Using runtime reflection adds a lot of bloat to Haxe code. ([Here is a simple gist](https://gist.github.com/jasononeil/bf5da8e176e595f476720ffffa6816b9) showing an example with the generated JS).

	Our aim is to avoid using `Reflect.callMethod`, `Reflect.setProperty`, `Reflect.fields`, `Type.getInstanceFields` or similar methods. We do this by using macros to generate code for instantiating new objects, rather than figuring it out at runtime using reflection.

	Take a look at `bin/example.js` - it is very obvious when looking at the output code how each object is being constructed.
	That example only has about 100 lines of generated JS - quite tiny considering a full dependency injector is in use.

 4. #### No runtime dependencies.

	We have a compile time dependency on `tink_core` and `tink_macro`.
	These are not included in the generated code.

	Again, look at the generated `bin/example.js` to see how compact the resulting code can be.

## About the project

### License

All code is released under the MIT license.

### Support

If you find a bug or need help, feel free to post a Github issue.

### Contributions

Bug fixes and new features are welcome, providing they keep in line with the concepts given above, and the code stays small and focused.

If you submit a pull request, and you've made sure to update the tests and check they are passing, I will be your friend :)

### Naming

This is an injection library for Haxe that uses macros for extra safety, to avoid runtime issues. I thought about calling it "macro inject", or "minject" for short, but that was [already taken](https://github.com/massiveinteractive/minject/).

So I searched for "[synonym inject](https://duckduckgo.com/?q=synonym+inject&ia=thesaurus)" and settled on the name "do drugs".

I feel that the first time you understand dependency injection, it blows your mind. Comprehending Haxe macros is also a mind altering experience. Therefore using both macros and dependency injection at the same time must be the hard stuff.

Some people may be offended by the name. And being offensive is how you become a famous person or a presidential nominee.

Disclaimer: I've not personally taken illegal drugs. While some are probably fine others are life ruining. Next time you're tempted to take illicit substances, just type `haxe -lib dodrugs` instead.
