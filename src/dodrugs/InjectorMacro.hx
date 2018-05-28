package dodrugs;

import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
import tink.core.Outcome;
import tink.core.Pair;
using tink.MacroApi;

#if (haxe_ver <= 3.5)
typedef ObjectField = {
	field: String,
	expr: Expr
};
#end

/**
Macros used internally by `dodrugs.Injector`.
**/
class InjectorMacro {

	inline static var META_INJECTOR_NAMES_CREATED = ":injectorNamesCreated";
	inline static var META_INJECTOR_PARENT = ":injectorParent_";
	inline static var META_MAPPINGS_SUPPLIED = ":mappingsSupplied_";
	inline static var META_MAPPINGS_REQUIRED = ":mappingsRequired_";
	inline static var META_MAPPINGS_REQUIRED_BY_ASSOCIATION = ":mappingsRequiredByAssociation_";

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
		var parentName = getIdOfInjector(parent);
		var parentId = (parentName != null) ? macro $i{parentName} : macro null;
		meta.add( metaName, [parentId], pos );

		// Return `new Injector<"id">( name, parent, mappings )`, which will trigger the Injector @:genericBuild.
		var mappingsExpr = generateMappings( name, mappings );
		var param = TPExpr( macro $v{name} );
		var typePath = "dodrugs.Injector".asTypePath([ param ]);
		return macro @:pos(pos) @:privateAccess new $typePath(@:noPrivateAccess $v{name}, @:noPrivateAccess $parent, @:noPrivateAccess $mappingsExpr );
	}

	/**
	Get the injector ID string from an expression

	@param injector An expression representing the injector
	@return A String containing the name of the injector, or `null` if it was not found.
	**/
	public static function getIdOfInjector(injector: Expr): Null<String> {
		switch injector.typeof() {
			case Success(TInst(_.toString() => "dodrugs.Injector", [TInst(_.get() => paramClassType, [])])):
				switch paramClassType.kind {
					case KExpr({expr: EConst(CString(name))}):
						return name;
					default:
				}
			default:
		};
		return null;
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
	public static function processMappingExpr(injectorId:Null<String>, mappingExpr:Expr): ObjectField {
		var details = getMappingDetailsFromExpr(mappingExpr),
			ct = details.ct,
			result = {
			field: details.mappingId,
			expr: null
		};
		// Haxe will reject UntypedInjector->String->T as different to UntypedInjector->String->Any.
		// This function wrapping is a hack to make it unify.
		function makeFnReturnAny(fn: Expr) {
			return macro @:pos(fn.pos) function (inj:dodrugs.UntypedInjector, id:String): std.Any {
				return ($fn: dodrugs.UntypedInjector->String->$ct)(inj, id);
			}
		}
		switch details.assignment {
			case macro @:toClass $classExpr:
				result.expr = makeFnReturnAny(buildClassInstantiationFn(injectorId, result.field, classExpr, ct));
			case macro @:toSingletonClass $classExpr:
				var fnExpr = buildClassInstantiationFn(injectorId, result.field, classExpr, ct);
				fnExpr = makeFnReturnAny(fnExpr);
				result.expr = macro @:pos(classExpr.pos) function(inj:dodrugs.UntypedInjector,id:String): std.Any {
					return @:privateAccess inj._getSingleton(inj, @:noPrivateAccess $fnExpr, id);
				}
			case macro @:toFunction $fn:
				result.expr = macro ($fn: dodrugs.UntypedInjector->String->$ct);
			case macro @:toSingletonFunction $fn:
				var fnWithAnyReturn = makeFnReturnAny(fn);
				result.expr = macro @:pos(fn.pos) function(inj:dodrugs.UntypedInjector,id:String): std.Any {
					return @:privateAccess inj._getSingleton(inj, @:noPrivateAccess $fnWithAnyReturn, id);
				}
			case macro $value:
				result.expr = macro @:pos(value.pos) function(_:dodrugs.UntypedInjector, _:String): std.Any {
					return ($value:$ct);
				}
		}
		if (details.preferParent) {
			var mappingFn = result.expr;
			result.expr = macro @:pos(result.expr.pos) function (inj: dodrugs.UntypedInjector, id: String): std.Any {
				return @:privateAccess inj._getPreferingParent(id, @:noPrivateAccess $mappingFn);
			}
		}
		if (injectorId!=null) {
			markInjectionStringAsSupplied(injectorId, result.field, mappingExpr.pos);
		}
		return result;
	}



	/**
	Add special metadata to UntypedInjector noting that this injection is required somewhere in the code base.

	This will be used to check all required mappings are supplied during `Context.onGenerate()`, and produce helpful error messages otherwise.

	@param injectorId The String that identifies which injector this mapping is supplied/required on.
	@param injectionString The String that describes the mapping, including type and name. See `getInjectionStringFromExpr()`.
	@param pos The position where the mapping is required. This will be used to generate error messages in the correct place.
	**/
	public static function markInjectionStringAsRequired( injectorId:Null<String>, injectionString:String, pos:Position ) {
		var metaName = META_MAPPINGS_REQUIRED + injectorId;
		markInjectionStringMetadata( metaName, injectionString, pos );
	}

	/**
	Mark that a particular mapping will be required if another mapping is called.
	This allows us to not mark something as required unless an explicit `get()` call is made.
	This is useful for parent mappings which depend on something being present in the child injector.
	**/
	static function markInjectionStringAsRequiredByAssociation(injectorId: String, injectionString: String, isRequiredBy: String, pos: Position) {
		var metaName = META_MAPPINGS_REQUIRED_BY_ASSOCIATION + injectorId + "_" + isRequiredBy;
		markInjectionStringMetadata(metaName, injectionString, pos);
	}

	/**
	Add special metadata to UntypedInjector noting that this injection is supplied when the injector is created.

	This will be used to check all required mappings are supplied during `Context.onGenerate()`, and produce helpful error messages otherwise.

	@param injectorId The String that identifies which injector this mapping is supplied/required on.
	@param injectionStrin The String that describes the mapping, including type and name. See `getInjectionStringFromExpr()`.
	@param pos The position where the injector is created. This will be used to generate error messages in the correct place.
	**/
	public static function markInjectionStringAsSupplied( injectorId:Null<String>, injectionString:String, pos:Position ) {
		var metaName = META_MAPPINGS_SUPPLIED + injectorId;
		markInjectionStringMetadata( metaName, injectionString, pos );
	}

	static function buildClassInstantiationFn( injectorId:Null<String>, isRequiredBy:String, classExpr:Expr, ct:ComplexType ):Expr {
		var p = classExpr.pos;
		// Get the TypePath, ComplexType and Type based on the classExpr.
		var className = exprIsTypePath( classExpr ).sure();
		var targetTypePath = className.asTypePath();
		var targetComplexType = TPath( targetTypePath );
		var targetType = targetComplexType.toType().sure();
		var targetClassType = switch targetType {
			case TInst(t,_): t.get();
			case _: Context.error( '${className} is not a class', p );
		}
		targetComplexType = targetType.toComplex();
		targetTypePath = switch targetComplexType {
			case TPath(tp): tp;
			case _: throw 'assert';
		}
		var constructorLines = getConstructorExpressions( injectorId, isRequiredBy, targetClassType, targetTypePath, p );
		return macro @:pos(p) function(inj:dodrugs.UntypedInjector,id:String):$ct $b{constructorLines};
	}

	static function getConstructorExpressions( injectorId:Null<String>, isRequiredBy:String, type:ClassType, typePath:TypePath, pos:Position ):Array<Expr> {
		var constructor = getConstructorForType( type, pos ).sure();
		var constructorLines = [];
		var constructorArguments = [];
		var fnArgumentLines = getArgumentsForMethodInjection( injectorId, isRequiredBy, constructor, pos );
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

	static function getArgumentsForMethodInjection(injectorId:Null<String>, isRequiredBy:String, method:ClassField, injectionPos:Position):Array<Pair<Expr,Expr>> {
		switch [method.kind, method.expr().expr] {
			case [FMethod(_), TFunction({ args:methodArgs, expr:_, t:_ })]:
				var argumentExprs = [];
				for (i in 0...methodArgs.length) {
					var varName = methodArgs[i].v.name;
					var injectionName = (varName != "_") ? varName : null;
					var getValueExpr = getExprForFunctionArg( injectorId, isRequiredBy, methodArgs[i], injectionName, method.pos );
					var identExpr = macro $i{varName};
					var setValueExpr = macro var $varName = $getValueExpr;
					argumentExprs.push( new Pair(identExpr,setValueExpr) );
				}
				return argumentExprs;
			case _:
				Context.warning('Internal Injector Error: ${method.name} is not a method', method.pos);
		}
		return [];
	}

	static function getExprForFunctionArg( injectorId:Null<String>, isRequiredBy:String, methodArg:{v:TVar, value:Null<TConstant>}, injectionName:Null<String>, pos:Position ):Expr {
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
		return generateExprToGetValueFromInjector( injectorId, isRequiredBy, paramType, injectionName, defaultValue, pos );
	}

	static function checkIfTypeIsOptional( t:Type, defaultValue:Null<Expr> ) {
		switch t {
			#if (haxe_ver <= 3.5)
				case TType(_.toString()=>"Null", _[0]=>actualType):
			#else
				case TAbstract(_.toString()=>"Null", _[0]=>actualType):
			#end
				return new Pair( actualType, (defaultValue!=null) ? defaultValue : macro null );
			case _:
				return new Pair( t, defaultValue );
		}
	}

	static function generateExprToGetValueFromInjector( injectorId:Null<String>, isRequiredBy:String, type:Type, injectionName:Null<String>, defaultValue:Null<Expr>, pos:Position ):Expr {
		var injectionString = formatMappingId( type.toComplex(), injectionName );
		if ( defaultValue==null && injectorId!=null ) {
			markInjectionStringAsRequiredByAssociation( injectorId, injectionString, isRequiredBy, pos );
		}
		return
			if ( defaultValue!=null ) macro inj.tryGetFromId( $v{injectionString}, $defaultValue )
			else macro inj.getFromId( $v{injectionString} );
	}

	static function markInjectionStringMetadata( metaName:String, injectionString:String, pos:Position ) {
		var meta = getInjectorMeta();
		var injectionStringParam = macro @:pos(pos) $v{injectionString};
		if ( !meta.has(metaName) ) {
			meta.add( metaName, [injectionStringParam], pos );
		}
		else {
			var params = getMetadata(metaName)[0].params;
			params.push( injectionStringParam );
			meta.remove( metaName );
			meta.add( metaName, params, pos );
		}
	}

	static function getInjectorMeta() {
		switch Context.getType("dodrugs.UntypedInjector") {
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
			var namesCreatedMeta = getMetadata( META_INJECTOR_NAMES_CREATED )[0];
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
	Return an array of classes (as `package.dot.ClassName` expressions) that are needed to instantiate a new class.

	These expressions can be used as mappings in a new child injector so that the child injector will be able to isntantiate the `complexType`.

	@param complexType The complex type for the class you wish to instantiate
	@param excludeClassesProvidedBy Exclude classes that are already provided by an injector with this name. If null, no classes will be excluded.
	@param pos The position to use if we need to report any errors
	@return An array of expressions containing the type paths of the classes needed to instantiate the requested type.
	**/
	public static function getAllClassesRequiredToBuildType(complexType: ComplexType, ?excludeClassesProvidedBy: Null<String>, pos: Position): Array<Expr> {
		var type = complexType.toType(pos).sure();
		var suppliedTypes;
		if (excludeClassesProvidedBy != null) {
			suppliedTypes = getSuppliedTypesForInjectorId(excludeClassesProvidedBy);
		} else {
			suppliedTypes = new Map();
		}
		var allClassesRequired = new Map();
		switch type {
			case TInst(ref, _):
				findClassesRequiredToBuildType(allClassesRequired, suppliedTypes, ref.get(), null, pos);
			case _:
				Context.error('Expected a class, but was some other kind of type:' + type.getID(), pos);
		}
		return [for (expr in allClassesRequired) expr];
	}

	static function findClassesRequiredToBuildType(allClassesRequired: Map<String, Expr>, suppliedTypes: Map<String, MetadataEntry>, expectedClass: ClassType, expectedName: Null<String>, pos: Position) {
		var parts = [expectedClass.module, expectedClass.name];
		var classPathExpr = parts.drill(pos);
		var mappingId = getInjectionStringFromExpr(classPathExpr);
		if (!suppliedTypes.exists(mappingId) && expectedName != null) {
			// If a wildcard mapping doesn't exist, check if a named mapping does.
			// Note that the order doesn't matter for this check, we are just checking one of the options exists.
			mappingId = mappingId + ' $expectedName';
		}
		if (suppliedTypes.exists(mappingId)) {
			// Even though this class has a supplied mapping, it's possible some of its dependents do not.
			// If the suppliedTypes metadata has some parameters, they are types this one depends on.
			if (suppliedTypes[mappingId] != null) {
				var entry = suppliedTypes[mappingId];
				for (param in entry.params) {
					var dependentMappingId = param.getString().sure();
					var dependentTypeParts = dependentMappingId.split(' ')[0].split('.');
					var dependentComplexType = TPath({
						sub: dependentTypeParts.pop(),
						name: dependentTypeParts.pop(),
						pack: dependentTypeParts,
						params: null,
					});
					switch getInstantiableClassType(dependentComplexType, param.pos) {
						case Some(dependentClassType):
							findClassesRequiredToBuildType(allClassesRequired, suppliedTypes, dependentClassType.get(), null, param.pos);
						case None:
					}
				}
			}
			return;
		}
		allClassesRequired.set(mappingId, macro @:preferParentMapping $classPathExpr);
		// Check if any of the function arguments are also classes that we should be adding to the allClassesRequired map.
		var constructor = getConstructorForType(expectedClass, pos).sure();
		var fn = Context.getTypedExpr(constructor.expr());
		switch fn.expr {
			case EFunction(null, {args: args}):
				for (arg in args) {
					switch getInstantiableClassType(arg.type, pos) {
						case Some(classTypeRef):
							// Add this class and recursively check it's constructor for other classes we might need.
							findClassesRequiredToBuildType(allClassesRequired, suppliedTypes, classTypeRef.get(), arg.name, pos);
						case None:
					}
				}
			case _:
				throw 'Expected unnamed function for constructor in ${parts.join('.')}';
		}
	}

	static function getInstantiableClassType(complexType: ComplexType, pos: Position): haxe.ds.Option<Ref<ClassType>> {
		var type = complexType.toType(pos).sure();
		switch type {
			case TInst(ref, _):
				var classType = ref.get();
				// Exclude Array, Date, EReg, IntIterator, List, String, StringBuf, SysError, Xml
				var excludedBasicTypes = [
					'Array',
					'Date',
					'EReg',
					'IntIterator',
					'List',
					'String',
					'StringBuf',
					'SysError',
					'Xml'
				];
				if (classType.pack.length != 0 || excludedBasicTypes.indexOf(classType.name) == -1) {
					return Some(ref);
				}
			default:
		}
		return None;
	}

	/**
	A build macro triggered on `Injector` to trigger various utilities, including:

	- trigger an `onMacroContextReused` callback to reset Injector metadata on each build when using the compiler cache.
		- TODO: test this, and see if META_INJECTOR_PARENT, META_MAPPINGS_REQUIRED, and META_MAPPINGS_SUPPLIED need resetting also.
	- trigger an `onGenerate` callback handler to check if all required injection mappings are supplied

	It has no effect on the building of the class, and is solely used to trigger the callbacks.
	**/
	public static function buildInjector() {
		Context.onGenerate(checkInjectorSuppliesAllRequirements);
		Context.onMacroContextReused(function() {
			var meta = getInjectorMeta();
			meta.remove( META_INJECTOR_NAMES_CREATED );
			return true;
		});
		return null;
	}

	static function generateMappings( injectorId:Null<String>, mappings:Expr ):Expr {
		var mappingRules: Array<ObjectField> = [];
		switch mappings {
			case macro [$a{mappingExprs}]:
				for ( mappingExpr in mappingExprs ) {
					var rule = processMappingExpr( injectorId, mappingExpr );
					mappingRules.push( rule );
				}
			case _:
				mappings.reject( 'Injector rules should be provided using Array syntax, with each mapping being an array item.' );
		}
		var objDecl = { expr:EObjectDecl(mappingRules), pos:mappings.pos };
		return macro ($objDecl:haxe.DynamicAccess<dodrugs.InjectorMapping<std.Any>>);
	}

	/**
	Check if an expression is a Type Path,
	**/
	static function exprIsTypePath(expr:Expr, ?needsToBeUpper=true):Outcome<String,Error> {
		function failure() return Failure(new Error('Not a valid type path: ${expr.toString()}', expr.pos));
		function firstCharIsUpper(s:String) return s.charAt(0)==s.charAt(0).toUpperCase();
		switch expr {
			case {expr: EMeta(_, expr)}:
				// Ignore any metadata.
				return exprIsTypePath(expr, needsToBeUpper);
			case macro $i{ident}:
				return
					if (firstCharIsUpper(ident) || needsToBeUpper==false) Success(ident);
					else failure();
			case macro $parent.$field:
				if (needsToBeUpper && firstCharIsUpper(field)==false)
					return failure();
				switch exprIsTypePath(parent,false) {
					case Success(tp): return Success('$tp.$field');
					case Failure(err): return failure();
				}
			case _: return failure();
		}
	}

	static function getMappingDetailsFromExpr(mapType:Expr):{ct:ComplexType,id:String,mappingId:String,assignment:Expr,preferParent:Bool} {
		var details = {
			ct: null,
			id: null,
			mappingId: null,
			assignment: null,
			preferParent: false
		};
		// If there is @:preferParentMapping metadata, take note and we'll use that when generating the mapping.
		switch mapType {
			case macro @:preferParentMapping $expr:
				mapType = expr;
				details.preferParent = true;
			default:
		}
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
			case exprIsTypePath(_) => Success(typePathStr):
				// They've just given a class name or TypePath.
				// This is essentially the same as `var _:path.To.Type = path.To.Type`
				details.ct = typePathStr.asComplexType();
				var assignment = typePathStr.resolve();
				// Check if it has @:toClass metadata, otherwise assume @:toSingletonClass.
				details.assignment = switch mapType {
					case macro @:toClass $typePath:
						macro @:toClass $assignment;
					default:
						macro @:toSingletonClass $assignment;
				}
			case (macro $i{variableName}):
				try {
					var type = Context.typeof(mapType);
					details.ct = Context.toComplexType(type);
					details.id = variableName;
					details.assignment = mapType;
					if (details.ct == null)
						throw 'Unknown type for ${mapType.toString()}';
				} catch (e: Dynamic) {
					Context.warning('Failed to understand type ${mapType.toString()}', mapType.pos);
					Context.warning('Perhaps use the format `var $variableName:MyType = $variableName`', mapType.pos);
					return mapType.reject('Error: ' + e);
				}
			default:
				try {
					var type = Context.typeof(mapType);
					details.ct = Context.toComplexType(type);
					details.id = null;
					details.assignment = mapType;
					if (details.ct == null)
						throw 'Unknown type for ${mapType.toString()}';
				} catch (e: Dynamic) {
					Context.warning('Failed to understand type ${mapType.toString()}', mapType.pos);
					Context.warning('Perhaps use the format `var _:MyType = ${mapType.toString()}`', mapType.pos);
					return mapType.reject('Error: ' + e);
				}
		}
		details.ct = makeTypePathAbsolute(details.ct, mapType.pos);
		details.mappingId = formatMappingId(details.ct, details.id);
		return details;
	}

	static function formatMappingId( complexType:ComplexType, name:String ) {
		var complexTypeStr = complexTypeToString(complexType);
		return (name!=null) ? '${complexTypeStr} ${name}' : complexTypeStr;
	}

	static function complexTypeToString( complexType:ComplexType ) {
		var complexTypeStr = complexType.toString();

		// Prior to 0.16.1, tink_macro would print String.String instead of just String.
		// See https://github.com/haxetink/tink_macro/commit/9cd59d39895c4e45105fb7114618b389f1b2b457
		// if (tink_macro <= 0.16.1)
		var version = Context.getDefines().get('tink_macro').split(".").map(Std.parseInt);
		if (
			version[0] == 0
			&& version[1] <= 16
			&& (version[1] < 16 || version[2] == 1)
		) {
			// Regex to match reptition like String.String or Array.Array but not String.StringTools
			var repeatedTypeNameSearch = ~/\b([A-Z][A-Za-z0-9_]*)\.\1\b/g;
			complexTypeStr = repeatedTypeNameSearch.replace(complexTypeStr, '$1');
		}

		// So `type.toComplex().toString()` does not handle const parameters correctly.
		// For example instead of `dodrugs.Injector<"classInstantiationInjector">` it shows `dodrugs.Injector<.SclassInstantiationInjector>`
		// Unfortunately `Array<SomeModule.SomeType>` is indistinguishable from `Array<"omeModule.SomeType">` so we will only handle this for the dodrugs.Injector use case.
		var weirdTypeStr = ~/dodrugs\.Injector<[a-zA-Z0-9\.]*\.S([a-zA-Z0-9]+)>/;
		if ( weirdTypeStr.match(complexTypeStr) ) {
			var typeParam = weirdTypeStr.matched( 1 );
			complexTypeStr = 'dodrugs.Injector<"$typeParam">';
		}
		// In case the type has constant type parameters, standardize on double quotes.
		complexTypeStr = StringTools.replace( complexTypeStr, "\'", "\"" );
		return complexTypeStr;
	}

	static function makeTypePathAbsolute( ct:ComplexType, pos:Position ):ComplexType {
		// If it is dodrugs.Injector<"name">, we don't want to expand that to dodrugs.UntypedInjector.
		// So we'll manually check for it and make it absolute without calling "toType()".
		switch ct {
			case TPath({ pack:[], name:"Injector", params:params }), TPath({ pack:["dodrugs"], name:"Injector", params:params }):
				return TPath({ pack:["dodrugs"], name:"Injector", params:params });
			case _:
		}
		return ct.toType( pos ).sure().toComplex();
	}

	static function checkInjectorSuppliesAllRequirements(types: Array<Type>) {
		var injectorIDs = getAllInjectorIDs();
		var allSuppliedTypes = getAllSuppliedTypes(injectorIDs);
		var allExplicitlyRequiredTypes = getAllRequiredTypes(injectorIDs);
		for (injectorId in allExplicitlyRequiredTypes.keys()) {
			var injectorHandlingRequest = allExplicitlyRequiredTypes[injectorId];
			var requiredTypes = injectorHandlingRequest.requiredTypes;
			if (requiredTypes.length > 0) {
				var suppliedTypes = allSuppliedTypes[injectorId].suppliedTypes;
				checkRequiredAgainstSupplied(requiredTypes, suppliedTypes, injectorHandlingRequest.createdAt);
			}
		}
	}

	static function getAllInjectorIDs() {
		return getMetadata(META_INJECTOR_NAMES_CREATED)[0].params;
	}

	static function getMetadata(name: String) {
		var meta = getInjectorMeta();
		return [for (entry in meta.get()) if (entry.name == name) entry];
	}

	static function getAllSuppliedTypes(injectorIDs: Array<Expr>): Map<String, {
		injectorId: String,
		createdAt: Position,
		suppliedTypes: Map<String, MetadataEntry>
	}> {
		var map = new Map();
		for (expr in injectorIDs) {
			var id = expr.getString().sure();
			map.set(id, {
				injectorId: id,
				createdAt: expr.pos,
				suppliedTypes: getSuppliedTypesForInjectorId(id)
			});
		}
		return map;
	}

	static function getSuppliedTypesForInjectorId(injectorId: String): Map<String,MetadataEntry> {
		var suppliedTypes = new Map();
		while (injectorId != null) {
			var requiredByAssociationMetaPrefix = META_MAPPINGS_REQUIRED_BY_ASSOCIATION + injectorId + '_';
			var suppliedMetaName = META_MAPPINGS_SUPPLIED + injectorId;
			var suppliedTypesMeta = getMetadata(suppliedMetaName)[0];
			if (suppliedTypesMeta!=null) {
				for (expr in suppliedTypesMeta.params) {
					var id = expr.getString().sure();
					// Look for related types this depends on - later when we're checking that required types are supplied, we'll also check these.
					var associatedRequirementsMetaName = requiredByAssociationMetaPrefix + id;
					var typesThisDependsOn = getMetadata(associatedRequirementsMetaName)[0];
					suppliedTypes[id] = typesThisDependsOn;
				}
			}
			injectorId = getParentId(injectorId);
		}
		return suppliedTypes;
	}

	static function getParentId(childId: String): String {
		var parentMetaName = META_INJECTOR_PARENT + childId;
		if (getMetadata(parentMetaName)[0] == null) {
			throw 'Child injector $childId does not exist';
		}
		var parentExpr = getMetadata(parentMetaName)[0].params[0];
		switch parentExpr {
			case macro null: return null;
			case {expr: EConst(CIdent(id)), pos: _}: return id;
			case _: throw 'Internal Error: '+parentExpr;
		}
	}

	static function getAllRequiredTypes(injectorIDs: Array<Expr>): Map<String, {
		injectorId: String,
		createdAt: Position,
		requiredTypes: Array<Expr>
	}> {
		var map = new Map();
		for (expr in injectorIDs) {
			var id = expr.getString().sure();
			map.set(id, {
				injectorId: id,
				createdAt: expr.pos,
				requiredTypes: getRequiredTypesForInjectorId(id)
			});
		}
		return map;
	}

	static function getRequiredTypesForInjectorId(injectorId: String): Array<Expr> {
		var requiredMetaName = META_MAPPINGS_REQUIRED + injectorId;
		var requiredMappingsMeta = getMetadata(requiredMetaName)[0];
		if (requiredMappingsMeta != null && requiredMappingsMeta.params != null) {
			return requiredMappingsMeta.params;
			}
		return [];
		}

	static function checkRequiredAgainstSupplied(required: Array<Expr>, suppliedTypes: Map<String, MetadataEntry>, injectorPos: Position) {
		for (requiredMappingExpr in required) {
			var mappingId = requiredMappingExpr.getString().sure();
			var wildcardMappingId = mappingId.split(' ')[0];
			if (!suppliedTypes.exists(mappingId) && !suppliedTypes.exists(wildcardMappingId)) {
				var mappingName = StringTools.replace(mappingId, ' ', ' with ID ');
				Context.warning('Mapping "$mappingName" is required here', requiredMappingExpr.pos);
				Context.error('Please make sure you provide a mapping for "$mappingName" here', injectorPos);
			} else {
				// The type is supplied. Check that dependent types are supplied too.
				var supplied = suppliedTypes.exists(mappingId) ? suppliedTypes[mappingId] : suppliedTypes[wildcardMappingId];
				if (supplied != null && supplied.params != null) {
					checkRequiredAgainstSupplied(supplied.params, suppliedTypes, injectorPos);
				}
			}
		}
	}
}
