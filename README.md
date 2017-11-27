DoDrugs (A macro-powered dependency injector for Haxe)
======================================================

[![Travis Build Status](https://travis-ci.org/jasononeil/dodrugs.svg?branch=master)](https://travis-ci.org/jasononeil/dodrugs)

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

### Child injectors

Sometimes it is useful to have child injectors, which share all the same mappings as a parent, as well as some mappings of it's own.

#### `Injector.extend(name, [])`

To create a child, use `Injector.extend`:

```haxe
var requestInjector = Injector.extend("request_injector", appInjector, [
	// All of the mappings we defined above in `appInjector` will be available here.
	// But we can add some more:
	var user: User = getCurrentUser(),
	var session: Session = getCurrentSession(),
	var req: Request = req,
	var res: Response = res,
]);
```

#### `injector.quickExtend([...additionalMappings])`

If you would like to quickly add a few extra mappings and use an injector, and don't plan to use the injector later, you can use `quickExtend()`:

```haxe
var requestInjector = appInjector.quickExtend([
	var req: Request = currentRequest,
	var res: Response = currentResponse,
]);
var user = requestInjector.get(User);
```

Using `quickExtend()` will generate an injector name automatically, so it is inconvenient to use the new injector in another function at a later time.
It is designed to be used immediately.

#### `injector.getWith(RequestedType, [...additionalMappings])`

If you would like to fetch a single value from an injector, while adding a few extra mappings, you can use `injector.getWith()`.

Calling `injector.getWith(type, mappings)` is essentially the same as calling `injector.quickExtend(mappings).get(type);`.

```haxe
var user = appInjector.getWith(User, [
	var req: Request = currentRequest,
	var res: Response = currentResponse
]);
```

#### `injector.instantiate(RequestedClass)`

If you would like to create a new object of a particular class using the injector, but the class does not have a mapping, you can use `injector.instantiate(RequestedClass)`:

```haxe
var inj = Injector.create('app', [
	var name: String = 'Jason',
	var age: Int = 30
]);
// This will work even though "Person" was not mapped in the 'app' injector.
var person = inj.instantiate(Person);
```

This works by creating a child injector with an extra mapping for that class. It is essentially the same as calling:

```haxe
var person = inj
	.quickExtend([
		var _:Person = @:toClass Person
	])
	.get(Person);
```

Note: if you call `instantiate()` but a mapping for the class already existed, the existing mapping will be used.

#### A note about singletons and child injectors

A singleton is created the first time `injector.get(MySingleton)` is called, and it will be available for future requests on that injector, and on all children injectors. Therefore, if you have a singleton mapping on a parent injector:

- If you call `parent.get(MySingleton)`, the `MySingleton` object will be created and shared between the parent and all children.
- If you call `child.get(MySingleton)`, the `MySingleton` object will be created and re-used for that child and any of it's children/grandchildren.
- If you call both, the behaviour will change depending on which one you call first. If `parent.get(MySingleton)` is called before `child.get(MySingleton)`, they will share the same object. If the child is called first, it will have its own scoped object.

This design trade-off was chosen as part of a refactor to allow children to supply injections to the parent injectors.
If you have advice on a more predictable API pattern we could use here, please open an issue so we can discuss.

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

	Using runtime reflection adds a lot of bloat to Haxe generated JS. ([Here is a simple gist](https://gist.github.com/jasononeil/bf5da8e176e595f476720ffffa6816b9) showing an example with the generated JS).

	Our aim is to avoid using `Reflect.callMethod`, `Reflect.setProperty`, `Reflect.fields`, `Type.getInstanceFields` or similar methods. We do this by using macros to generate code for instantiating new objects, rather than figuring it out at runtime using reflection.

	Take a look at `bin/example.js` - it is very obvious when looking at the output code how each object is being constructed.
	That example only has about 100 lines of generated JS - quite tiny considering a full dependency injector is in use.

	Please note we do use `DynamicAccess`, which on some Haxe targets will use reflection, but importantly the output is clean and avoids reflection on the JS target.

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
