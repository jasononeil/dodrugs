package dodrugs;

/**
The main class for setting up and interacting with an injector.

Because of the way we have set up the `@:genericBuild` macro, the API documentaton is split between `InjectorStatics` and `InjectorInstance`.

Static methods:

- `Injector.create()` - See `InjectorStatics.create()`
- `Injector.extend()` - See `InjectorStatics.extend()`
- `Injector.getInjectionId()` - See `InjectorStatics.getInjectionId()`
- `Injector.getInjectionMapping()` - See `InjectorStatics.getInjectionMapping()`

Instance methods:

- `myInjector.getFromID()` - See `InjectorInstance.getFromID()`
- `myInjector.tryGetFromID()` - See `InjectorInstance.tryGetFromID()`
- `myInjector.get()` - See `InjectorInstance.get()`
**/
@:genericBuild(dodrugs.InjectorBuildMacro.build())
class Injector<Const> {}
