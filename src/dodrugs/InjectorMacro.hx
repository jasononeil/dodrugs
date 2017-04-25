package dodrugs;

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
import tink.core.Outcome;
import tink.core.Pair;
using tink.MacroApi;

/**
Macros used internally by `dodrugs.Injector`.
**/
class InjectorMacro {

	inline static var META_INJECTOR_NAMES_CREATED = ":injectorNamesCreated";
	inline static var META_INJECTOR_PARENT = ":injectorParent_";
	inline static var META_MAPPINGS_SUPPLIED = ":mappingsSupplied_";
	inline static var META_MAPPINGS_REQUIRED = ":mappingsRequired_";

	/**
	Generate a new `Injector` instance using the given name and parent, and setting up the mappings.

	@param name The unique name of this injector.
	@param name An expression for the parent injector, or `null`.
	@param mappings An expression for the mappings that we will process and make available in this injector.
	@return An expression that will instantiate a new injector with the mappings appropriately processed.
	**/
	public static function generateNewInjector( name:String, parent:Expr, mappings:Expr ):Expr {
		var pos = Context.currentPos();
		checkInjectorIsNotAlreadyCreated( name, pos );

		// Add metadata to keep track of the parent.
		var meta = getInjectorMeta();
		var metaName = META_INJECTOR_PARENT + name;
		var parentId = macro null;
		switch parent.typeof() {
			case Success(TInst(_.toString() => "dodrugs.Injector", [TInst(_.get() => paramClassType, [])])):
				switch paramClassType.kind {
					case KExpr({expr: EConst(CString(name))}):
						parentId = macro $i{name};
					default:
				}
			default:
		};
		meta.add( metaName, [parentId], pos );

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
	public static function getInjectionStringFromExpr(mapType:Expr):String {
		return getMappingDetailsFromExpr(mapType).mappingId;
	}

	/**
	Find the expected ComplexType based on the same expression used to get the injection string.

	@param mapType The expression representing the type or name we wish to reference.
	@return The complex type that this expression represents.
	**/
	public static function getComplexTypeFromIdExpr(mapType:Expr):ComplexType {
		return getMappingDetailsFromExpr(mapType).ct;
	}


	/**
	Process a mapping expression, and return the field and the mapping function.

	@param injectorId The Injector this mapping expression belongs to. This is required for compile-time checking that all required dependencies are supplied. If you do not require these checks, set the injectorId to null.
	@param mappingExpr The complete expression representing the mapping.
	@return An object with the `field` (the injection ID) and the `expr` (the mapping function). Ready to use in an EObjectDecl.
	**/
	public static function processMappingExpr(injectorId:Null<String>, mappingExpr:Expr):{ field:String, expr:Expr } {
		var details = getMappingDetailsFromExpr(mappingExpr);
		var result = {
			field: details.mappingId,
			expr: null
		};
		switch details.assignment {
			case macro @:toClass $classExpr:
				result.expr = buildClassInstantiationFn(injectorId, classExpr);
			case macro @:toSingletonClass $classExpr:
				var fnExpr = buildClassInstantiationFn(injectorId, classExpr);
				result.expr = macro @:pos(classExpr.pos) function(inj:dodrugs.DynamicInjector,id:String):Any {
					return @:privateAccess inj._getSingleton($fnExpr, id);
				}
			case macro @:toFunction $fn:
				result.expr = fn;
			case macro @:toSingletonFunction $fn:
				// Haxe will reject DynamicInjector->String->T as different to DynamicInjector->String->Any.
				// This function wrapping is a hack to make it unify.
				var fnWithAnyReturn = macro @:pos(fn.pos) function (inj:dodrugs.DynamicInjector, id:String):Any {
					return $fn(inj, id);
				}
				result.expr = macro @:pos(fn.pos) function(inj:dodrugs.DynamicInjector,id:String):Any {
					return @:privateAccess inj._getSingleton($fnWithAnyReturn, id);
				}
			case macro $value:
				result.expr = macro @:pos(value.pos) function(_:dodrugs.DynamicInjector, _:String):Any {
					return ($value:Any);
				}
		}
		if (injectorId!=null) {
			markInjectionStringAsSupplied(injectorId, result.field, mappingExpr.pos);
		}
		return result;
	}



	/**
	Add special metadata to DynamicInjector noting that this injection is required somewhere in the code base.

	This will be used to check all required mappings are supplied during `Context.onGenerate()`, and produce helpful error messages otherwise.

	@param injectorId The String that identifies which injector this mapping is supplied/required on.
	@param injectionStrin The String that describes the mapping, including type and name. See `getInjectionStringFromExpr()`.
	@param pos The position where the mapping is required. This will be used to generate error messages in the correct place.
	**/
	public static function markInjectionStringAsRequired( injectorId:Null<String>, injectionString:String, pos:Position ) {
		var metaName = META_MAPPINGS_REQUIRED + injectorId;
		markInjectionStringMetadata( metaName, injectionString, pos );
	}

	/**
	Add special metadata to DynamicInjector noting that this injection is supplied when the injector is created.

	This will be used to check all required mappings are supplied during `Context.onGenerate()`, and produce helpful error messages otherwise.

	@param injectorId The String that identifies which injector this mapping is supplied/required on.
	@param injectionStrin The String that describes the mapping, including type and name. See `getInjectionStringFromExpr()`.
	@param pos The position where the injector is created. This will be used to generate error messages in the correct place.
	**/
	public static function markInjectionStringAsSupplied( injectorId:Null<String>, injectionString:String, pos:Position ) {
		var metaName = META_MAPPINGS_SUPPLIED + injectorId;
		markInjectionStringMetadata( metaName, injectionString, pos );
	}

	static function buildClassInstantiationFn( injectorId:Null<String>, classExpr:Expr ):Expr {
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
		var constructorLines = getConstructorExpressions( injectorId, targetClassType, targetTypePath, p );
		return macro @:pos(p) function(inj:dodrugs.DynamicInjector,id:String):Any $b{constructorLines};
	}

	static function getConstructorExpressions( injectorId:Null<String>, type:ClassType, typePath:TypePath, pos:Position ):Array<Expr> {
		var constructor = getConstructorForType( type, pos ).sure();
		var constructorLines = [];
		var constructorArguments = [];
		var fnArgumentLines = getArgumentsForMethodInjection( injectorId, constructor, pos );
		for ( argPair in fnArgumentLines ) {
			constructorArguments.push( argPair.a );
			constructorLines.push( argPair.b );
		}
		constructorLines.push( macro @:pos(pos) return new $typePath($a{constructorArguments}) );
		return constructorLines;
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

	static function getArgumentsForMethodInjection( injectorId:Null<String>, method:ClassField, injectionPos:Position ):Array<Pair<Expr,Expr>> {
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
						var getValueExpr = getExprForFunctionArg( injectorId, methodArgs[i], injectionName, method.pos );
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

	static function getExprForFunctionArg( injectorId:Null<String>, methodArg:{v:TVar, value:Null<TConstant>}, injectionName:Null<String>, pos:Position ):Expr {
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
		return generateExprToGetValueFromInjector( injectorId, paramType, injectionName, defaultValue, pos );
	}

	static function checkIfTypeIsOptional( t:Type, defaultValue:Null<Expr> ) {
		switch t {
			case TType(_.toString()=>"Null", _[0]=>actualType):
				return new Pair( actualType, (defaultValue!=null) ? defaultValue : macro null );
			case _:
				return new Pair( t, defaultValue );
		}
	}

	static function generateExprToGetValueFromInjector( injectorId:Null<String>, type:Type, injectionName:Null<String>, defaultValue:Null<Expr>, pos:Position ):Expr {
		var injectionString = formatMappingId( type.toComplex(), injectionName );
		if ( defaultValue==null && injectorId!=null ) {
			markInjectionStringAsRequired( injectorId, injectionString, pos );
		}
		return
			if ( defaultValue!=null ) macro inj.trygetFromId( $v{injectionString}, $defaultValue )
			else macro inj.getFromId( $v{injectionString} );
	}

	static function markInjectionStringMetadata( metaName:String, injectionString:String, pos:Position ) {
		var meta = getInjectorMeta();
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

	static function getInjectorMeta() {
		switch Context.getType("dodrugs.DynamicInjector") {
			case TInst( _.get() => classType, _ ):
				return classType.meta;
			default:
				return throw 'Injector should have been a class';
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
		var meta = getInjectorMeta();
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
	A build macro triggered on `Injector` that will reset Injector metadata on each build when using the compiler cache.

	It has no effect on the building of the class, and is solely used to trigger a `Context.onMacroContextReused` callback to reset the metadata on each build.

	TODO: test this, and see if META_INJECTOR_PARENT, META_MAPPINGS_REQUIRED, and META_MAPPINGS_SUPPLIED need resetting also.

	@return Always returns null.
	**/
	public static function resetInjectorMetadata() {
		Context.onMacroContextReused(function() {
			var meta = getInjectorMeta();
			meta.remove( META_INJECTOR_NAMES_CREATED );
			return true;
		});
		return null;
	}

	static function generateMappings( injectorId:Null<String>, mappings:Expr ):Expr {
		var mappingRules = [];
		switch mappings {
			case macro [$a{mappingExprs}]:
				for ( mappingExpr in mappingExprs ) {
					var rule = processMappingExpr( injectorId, mappingExpr );
					mappingRules.push( rule );
				}
			case _:
				mappings.reject( 'Injector rules should be provided using Map Literal syntax.' );
		}
		var objDecl = { expr:EObjectDecl(mappingRules), pos:mappings.pos };
		return macro ($objDecl:haxe.DynamicAccess<dodrugs.InjectorMapping<Any>>);
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

	static function getMappingDetailsFromExpr(mapType:Expr):{ct:ComplexType,id:String,mappingId:String,assignment:Expr} {
		var details = {
			ct: null,
			id: null,
			mappingId: null,
			assignment: null
		};
		switch mapType {
			case (macro var _:$ct):
				details.ct = ct;
			case (macro var _:$ct = $assignment):
				details.ct = ct;
				details.assignment = assignment;
			case (macro var $varName:$ct):
				details.ct = ct;
				details.id = varName;
			case (macro var $varName:$ct = $assignment):
				details.ct = ct;
				details.id = varName;
				details.assignment = assignment;
			default:
				return mapType.reject( 'Incorrect syntax for mapping type: ${mapType.toString()} should be in the format `var injectionId:InjectionType`' );
		}
		details.ct = makeTypePathAbsolute(details.ct, mapType.pos);
		details.mappingId = formatMappingId(details.ct, details.id);
		return details;
	}

	static function formatMappingId( complexType:ComplexType, name:String ) {
		var complexTypeStr = complexType.toString();
		// type.toComplex().toString() does not handle const parameters correctly.
		// For example showing "dodrugs.Injector<.SclassInstantiationInjector>" instead of dodrugs.Injector<"classInstantiationInjector">
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
		// If it is dodrugs.Injector<"name">, we don't want to expand that to dodrugs.DynamicInjector.
		// So we'll manually check for it and make it absolute without calling "toType()".
		switch ct {
			case TPath({ pack:[], name:"Injector", params:params }), TPath({ pack:["dodrugs"], name:"Injector", params:params }):
				return TPath({ pack:["dodrugs"], name:"Injector", params:params });
			case _:
		}
		return ct.toType( pos ).sure().toComplex();
	}

	static function checkInjectorSuppliesAllRequirements( injectorId:String, creationPos:Position, types:Array<Type> ) {
		var requiredMetaName = META_MAPPINGS_REQUIRED + injectorId;
		var meta = getInjectorMeta();

		// Collect all the supplied injections for this injector and it's parent.
		var suppliedTypes = [];
		while ( injectorId!=null ) {
			var parentMetaName = META_INJECTOR_PARENT + injectorId;
			var suppliedMetaName = META_MAPPINGS_SUPPLIED + injectorId;
			var suppliedTypesMeta = meta.extract( suppliedMetaName )[0];
			if ( suppliedTypesMeta!=null ) {
				for ( expr in suppliedTypesMeta.params )
					suppliedTypes.push( expr.getString().sure() );
			}
			// See if there is a parent injector.
			if ( meta.extract( parentMetaName )[0]==null )
				// There is no metadata, meaning Injector.create() or Injector.extend() was never called.
				Context.error( 'Parent Injector $injectorId does not exist', creationPos );
			var parentExpr = meta.extract( parentMetaName )[0].params[0];
			switch parentExpr {
				case macro null:
					// Injector.create() was called, rather than extend(), so there is no parent.
					injectorId = null;
				case { expr: EConst(CIdent(id)), pos: _ }:
					injectorId = id;
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
					var mappingName = StringTools.replace( mapping, ' ', ' with ID ' );
					Context.warning('Mapping "$mappingName" is required here', requiredMapping.pos);
					Context.error('Please make sure you provide a mapping for "$mappingName" here', creationPos);
				}
			}
		}
	}
}
