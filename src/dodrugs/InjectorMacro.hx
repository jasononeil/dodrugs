package dodrugs;

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
using haxe.macro.Tools;
using tink.CoreApi;
using tink.MacroApi;

class InjectorMacro {

	/**
	Generate a new `InjectorInstance` (usually a @:genericBuild() from `Injector`) using the given parent and setting up the mappings.

	@param name The unique name of this injector.
	@param name An expression for the parent injector, or `null`.
	@param mappings An expression for the mappings that we will process and make available in this injector.
	@return An expression that will instantiate a new injector with the mappings appropriately processed.
	**/
	public static function generateNewInjector( name:String, parent:Expr, mappings:Expr ):Expr {
		var mappingsExpr = generateMappings( mappings );
		var pos = Context.currentPos();
		var param = TPExpr( macro $v{name} );
		var typePath = "dodrugs.Injector".asTypePath([ param ]);
		var expr = macro @:pos(pos) @:privateAccess new $typePath( null, $mappingsExpr );

		// Mark the metadata to show this type has been used. We'll need to trigger the type creation first.
		Context.typeof( expr );
		var type = Context.getType( getQualifiedInjectorTypeName(name) );
		checkInjectorIsNotAlreadyCreated( type, name, pos );

		return expr;
	}

	/**
	Find the injection ID for a particular expression.

	@param mapType The expression representing the type or name we wish to reference.
	@return The mapping ID as a String.
	**/
	public static function getInjectionIdFromExpr( mapType:Expr ):String {
		var pair = getMappingDetailsFromExpr( mapType );
		var complexType = makeTypePathAbsolute( pair.a, mapType.pos );
		return formatMappingId( complexType, pair.b );
	}

	/**
	Find the expected ComplexType based on the same expression used to get the injection ID.

	@param mapType The expression representing the type or name we wish to reference.
	@return The complex type that this expression represents.
	**/
	public static function getComplexTypeFromIdExpr( mapType:Expr ):ComplexType {
		var pair = getMappingDetailsFromExpr( mapType );
		return makeTypePathAbsolute( pair.a, mapType.pos );
	}

	/**
	Get an expression for the runtime `InjectorMapping` value based on the compile-time expression.

	@param mapExpr The compile time expression describing how the map should work.
	@return An expression for the `InjectorMapping` value to be used.
	**/
	public static function getInjectionMappingFromExpr( mapExpr:Expr ):Expr {
		switch mapExpr {
			case macro Function($fnExpr):
				return fnExpr;
			case macro Class($classExpr):
				return buildClassInstantiationFn( classExpr );
			case macro Singleton($classExpr):
				var fnExpr = buildClassInstantiationFn( classExpr );
				return macro @:pos(classExpr.pos) function(inj:dodrugs.InjectorInstance,id:String):tink.core.Any return @:privateAccess inj.getSingleton( $fnExpr, id );
			case macro Value($e):
				return macro @:pos(e.pos) function(_:dodrugs.InjectorInstance, _:String):tink.core.Any return ($e:tink.core.Any);
			case _:
				return mapExpr.reject( 'Injector mappings should be a Value(v), Class(cl), Singleton(cl) or Function(Injector->Outcome<T,String>)' );
		}
	}

	static function buildClassInstantiationFn( classExpr:Expr ):Expr {
		var p = classExpr.pos;
		// Get the TypePath, ComplexType and Type based on the classExpr.
		var className = exprIsTypePath( classExpr ).sure();
		var targetTypePath = className.asTypePath();
		var targetComplexType = TPath( targetTypePath );
		var targetType = targetComplexType.toType().sure();
		var targetClassType = switch targetType {
			case TInst(t,_): t.get();
			case _: Context.error( '${classExpr} is not a class', p );
		}
		targetComplexType = targetType.toComplex();
		targetTypePath = switch targetComplexType {
			case TPath(tp): tp;
			case _: throw 'assert';
		}
		var constructorLines = getConstructorExpressions( targetClassType, targetTypePath, p );
		var methodInjections = getMethodInjectionExpressions( targetClassType, p );
		var propertyInjections = getPropertyInjectionExpressions( targetClassType, p );
		var postInjections = getPostInjectionExpressions( targetClassType, p );

		var allLines = [for (arr in [constructorLines,methodInjections,propertyInjections,postInjections]) for (line in arr) line];
		allLines.push( macro return (o:tink.core.Any) );
		return macro @:pos(p) function(inj:dodrugs.InjectorInstance,id:String):tink.core.Any $b{allLines}
	}

