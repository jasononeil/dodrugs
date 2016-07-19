package dodrugs;

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
using haxe.macro.Tools;
using tink.CoreApi;
using tink.MacroApi;

class InjectorMacro {

	inline static var META_INJECTOR_NAMES_CREATED = ":injectorNamesCreated";
	inline static var META_INJECTOR_PARENT = ":injectorParent_";
	inline static var META_MAPPINGS_SUPPLIED = ":mappingsSupplied_";
	inline static var META_MAPPINGS_REQUIRED = ":mappingsRequired_";

	/**
	Generate a new `InjectorInstance` (usually a @:genericBuild() from `Injector`) using the given parent and setting up the mappings.

	@param name The unique name of this injector.
	@param name An expression for the parent injector, or `null`.
	@param mappings An expression for the mappings that we will process and make available in this injector.
	@return An expression that will instantiate a new injector with the mappings appropriately processed.
	**/
	public static function generateNewInjector( name:String, parent:Expr, mappings:Expr ):Expr {
		var pos = Context.currentPos();
		checkInjectorIsNotAlreadyCreated( name, pos );
		// Add metadata to keep track of the parent.
		var meta = getInjectorInstanceMeta();
		var metaName = META_INJECTOR_PARENT + name;
		meta.add( metaName, [parent], pos );
		// Run a check at the end of compilation to check all injection mappings are there.
		Context.onGenerate( checkInjectorSuppliesAllRequirements.bind(name,pos) );
		// Return `new Injector<"id">( name, parent, mappings )`, which will trigger the Injector @:genericBuild.
		var mappingsExpr = generateMappings( name, mappings );
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
		return formatMappingId( complexType, pair.b );
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

	@param injectorID The Injector this mapping expression belongs to. This is required for compile-time checking that all required dependencies are supplied. If you do not require these checks, set the injectorID to null.
	@param mappingExpr The complete expression representing the mapping.
	@return An object with the `field` (the injection ID) and the `expr` (the mapping function). Ready to use in an EObjectDecl.
	**/
	public static function processMappingExpr( injectorID:Null<String>, mappingExpr:Expr ):{ field:String, expr:Expr } {
		var result = { field:null, expr:null };
		switch mappingExpr {
			case macro $mappingIDExpr.toClass( $classExpr ):
				result.field = getInjectionStringFromExpr( mappingIDExpr );
				result.expr = buildClassInstantiationFn( injectorID, classExpr );
			case macro $mappingIDExpr.toSingleton( $classExpr ):
				var fnExpr = buildClassInstantiationFn( injectorID, classExpr );
				result.field = getInjectionStringFromExpr( mappingIDExpr );
				result.expr = macro @:pos(classExpr.pos) function(inj:dodrugs.DynamicInjectorInstance,id:String):tink.core.Any return @:privateAccess inj._getSingleton( $fnExpr, id );
			case macro $mappingIDExpr.toValue( $e ):
				result.field = getInjectionStringFromExpr( mappingIDExpr );
				result.expr = macro @:pos(e.pos) function(_:dodrugs.DynamicInjectorInstance, _:String):tink.core.Any return ($e:tink.core.Any);
			case macro $mappingIDExpr.toFunction( $fn ):
				result.field = getInjectionStringFromExpr( mappingIDExpr );
				result.expr = fn;
			case exprIsTypePath(_) => outcome:
				var typeName = outcome.sure();
				result.field = getInjectionStringFromExpr( mappingExpr );
				result.expr = buildClassInstantiationFn( injectorID, mappingExpr );
			case _:
				return mappingExpr.reject( 'Mapping expression should end in .toClass(cls), .toSingleton(cls), .toValue(v) or .toFunction(fn)' );
		}
		if ( injectorID!=null )
			markInjectionStringAsSupplied( injectorID, result.field, mappingExpr.pos );
		return result;
	}



	/**
	Add special metadata to DynamicInjectorInstance noting that this injection is required somewhere in the code base.

	This will be used to check all required mappings are supplied during `Context.onGenerate()`, and produce helpful error messages otherwise.

	@param injectorID The String that identifies which injector this mapping is supplied/required on.
	@param injectionStrin The String that describes the mapping, including type and name. See `getInjectionStringFromExpr()`.
	@param pos The position where the mapping is required. This will be used to generate error messages in the correct place.
	**/
	public static function markInjectionStringAsRequired( injectorID:Null<String>, injectionString:String, pos:Position ) {
		var metaName = META_MAPPINGS_REQUIRED + injectorID;
		markInjectionStringMetadata( metaName, injectionString, pos );
	}

	/**
	Add special metadata to DynamicInjectorInstance noting that this injection is supplied when the injector is created.

	This will be used to check all required mappings are supplied during `Context.onGenerate()`, and produce helpful error messages otherwise.

	@param injectorID The String that identifies which injector this mapping is supplied/required on.
	@param injectionStrin The String that describes the mapping, including type and name. See `getInjectionStringFromExpr()`.
	@param pos The position where the injector is created. This will be used to generate error messages in the correct place.
	**/
	public static function markInjectionStringAsSupplied( injectorID:Null<String>, injectionString:String, pos:Position ) {
		var metaName = META_MAPPINGS_SUPPLIED + injectorID;
		markInjectionStringMetadata( metaName, injectionString, pos );
	}

	static function buildClassInstantiationFn( injectorID:Null<String>, classExpr:Expr ):Expr {
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
		var constructorLines = getConstructorExpressions( injectorID, targetClassType, targetTypePath, p );
		var methodInjections = getMethodInjectionExpressions( injectorID, targetClassType, p );
		var propertyInjections = getPropertyInjectionExpressions( injectorID, targetClassType, p );
		var postInjections = getPostInjectionExpressions( targetClassType, p );

		var allLines = [for (arr in [constructorLines,methodInjections,propertyInjections,postInjections]) for (line in arr) line];
		allLines.push( macro return (o:tink.core.Any) );
		return macro @:pos(p) function(inj:dodrugs.DynamicInjectorInstance,id:String):tink.core.Any $b{allLines}
	}

	static function getConstructorExpressions( injectorID:Null<String>, type:ClassType, typePath:TypePath, pos:Position ):Array<Expr> {
		var constructor = getConstructorForType( type, pos ).sure();
		var constructorLines = [];
		var constructorArguments = [];
		var fnArgumentLines = getArgumentsForMethodInjection( injectorID, constructor, pos );
		for ( argPair in fnArgumentLines ) {
			constructorArguments.push( argPair.a );
			constructorLines.push( argPair.b );
		}
		constructorLines.push( macro @:pos(pos) var o = new $typePath($a{constructorArguments}) );
		return constructorLines;
	}

	static function getMethodInjectionExpressions( injectorID:Null<String>, type:ClassType, pos:Position ):Array<Expr> {
		var injectionExprs = [];
		var injectionFields = getPublicInstanceFieldsWithMeta( type, 'inject' );
		for ( field in injectionFields ) {
			if ( field.kind.match(FMethod(_)) ) {
				var fieldName = field.name;
				var fnArguments = [];
				var fnArgumentLines = getArgumentsForMethodInjection( injectorID, field, pos );
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

	static function getPropertyInjectionExpressions( injectorID:Null<String>, type:ClassType, pos:Position ):Array<Expr> {
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
				var getValueExpr = generateExprToGetValueFromInjector( injectorID, fieldType, injectionName, defaultValue, field.pos );
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

	static function getArgumentsForMethodInjection( injectorID:Null<String>, method:ClassField, injectionPos:Position ):Array<Pair<Expr,Expr>> {
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
						var getValueExpr = getExprForFunctionArg( injectorID, methodArgs[i], injectionName, method.pos );
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

	static function getExprForFunctionArg( injectorID:Null<String>, methodArg:{v:TVar, value:Null<TConstant>}, injectionName:Null<String>, pos:Position ):Expr {
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
		return generateExprToGetValueFromInjector( injectorID, paramType, injectionName, defaultValue, pos );
	}

	static function checkIfTypeIsOptional( t:Type, defaultValue:Null<Expr> ) {
		switch t {
			case TType(_.toString()=>"Null", _[0]=>actualType):
				return new Pair( actualType, (defaultValue!=null) ? defaultValue : macro null );
			case _:
				return new Pair( t, defaultValue );
		}
	}

	static function generateExprToGetValueFromInjector( injectorID:Null<String>, type:Type, injectionName:Null<String>, defaultValue:Null<Expr>, pos:Position ):Expr {
		var injectionString = formatMappingId( type.toComplex(), injectionName );
		if ( defaultValue==null && injectorID!=null ) {
			markInjectionStringAsRequired( injectorID, injectionString, pos );
		}
		return
			if ( defaultValue!=null ) macro inj.tryGetFromID( $v{injectionString}, $defaultValue )
			else macro inj.getFromID( $v{injectionString} );
	}

	static function markInjectionStringMetadata( metaName:String, injectionString:String, pos:Position ) {
		var meta = getInjectorInstanceMeta();
		var injectionStringParam = macro @:pos(pos) $v{injectionString};
		if ( !meta.has(metaName) ) {
			meta.add( metaName, [injectionStringParam], pos );
		}
		else {
			var params = meta.extract( metaName )[0].params;
			params.push( injectionStringParam );
			meta.remove( metaName );
			meta.add( metaName, params, pos );
		}
	}

	static function getInjectorInstanceMeta() {
		switch Context.getType("dodrugs.DynamicInjectorInstance") {
			case TInst( _.get() => classType, _ ):
				return classType.meta;
			default:
				return throw 'InjectorInstance should have been a class';
		}
	}

	/**
	Use metadata to track which injectors have been created, and give errors if an injector name is created multiple times.

	This ensures that each injector is unique to the codebase, and we can know with confidence which rules are available within the injector.

	@param name The unique name of the injector.
	@param pos The position to report an error if the unique name has already been used.
	@throws Generates a compile time error if the Injector has been created more than once in this code base.
	**/
	public static function checkInjectorIsNotAlreadyCreated( name:String, pos:Position ) {
		var meta = getInjectorInstanceMeta();
		var nameMetaParam = macro @:pos(pos) $v{name};
		if ( !meta.has(META_INJECTOR_NAMES_CREATED) ) {
			meta.add( META_INJECTOR_NAMES_CREATED, [nameMetaParam], pos );
		}
		else {
			var namesCreatedMeta = meta.extract( META_INJECTOR_NAMES_CREATED )[0];
			var namesUsed = namesCreatedMeta.params;
			var oldEntry = Lambda.find( namesUsed, function (e) return switch e {
				case { expr:EConst(CString(nameUsed)), pos:_ }: return nameUsed==name;
				case _: false;
			} );
			if ( oldEntry==null ) {
				namesUsed.push( nameMetaParam );
				meta.remove( META_INJECTOR_NAMES_CREATED );
				meta.add( META_INJECTOR_NAMES_CREATED, namesUsed, pos );
			}
			else {
				var previousPos = oldEntry.pos;
				Context.warning( 'An Injector named "${name}" was previously created here', previousPos );
				Context.warning( 'And a different Injector named "${name}" is being created here', pos );
				Context.error( 'Error: duplicate Injector name used', pos );
			}
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
			var meta = getInjectorInstanceMeta();
			meta.remove( META_INJECTOR_NAMES_CREATED );
			return true;
		});
	}

	static function generateMappings( injectorID:Null<String>, mappings:Expr ):Expr {
		var mappingRules = [];
		switch mappings {
			case macro [$a{mappingExprs}]:
				for ( mappingExpr in mappingExprs ) {
					var rule = processMappingExpr( injectorID, mappingExpr );
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
		// For example showing "dodrugs.InjectorInstance<.SclassInstantiationInjector>" instead of dodrugs.InjectorInstance<"classInstantiationInjector">
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
		// If it is dodrugs.Injector<"name">, we don't want to expand that to dodrugs.DynamicInjectorInstance.
		// So we'll manually check for it and make it absolute without calling "toType()".
		switch ct {
			case TPath({ pack:[], name:"Injector", params:params }), TPath({ pack:["dodrugs"], name:"Injector", params:params }):
				return TPath({ pack:["dodrugs"], name:"InjectorInstance", params:params });
			case _:
		}
		return ct.toType( pos ).sure().toComplex();
	}

	static function checkInjectorSuppliesAllRequirements( injectorID:String, creationPos:Position, types:Array<Type> ) {
		var requiredMetaName = META_MAPPINGS_REQUIRED + injectorID;
		var meta = getInjectorInstanceMeta();

		// Collect all the supplied injections for this injector and it's parent.
		var suppliedTypes = [];
		while ( injectorID!=null ) {
			var parentMetaName = META_INJECTOR_PARENT + injectorID;
			var suppliedMetaName = META_MAPPINGS_SUPPLIED + injectorID;
			var suppliedTypesMeta = meta.extract( suppliedMetaName )[0];
			if ( suppliedTypesMeta!=null ) {
				for ( expr in suppliedTypesMeta.params )
					suppliedTypes.push( expr.getString().sure() );
			}
			// See if there is a parent injector.
			if ( meta.extract( parentMetaName )[0]==null )
				// There is no metadata, meaning Injector.create() or Injector.extend() was never called.
				Context.error( 'Parent Injector $injectorID does not exist', creationPos );
			var parentExpr = meta.extract( parentMetaName )[0].params[0];
			switch parentExpr {
				case macro null:
					// Injector.create() was called, rather than extend(), so there is no parent.
					injectorID = null;
				case { expr: EConst(CIdent(id)), pos: _ }:
					injectorID = id;
					trace( "drill down into "+injectorID );
				case _:
					throw 'Internal Error: '+parentExpr;
			}
		}

		// Collect all the required injections and check they're supplied.
		var requiredMappingsMeta = meta.extract(requiredMetaName)[0];
		if ( requiredMappingsMeta!=null ) {
			for ( requiredMapping in requiredMappingsMeta.params ) {
				var mapping = requiredMapping.getString().sure();
				var isSupplied = suppliedTypes.indexOf( mapping ) > -1;
				if ( !isSupplied ) {
					var mappingName = StringTools.replace( mapping, ' ', ' named ' );
					Context.warning('Mapping "$mappingName" is required here', requiredMapping.pos);
					Context.error('Please make sure you provide a mapping for "$mappingName" here', creationPos);
				}
			}
		}
	}
}
