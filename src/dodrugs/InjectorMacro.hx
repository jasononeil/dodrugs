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
		checkInjectorIsNotAlreadyCreated( name, pos );
		var param = TPExpr( macro $v{name} );
		var typePath = "dodrugs.Injector".asTypePath([ param ]);
		return macro @:pos(pos) @:privateAccess new $typePath( $v{name}, $parent, $mappingsExpr );
	}

	/**
	Find the injection mapping string for a particular expression.

	@param mapType The expression representing the type or name we wish to reference.
	@return The unique mapping string for this mapping type and name.
	**/
	public static function getInjectionStringFromExpr( mapType:Expr ):String {
		var pair = getMappingDetailsFromExpr( mapType );
		var complexType = makeTypePathAbsolute( pair.a, mapType.pos );
		return getInjectionIDAndMarkSupplied( complexType, pair.b );
	}

	/**
	Find the expected ComplexType based on the same expression used to get the injection string.

	@param mapType The expression representing the type or name we wish to reference.
	@return The complex type that this expression represents.
	**/
	public static function getComplexTypeFromIdExpr( mapType:Expr ):ComplexType {
		var pair = getMappingDetailsFromExpr( mapType );
		return makeTypePathAbsolute( pair.a, mapType.pos );
	}


	/**
	Process a mapping expression, and return the field and the mapping function.

	@param mappingExpr The complete expression representing the mapping.
	@return An object with the `field` (the injection ID) and the `expr` (the mapping function). Ready to use in an EObjectDecl.
	**/
	public static function processMappingExpr( mappingExpr:Expr ):{ field:String, expr:Expr } {
		var result = { field:null, expr:null };
		switch mappingExpr {
			case macro $mappingIDExpr.toClass( $classExpr ):
				result.field = getInjectionIdFromExpr( mappingIDExpr );
				result.expr = buildClassInstantiationFn( classExpr );
			case macro $mappingIDExpr.toSingleton( $classExpr ):
				var fnExpr = buildClassInstantiationFn( classExpr );
				result.field = getInjectionIdFromExpr( mappingIDExpr );
				result.expr = macro @:pos(classExpr.pos) function(inj:dodrugs.InjectorInstance,id:String):tink.core.Any return @:privateAccess inj._getSingleton( $fnExpr, id );
			case macro $mappingIDExpr.toValue( $e ):
				result.field = getInjectionIdFromExpr( mappingIDExpr );
				result.expr = macro @:pos(e.pos) function(_:dodrugs.InjectorInstance, _:String):tink.core.Any return ($e:tink.core.Any);
			case macro $mappingIDExpr.toFunction( $fn ):
				result.field = getInjectionIdFromExpr( mappingIDExpr );
				result.expr = fn;
			case exprIsTypePath(_) => outcome:
				var typeName = outcome.sure();
				result.field = getInjectionIdFromExpr( mappingExpr );
				result.expr = buildClassInstantiationFn( mappingExpr );
			case _:
				return mappingExpr.reject( 'Mapping expression should end in .toClass(cls), .toSingleton(cls), .toValue(v) or .toFunction(fn)' );
		}
		return result;
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
				var getValueExpr = generateExprToGetValueFromInjector( fieldType, injectionName, defaultValue );
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
		return generateExprToGetValueFromInjector( paramType, injectionName, defaultValue );
	}

	static function checkIfTypeIsOptional( t:Type, defaultValue:Null<Expr> ) {
		switch t {
			case TType(_.toString()=>"Null", _[0]=>actualType):
				return new Pair( actualType, (defaultValue!=null) ? defaultValue : macro null );
			case _:
				return new Pair( t, defaultValue );
		}
	}

	static function generateExprToGetValueFromInjector( type:Type, injectionName:Null<String>, defaultValue:Null<Expr> ):Expr {
		var injectionID = getInjectionIDAndMarkRequired( type.toComplex(), injectionName, defaultValue!=null );
		return
			if ( defaultValue!=null ) macro inj.tryGetFromID( $v{injectionID}, $defaultValue )
			else macro inj.getFromID( $v{injectionID} );
	}

	static function getInjectionIDAndMarkRequired( complexType:ComplexType, name:String, isOptional:Bool ) {
		var id = formatMappingId( complexType, name );
		return id;
	}

	static function getInjectionIDAndMarkSupplied( complexType:ComplexType, name:String ) {
		var id = formatMappingId( complexType, name );
		return id;
	}

	// /**
	// Get the fully qualified TypeName for an Injector with a particular name.
	// @param injectorName The unique name of the injector.
	// @return A String with the fully qualified TypePath for the injector with that name.
	// **/
	// public static function getQualifiedInjectorTypeName( injectorName:String ):String {
	// 	return 'dodrugs.instances.InjectorInstance_$injectorName';
	// }

	/**
	Use metadata to track which injectors have been created, and give errors if an injector name is created multiple times.

	This ensures that each injector is unique to the codebase, and we can know with confidence which rules are available within the injector.

	@param name The unique name of the injector.
	@param pos The position to report an error if the unique name has already been used.
	@throws Generates a compile time error if the Injector has been created more than once in this code base.
	**/
	public static function checkInjectorIsNotAlreadyCreated( name:String, pos:Position ) {
		switch Context.getType( "dodrugs.InjectorInstance") {
			case TInst( _.get() => classType, _ ):
				var nameMetaParam = macro @:pos(pos) $v{name};
				if ( !classType.meta.has(':injectorNamesCreated') ) {
					classType.meta.add( ':injectorNamesCreated', [nameMetaParam], pos );
				}
				else {
					var namesCreatedMeta = classType.meta.extract( ':injectorNamesCreated' )[0];
					var namesUsed = namesCreatedMeta.params;
					var oldEntry = Lambda.find( namesUsed, function (e) return switch e {
						case { expr:EConst(CString(nameUsed)), pos:_ }: return nameUsed==name;
						case _: false;
					} );
					if ( oldEntry==null ) {
						namesUsed.push( nameMetaParam );
						classType.meta.remove( ':injectorNamesCreated' );
						classType.meta.add( ':injectorNamesCreated', namesUsed, pos );
					}
					else {
						var previousPos = oldEntry.pos;
						Context.warning( 'An Injector named "${name}" was previously created here', previousPos );
						Context.warning( 'And a different Injector named "${name}" is being created here', pos );
						Context.error( 'Error: duplicate Injector name used', pos );
					}
				}
			case _:
		}
	}

	/**
	Reset the @:injectorNamesCreated metadata on the InjectorInstance type at the start of each build.

	It is currently called as part of `InjectorBuildMacro.build()`.
	It has no effect on the building of the class, and is solely used to trigger a `Context.onMacroContextReused` callback to reset the metadata on each build.

	@return Always returns null.
	**/
	public static function resetInjectorNamesCreatedMetadata() {
		Context.onMacroContextReused(function() {
			switch Context.getType( "dodrugs.InjectorInstance") {
				case TInst( _.get() => classType, _ ):
					classType.meta.remove( ':injectorNamesCreated' );
				case _:
			}
			return true;
		});
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
		var name:String = null;
		var complexType;

		switch mapType {
			case macro $expr.named($nameExpr):
				mapType = expr;
				name = nameExpr.getString().sure();
			case _:
		}

		switch mapType {
			case macro $i{typeName}:
				complexType = typeName.asComplexType();
			case macro (_:$ct):
				complexType = ct;
			case macro ($i{nameStr}:$ct):
				complexType = ct;
				name = nameStr;
			case { expr:EConst(CString(typeStr)), pos:pos }:
				try {
					switch Context.parse( '(_:$typeStr)', pos ) {
						case macro (_:$ct): complexType = ct;
						case _:
					}
				}
				catch ( e:Dynamic ) {
					Context.error( 'Failed to understand type $typeStr', pos );
				}
			case exprIsTypePath(_) => outcome:
				var typeName = outcome.sure();
				complexType = typeName.asComplexType();
			case _:
				mapType.reject( 'Incorrect syntax for mapping type: ${mapType.toString()} could not be understood' );
		}

		return new Pair( complexType, name );
	}

	static function formatMappingId( complexType:ComplexType, name:String ) {
		var complexTypeStr = complexType.toString();
		// type.toComplex().toString() does not handle const parameters correctly.
		// For example showing "dodrugs.NamedInjectorInstance<.SclassInstantiationInjector>" instead of dodrugs.NamedInjectorInstance<"classInstantiationInjector">
		var weirdTypeStr = ~/([a-zA-Z0-9_.]+)<\.S([a-zA-Z0-9]+)>/;
		if ( weirdTypeStr.match(complexTypeStr) ) {
			var typeName = weirdTypeStr.matched( 1 );
			var typeParam = weirdTypeStr.matched( 2 );
			complexTypeStr = '$typeName<"$typeParam">';
		}
		// In case the type has constant type parameters, standardize on double quotes.
		complexTypeStr = StringTools.replace( complexTypeStr, "\'", "\"" );
		return (name!=null) ? '${complexTypeStr} ${name}' : complexTypeStr;
	}

	static function makeTypePathAbsolute( ct:ComplexType, pos:Position ):ComplexType {
		// If it is dodrugs.Injector<"name">, we don't want to expand that to dodrugs.InjectorInstance.
		// So we'll manually check for it and make it absolute without calling "toType()".
		switch ct {
			case TPath({ pack:[], name:"Injector", params:params }), TPath({ pack:["dodrugs"], name:"Injector", params:params }):
				return TPath({ pack:["dodrugs"], name:"NamedInjectorInstance", params:params });
			case _:
		}
		return ct.toType( pos ).sure().toComplex();
	}
}
