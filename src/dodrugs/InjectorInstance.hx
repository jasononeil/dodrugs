package dodrugs;

/**
InjectorInstance is the implementation class used for each `Injector`.

Every time you see a `Injector<"name">`, it will be an `InjectorInstance<"name">` object.

To create a new InjectorInstance, use `Injector.create()` or `Injector.extend()`.
See `InjectorStatics.create()` and `InjectorStatics.extend()` for documentation.
**/
class InjectorInstance<Const> extends DynamicInjectorInstance {
	public var name(default,null):String;

	function new( name:String, parent:Null<DynamicInjectorInstance>, mappings:InjectorMappings ) {
		super( parent, mappings );
		this.name = name;
		if ( !mappings.exists('dodrugs.InjectorInstance<"$name">') )
			mappings.set( 'dodrugs.InjectorInstance<"$name">', function(_,_) return this );
	}
}
