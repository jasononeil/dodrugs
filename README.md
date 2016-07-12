DoDrugs (A macro-powered dependency injector for Haxe)
======================================================

DoDrugs in a dependency injection (*get it!!*) library for Haxe.
Unlike doing actual drugs, it uses macros to be safe, checking all of your dependencies at compiletime.

## Usage

### Getting set up

Installation:

	haxelib install dodrugs

Add it to your build hxml file:

	-lib dodrugs

And this import:

	import dodrugs.Injector;

### Set up your injector and its mappings in one place.

All of your dependencies must be defined in one go:

```haxe
var appInjector = Injector.create( "myapp", [
	// Map a value, class, singleton or function
	Connection.toValue(existingMysqlCnx),
	MailApi.toClass(MyMailApi),
	UFMailer.toSingleton(SmtpMailer),

	// Shortcut for mapping a class to itself:
	MyMailApi,
	MyAuthHandler,

	// Injection mappings with a specific name:
	String.named("sessionName").toValue("my_session_ID"),
	Int.named("sessionExpiry").toValue(3600),

	// And an alternative syntax:
	(sessionName:String).toValue("my_session_ID"),
	(sessionExpiry:Int).toValue(3600),

	// Type parameters need to either be in quotation marks:
	"Array<String>".toValue([]),
	"Array<Int>".named("magicNumbers").toValue([3,7,13]),

	// Or in brackets, using the "CheckType" syntax.
	// (If you use this syntax but don't want a named injection, use an underscore "_")
	(_:Array<String>).toValue([]),
	(magicNumbers:Array<Int>).toValue([3,7,13]),
] );

$type( appInjector ); // Injector<"myapp">
```

A quick explanation for each of these:

- __Mapping a value:__ When anything requests a `Connection`, we'll give it the existing value (`existingMysqlCnx`).
- __Mapping a class:__ When anything requests a `MailApi`, we'll use the Injector to build a new `MyMailApi`.
- __Mapping a singleton:__ The first time something requests a `UFMailer`, we'll build a new `SmtpMailer`. All future requests will use that same `SmtpMailer`.
- __Using a named injection:__ Any time you see `@inject("sessionName") public var name:String` we'll give it the String "my_session_ID".
- __Using type parameters:__ When you map a type that has a type parameter, you need to either wrap it in quotation marks `"Array<Int>"`, or use the CheckType syntax `(name:Array<Int>)`. This is a limitaton of Haxe syntax parsing.

### Set up your injection points:

Constructor injection:

```haxe
// Inject a `Connection`
@inject
public function new( cnx:sys.db.Connection ) {
	this.cnx = cnx;
}

// Inject a `String` named "assetPath"
@inject("assetPath")
public function new( path:String ) {
	this.path = path;
}

// A combination:
@inject("","assetPath")
public function new( cnx:Connection, path:String ) {
	this.cnx = cnx;
	this.path = path;
}
```

Property injection:

```haxe
// Inject a `String` named "projectName"
@inject("projectName") public var projectName:String;

// Inject a `Date` named "projectDeadline"
@inject("projectDeadline") public var deadline:Date;

// Inject a `Connection` without a name
@inject public var cnx:Connection;
```

Injection methods:

```haxe
// Inject a `Connection`
@inject
public function setConnection( cnx:Connection ) {
	this.cnx = cnx;
}

// Inject a `String` named "assetPath"
@inject("assetPath")
public function useAssetPath( path:String ) {
	this.path = path;
}

// A combination:
@inject("","assetPath")
public function injectData( cnx:Connection, path:String ) {
	this.cnx = cnx;
	this.path = path;
}
```

Post injection:

```haxe
@post
public function injectionHasFinished() {
	trace( "All done!" );
}
```

Manual injection:

```haxe
// Basic:
var cnx = appInjector.get( Connection );
var mailer = appInjector.get( ufront.mail.UFMailer );

// Named Injections:
var sessionName = appInjector.get( String.named("sessionName") );
var sessionExpiry = appInjector.get( Int.named("sessionExpiry") );

// Alternative Syntax:
var sessionName = appInjector.get( (sessionName:String) );
var sessionExpiry = appInjector.get( (sessionExpiry:Int) );

// Type parameters:
var myArray = appInjector.get( "Array<String>" );
var magicNumbers = appInjector.get( "Array<Int>".named("magicNumbers") );

// CheckType syntax:
var myArray = appInjector.get( (_:Array<String>) );
var magicNumbers = appInjector.get( (magicNumbers:Array<String>) );
```

### Feel safe:

TODO: We haven't added it yet, but soon we'll add a whole range of compile time safety checks.

You should never get an "Injector has no rule for type ..." error message again.

## Concepts

 1. #### Each injector has a unique name, and we know exactly what mappings it has at compile time, so we can be sure it has all the mappings it needs.

	This is how we know we can add compile time safety.

	Anytime you have an `Injector<"app">` it will only be able to use the mappings available when `Injector.create( "app", [] )` was used.

 2. #### The `@inject` and `@post` metadata used to define injection points is designed to be compatible with [minject](https://github.com/massiveinteractive/minject/).

    This means a class could be instantiated by both an minject.Injector and a dodrugs.Injector.

 3. #### Avoid reflection.

	Using runtime reflection adds a lot of bloat to Haxe code. ([Here is a simple gist](https://gist.github.com/jasononeil/bf5da8e176e595f476720ffffa6816b9) showing an example with the generated JS).

	Our aim is to avoid using `Reflect.callMethod`, `Reflect.setProperty`, `Reflect.fields`, `Type.getInstanceFields` or similar methods. We do this by using macros to generate code for instantiating new objects, rather than figuring it out at runtime using reflection.

	Take a look at `bin/example.js` - it is very obvious when looking at the output code how each object is being constructed, and that example has less than 100 lines of generated JS.

 4. #### Minimal runtime dependencies.

	We have a compile time dependency on `tink_core` and `tink_macro`.

	In our runtime code, though only part of tink_core we use is `tink.core.Any`, which is a safer replacement for `Dynamic`, and will not require any extra code to be included at runtime.

	Again, look at the generated `bin/example.js` to see how compact the resulting code can be.

About the project
-----------------

### License

All code is released under the MIT license.

### Naming

This is an injection library for Haxe that uses macros for extra safety, to avoid runtime issues. I thought about calling it "macro inject", or "minject" for short, but that was [already taken](https://github.com/massiveinteractive/minject/).

So I searched for "[synonym inject](https://duckduckgo.com/?q=synonym+inject&ia=thesaurus)" and settled on the name "do drugs".

I feel that the first time you understand dependency injection, it blows your mind. Comprehending Haxe macros is also a mind altering experience. Therefore using both macros and dependency injection at the same time must be the hard stuff.

Some people may be offended by the name. And being offensive is how you become a famous person or a presidential nominee.

Disclaimer: I've not personally taken illegal drugs. While some are probably fine others are life ruining. Next time you're tempted to take illicit substances, just type `haxe -lib dodrugs` instead.
