package dodrugs;

import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type;
using haxe.macro.Tools;
using tink.MacroApi;

class InjectorBuildMacro {
	static public function build():Null<ComplexType> {
		var typeToReturn = null;
		var pos = Context.currentPos();
		switch Context.getLocalType() {
			case TInst(_,[param]):
				switch param {
					case TInst( _.get() => { kind: KExpr(macro $v{(injectorID:String)})}, [] ):
						typeToReturn = macro :dodrugs.InjectorInstance;
						InjectorMacro.resetInjectorNamesCreatedMetadata();
					case TDynamic( null ):
						// If it's Dynamic, we just return a standard `InjectorInstance` with no information about available mappings.
						typeToReturn = macro :dodrugs.InjectorInstance;
					case _:
						Context.error( "Expected the type parameter to be a String", pos );
				}
			case TInst(_,[]):
				typeToReturn = macro :dodrugs.InjectorStatics;
			case t:
				Context.error( "Expected class with 1 parameter but got "+t.toString(), pos );
		}
		return typeToReturn;
	}
}
