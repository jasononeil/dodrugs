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
						typeToReturn = defineClassForID( injectorID, pos );
					case TDynamic( null ):
						// If it's Dynamic, we just return a standard `InjectorInstance` with no information about available mappings.
						typeToReturn = macro :dodrugs.InjectorInstance;
					case _:
						Context.error( "Expected the type parameter to be a String", pos );
				}
			case t:
				Context.error( "Expected class with 1 parameter but got "+t.toString(), pos );
		}
		return typeToReturn;
	}

	static function defineClassForID( injectorID:String, p:Position ):ComplexType {
		var qualifiedClassName = InjectorMacro.getQualifiedInjectorTypeName( injectorID );
		var classNameParts = qualifiedClassName.split( "." );
		var className = classNameParts.pop();
		var typeDefinition = macro class $className extends dodrugs.InjectorInstance {

		};
		typeDefinition.pack = classNameParts;
		typeDefinition.pos = p;
		// If the type does not already exist, create it.
		try {
			Context.getType( qualifiedClassName );
		}
		catch ( e:Dynamic ) {
			Context.defineType( typeDefinition );
			var type = Context.getType( qualifiedClassName );
			Context.onMacroContextReused(function() {
				InjectorMacro.resetHasBeenCreatedMetadata( type );
				return true;
			});
		}
		return TPath({ name: className, pack: typeDefinition.pack, sub: null, params: null });
	}
}