	static function getConstructorExpressions( type:ClassType, typePath:TypePath, pos:Position ):Array<Expr> {
		var constructor = getConstructorForType( type, pos ).sure();
		var constructorLines = [];
		var constructorArguments = [];
		var fnArgumentLines = getArgumentsForMethodInjection( constructor, pos );
		for ( argPair in fnArgumentLines ) {
			constructorArguments.push( argPair.a );
			constructorLines.push( argPair.b );
		}
		constructorLines.push( macro @:pos(pos) var o = new $typePath($a{constructorArguments}) );
		return constructorLines;
	}

	static function getMethodInjectionExpressions( type:ClassType, pos:Position ):Array<Expr> {
		var injectionExprs = [];
		var injectionFields = getPublicInstanceFieldsWithMeta( type, 'inject' );
		for ( field in injectionFields ) {
			if ( field.kind.match(FMethod(_)) ) {
				var fieldName = field.name;
				var fnArguments = [];
				var fnArgumentLines = getArgumentsForMethodInjection( field, pos );
				for ( argPair in fnArgumentLines ) {
					fnArguments.push( argPair.a );
					injectionExprs.push( argPair.b );
				}
				var callFnExpr = macro @:pos(pos) o.$fieldName( $a{fnArguments} );
				injectionExprs.push( callFnExpr );
			}
		}
		return injectionExprs;
	}

	static function getPostInjectionExpressions( type:ClassType, pos:Position ):Array<Expr> {
		var injectionExprs = [];
		var injectionFields = getPublicInstanceFieldsWithMeta( type, 'post' );
		for ( field in injectionFields ) {
			switch [field.kind, field.expr().expr] {
				case [FMethod(_), TFunction({ args:methodArgs, expr:_, t:_ })]:
					if ( methodArgs.length==0 ) {
						var fieldName = field.name;
						var callFnExpr = macro @:pos(pos) o.$fieldName();
						injectionExprs.push( callFnExpr );
					}
					else {
						Context.error( '@post functions should not have function arguments, but ${field.name}() has ${methodArgs.length} function arguments', field.pos );
					}
				case _:
					Context.warning( 'Internal Injector Error: ${field.name} is not a method', field.pos );
			}
		}
		return injectionExprs;
	}

	static function getPropertyInjectionExpressions( type:ClassType, pos:Position ):Array<Expr> {
		var injectionExprs:Array<Expr> = [];
		var injectionFields = getPublicInstanceFieldsWithMeta( type, 'inject' );
		for ( field in injectionFields ) {
			if ( field.kind.match(FVar(_,_)) ) {
				var typedExpr = field.expr();
				var defaultValue = ( typedExpr!=null ) ? Context.getTypedExpr(typedExpr) : null;
				var pair = checkIfTypeIsOptional( field.type, defaultValue );
				var fieldType = pair.a;
				var defaultValue = pair.b;
				var metaNames = getInjectionNamesFromMetadata( field );
				var injectionName = (metaNames[0]!="") ? metaNames[0] : null;
				var getValueExpr = generateExprToGetValueFromInjetor( fieldType, injectionName, defaultValue );
				var fieldName = field.name;
				// Note, $getValueExpr is typed as `Any`, but the auto-cast to the intended type produces some verbose JS code.
				// We're using an unsafe cast here to make sure the JS code is nice and clean.
				var setPropExpr = macro @:pos(pos) o.$fieldName = cast $getValueExpr;
				injectionExprs.push( setPropExpr );
			}
		}
		return injectionExprs;
	}

	static function getConstructorForType( classType:ClassType, pos:Position ):Outcome<ClassField,Error> {
		if ( classType.constructor!=null ) {
			return Success( classType.constructor.get() );
		}
		if ( classType.superClass!=null ) {
			// TODO: see if it is useful for us to support type parameters.
			var superClassType = classType.superClass.t.get();
			return getConstructorForType( superClassType, pos );
		}
		return Failure( new Error('The type ${classType.name} has no constructor',pos) );
	}

	static function getPublicInstanceFieldsWithMeta( classType:ClassType, metaName:String ):Array<ClassField> {
		var fields = [for (f in classType.fields.get()) if (f.isPublic && f.meta.has(metaName)) f];
		if ( classType.superClass!=null ) {
			// TODO: see if it is useful for us to support type parameters.
			var superClassType = classType.superClass.t.get();
			var existingFields = getPublicInstanceFieldsWithMeta( superClassType, metaName );
			for ( f1 in existingFields ) {
				if ( !Lambda.exists(fields,function(f2) return f1.name==f2.name) ) {
					fields.unshift( f1 );
				}
			}
		}
		return fields;
	}

