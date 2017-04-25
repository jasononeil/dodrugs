package dodrugs;

/**
An InjectorMapping is a simple function, taking the form `function (dynamicInjector, mappingString):T`.

Most of the time, these mappings will be created for you during `Injector.create()` or `Injector.extend()`.

But you can create mappings yourself.

If you wish to map a value, simply have the function return a value:

```haxe
var name = "Jason";
var mapping:InjectorMapping<String> = function(_,_) return name;
```

If you wish to set up a more complex object, you can have a more complex function:

```haxe
function injectorMapping(inj,mappingString) {
	var session = {};
	session.name = "UserSession";
	session.expiry = inj.getFromId("StdTypes.Int sessionExpiry");
	return session;
}
```

You can also modify the current injector.
For example, to map a singleton:

```haxe
function injectorMapping(inj,mappingStr) {
	// Build the value the first time, then replace this mapping with a "value" mapping.
	var value = buildMyObject();
	var newMapping = function(_,_) return value;
	@:privateAccess inj.mappings[mappingStr] = newMapping;
	return value;
}
```
**/
typedef InjectorMapping<T> = DynamicInjector->String->T;
