package dodrugs;

using tink.CoreApi;

enum InjectorMapping<T> {
	/** An ordinary value. **/
	Value( value:T );
	/** A function that will provide a value each time it is requested. **/
	Function( fn:Injector<Dynamic>->Outcome<T,Error> );
	/** A function that will provide a value the first time, and re-use that same value on future requests. **/
	Singleton( fn:Injector<Dynamic>->Outcome<T,Error> );
}