	static function getArgumentsForMethodInjection( method:ClassField, injectionPos:Position ):Array<Pair<Expr,Expr>> {
		var metaNames = getInjectionNamesFromMetadata( method );
		switch [method.kind, method.expr().expr] {
			case [FMethod(_), TFunction({ args:methodArgs, expr:_, t:_ })]:
				if ( metaNames.length!=0 && methodArgs.length!=metaNames.length ) {
					Context.error( '@inject() had ${metaNames.length} parameters but ${method.name}() has ${methodArgs.length} arguments', method.pos );
				}
				else {
					var argumentExprs = [];
					for ( i in 0...methodArgs.length ) {
						var varName = methodArgs[i].v.name;
						var injectionName = (metaNames[i]!="") ? metaNames[i] : null;
						var getValueExpr = getExprForFunctionArg( methodArgs[i], injectionName );
						var identExpr = macro $i{varName};
						var setValueExpr = macro var $varName = $getValueExpr;
						argumentExprs.push( new Pair(identExpr,setValueExpr) );
					}
					return argumentExprs;
				}
			case _:
				Context.warning( 'Internal Injector Error: ${method.name} is not a method', method.pos );
		}
		return [];
	}

	static function getInjectionNamesFromMetadata( field:ClassField ):Array<String> {
		var metaNames = [];
		for ( metaEntry in field.meta.extract("inject") ) {
			for ( param in metaEntry.params ) {
				switch param.getString() {
					case Success(str):
						metaNames.push( str );
					case Failure(_):
						Context.error( '@inject() parameters should be strings', param.pos );
				}
			}
		}
		return metaNames;
	}

	static function getExprForFunctionArg( methodArg:{v:TVar, value:Null<TConstant>}, injectionName:Null<String> ):Expr {
		var param = methodArg.v;
		var defaultValue:Expr = null;
		if ( methodArg.value!=null ) {
			defaultValue = switch methodArg.value {
				case TInt(i): macro $v{i};
				case TFloat(f): macro $v{f};
				case TString(s): macro $v{s};
				case TBool(b): macro $v{b};
				case TNull: macro null;
				case TThis: macro this;
				case TSuper: macro super;
			}
		}
		// Check if the injection is optional.
		var pair = checkIfTypeIsOptional( param.t, defaultValue );
		var paramType = pair.a;
		defaultValue = pair.b;
		return generateExprToGetValueFromInjetor( paramType, injectionName, defaultValue );
	}

	static function checkIfTypeIsOptional( t:Type, defaultValue:Null<Expr> ) {
		switch t {
			case TType(_.toString()=>"Null", _[0]=>actualType):
				return new Pair( actualType, (defaultValue!=null) ? defaultValue : macro null );
			case _:
				return new Pair( t, defaultValue );
		}
	}

	static function generateExprToGetValueFromInjetor( type:Type, injectionName:Null<String>, defaultValue:Null<Expr> ):Expr {
		var injectionID = getInjectionIDAndMarkRequired( type, injectionName, defaultValue!=null );
		return
			if ( defaultValue!=null ) macro inj.getOptionalValueFromMappingID( $v{injectionID}, $defaultValue )
			else macro inj.getValueFromMappingID( $v{injectionID} );
	}

	static function getInjectionIDAndMarkRequired( type:Type, name:String, isOptional:Bool ) {
		var id = formatMappingId( type.toComplex(), name );
		return id;
	}

	static function getInjectionIDAndMarkSupplied( type:Type, name:String, isOptional:Bool ) {
		var id = formatMappingId( type.toComplex(), name );
		return id;
	}

	/**
	Get the fully qualified TypeName for an Injector with a particular name.
	@param injectorName The unique name of the injector.
	@return A String with the fully qualified TypePath for the injector with that name.
	**/
	public static function getQualifiedInjectorTypeName( injectorName:String ):String {
		return 'dodrugs.instances.InjectorInstance_$injectorName';
	}

