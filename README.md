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

	var appInjector = Injector.create( "app", [
		Connection => Value(existingMysqlCnx),          // Map a value.
		MailApi => Class(MyMailApi),                    // Map a class.
		UFMailer => Singleton(SmtpMailer),              // Map a singleton.
		(sessionName:String) => Value("my_session_ID"), // Map a String with a specific name.
		(magicNumbers:Array<Int>) => Value([3,7,13]),   // Map specific type parameters.
		(_:Array<Int>) => Value([]),                    // Map specific type parameters, without a name.
	] );

	$type( appInjector ); // Injector<"app">

A quick explanation for each of these:

- __Mapping a value:__ When anything requests a `Connection`, we'll give it the existing value (`existingMysqlCnx`).
- __Mapping a class:__ When anything requests a `MailApi`, we'll use the Injector to build a new `MyMailApi`.
- __Mapping a singleton:__ The first time something requests a `UFMailer`, we'll build a new `SmtpMailer`. All future requests will use that same `SmtpMailer`.
- __Using a named injection:__ Any time you see `@inject("sessionName") public var name:String` we'll give it the String "my_session_ID".
- __Using type parameters and a named injection:__ If you wish to map a type with type parameters, you need to wrap it in brackets so that it is valid Haxe syntax.
- __Using type parameters with no name:__ If you wish to use type parameters, but no name, you can use an underscore as the name: `(_:Type<TypeParameter>)`.

### Set up your injection points:

Constructor injection:

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

Property injection:

	// Inject a `String` named "projectName"
	@inject("projectName") public var projectName:String;

	// Inject a `Date` named "projectDeadline"
	@inject("projectDeadline") public var deadline:Date;

	// Inject a `Connection` without a name
	@inject public var cnx:Connection;

Injection methods:

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

Post injection:

	@post
	public function injectionHasFinished() {
		trace( "All done!" );
	}

### Feel safe:

TODO: demonstrate how this has compile time safety.

## Concepts

 1. Each injector has a unique name, and we know exactly what mappings it has at CompileTime.

	This is how we know we can add compile time safety.

	Anytime you have an `Injector<"app">` it will only be able to use the mappings available when `Injector.create( "app", [] )` was used.

 2. The `@inject` and `@post` metadata used to define injection points is designed to be compatible with [minect](https://github.com/massiveinteractive/minject/).

    This means a class could be instantiated by both an minject.Injector and a dodrugs.Injector.

 3. Avoid reflection

	Using runtime reflection adds a lot of bloat to Haxe code. ([Here is a simple gist](https://gist.github.com/jasononeil/bf5da8e176e595f476720ffffa6816b9) showing an example with the generated JS).

	Our aim is to avoid using `Reflect.callMethod`, `Reflect.setProperty`, `Reflect.fields`, `Type.getInstanceFields` or similar methods. We do this by using macros to generate regular imperitive Haxe for instantiating new objects.

 4. Minimal runtime dependencies.

	We have a compile time dependency on `tink_core` and `tink_macro`.

	In our runtime code, though only part of tink_core we use is `tink.core.Any`, which is a safer replacement for `Dynamic`, and will not require any extra code to be included at runtime.

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
