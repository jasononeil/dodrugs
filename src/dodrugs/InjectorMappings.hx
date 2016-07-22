package dodrugs;

import haxe.DynamicAccess;

/**
A group of mappings for a particular injector.

These are typed as a `DynamicAccess`, which means at runtime they are a dynamic object.
They behave like a `Map<String,InjectorMapping>`, with `get()`, `set()`, `[]` array access etc.

See `DynamicAccess` and `InjectorMapping`.
**/
typedef InjectorMappings = DynamicAccess<InjectorMapping<Dynamic>>;