	/**
	Use metadata to track which injectors have been created, and give errors if an injector name is created multiple times.

	This ensures that each injector is unique to the codebase, and we can know with confidence which rules are available within the injector.

	@param type The `haxe.macro.Type` of the injector (created from the @:genericBuild on `Injector`).
	@param name The unique name of the injector.
	@param pos The position to report an error if the unique name has already been used.
	@throws Generates a compile time error if the Injector has been created more than once in this code base.
	**/
	public static function checkInjectorIsNotAlreadyCreated( type:Type, name:String, pos:Position ) {
		switch type {
			case TInst( _.get() => classType, _ ):
				if ( classType.meta.has(':hasBeenCreated') ) {
					var oldMeta = Lambda.find( classType.meta.get(), function(m) return m.name==":hasBeenCreated" );
					var previousPos = oldMeta.pos;
					Context.warning( 'An Injector named "${name}" was previously created here', previousPos );
					Context.warning( 'And a different Injector named "${name}" is being created here', pos );
					Context.error( 'Error: duplicate Injector name used', pos );
				}
				else {
					classType.meta.add( ':hasBeenCreated', [], pos );
				}
			case _:
		}
	}

	/**
	Reset the @:hasBeenCreated metadata on a Type.
	If using the Haxe compilation server, this should be used at the start of each new build.
	It is currently used on all `@:genericBuild class Injector` builds.

	@param type The `haxe.macro.Type` of the injector (created from the @:genericBuild on `Injector`).
	**/
	public static function resetHasBeenCreatedMetadata( type:Type ) {
		switch type {
			case TInst( _.get() => classType, _ ):
				classType.meta.remove( ':hasBeenCreated' );
			case _:
		}
	}

	static function generateMappings( mappings:Expr ):Expr {
		var mappingRules = [];
		switch mappings {
			case macro [$a{mappingExprs}]:
				for ( mappingExpr in mappingExprs ) {
					var rule = processMappingExpr( mappingExpr );
					mappingRules.push( rule );
				}
			case _:
				mappings.reject( 'Injector rules should be provided using Map Literal syntax.' );
		}
		var objDecl = { expr:EObjectDecl(mappingRules), pos:mappings.pos };
		return macro ($objDecl:haxe.DynamicAccess<dodrugs.InjectorMapping<tink.core.Any>>);
	}

	static function processMappingExpr( mappingExpr:Expr ):{ field:String, expr:Expr } {
		switch mappingExpr {
			case macro $i{typeName}:
				var mappingID = getInjectionIdFromExpr( mappingExpr );
				var injectorMapping = getInjectionMappingFromExpr( macro Class($mappingExpr) );
				return { field:mappingID, expr: injectorMapping };
			case macro $mapType => $mapRule:
				var mappingID = getInjectionIdFromExpr( mapType );
				var injectorMapping = getInjectionMappingFromExpr( mapRule );
				return { field:mappingID, expr: injectorMapping };
			case _:
				return mappingExpr.reject( 'Mapping expression should either by `TypeName` or `MappedType => ImplementationType`' );
		}
	}

	/**
	Check if an expression is a Type Path,
	**/
	static function exprIsTypePath( expr:Expr, ?needsToBeUpper=true ):Outcome<String,Error> {
		function failure() return Failure( new Error('Not a valid type path: ${expr.toString()}', expr.pos) );
		function firstCharIsUpper(s:String) return s.charAt(0)==s.charAt(0).toUpperCase();
		switch expr {
			case macro $i{ident}:
				return
					if ( firstCharIsUpper(ident) || needsToBeUpper==false ) Success( ident );
					else failure();
			case macro $parent.$field:
				if ( needsToBeUpper && firstCharIsUpper(field)==false )
					return failure();
				switch exprIsTypePath(parent,false) {
					case Success(tp): return Success( '$tp.$field' );
					case Failure(err): return failure();
				}
			case _: return failure();
		}
	}

	static function getMappingDetailsFromExpr( mapType:Expr ):Pair<ComplexType,String> {
		var typePathRegex = ~/^([a-zA-Z0-9_\.]+\.)?[A-Z][a-zA-Z0-9_]*$/;
		switch mapType {
			case macro $i{typeName}:
				var complexType = typeName.asComplexType();
				return new Pair( complexType, null );
			case macro (_:$complexType):
				return new Pair( complexType, null );
			case macro ($i{name}:$complexType):
				return new Pair( complexType, name );
			case exprIsTypePath(_) => Success(typeName):
				var complexType = typeName.asComplexType();
				return new Pair( complexType, null );
			case _:
				mapType.reject( 'Incorrect syntax for mapping type: ${mapType.toString()} could not be understood' );
				return null;
		}
	}

	static function formatMappingId( complexType:ComplexType, name:String ) {
		var complexTypeStr = complexType.toString();
		return (name!=null) ? '${complexTypeStr} ${name}' : complexTypeStr;
	}

	static function makeTypePathAbsolute( ct:ComplexType, pos:Position ):ComplexType {
		return ct.toType( pos ).sure().toComplex();
	}
}
