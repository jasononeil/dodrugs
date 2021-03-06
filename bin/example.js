// Generated by Haxe 3.4.4
(function () { "use strict";
function $extend(from, fields) {
	function Inherit() {} Inherit.prototype = from; var proto = new Inherit();
	for (var name in fields) proto[name] = fields[name];
	if( fields.toString !== Object.prototype.toString ) proto.toString = fields.toString;
	return proto;
}
var Example = function() { };
Example.main = function() {
	var person = Example.setupInjector()._get("Example.Person");
	console.log("I am " + person.name + ", I am " + person.age + " years old and I have " + person.favouriteNumbers.length + " favourite numbers");
};
Example.setupInjector = function() {
	var leastFavouriteNumbers = [-1,3,366];
	return new dodrugs_Injector("exampleInjector",null,{ 'StdTypes.Int age' : function(_,_1) {
		return 28;
	}, 'String.String name' : function(_2,_3) {
		return "Jason";
	}, 'Array.Array<StdTypes.Int>' : function(_4,_5) {
		return [0,1,2];
	}, 'Array.Array<StdTypes.Int> leastFavouriteNumbers' : function(_6,_7) {
		return leastFavouriteNumbers;
	}, 'Example.Person' : function(inj,id) {
		return inj._getSingleton(inj,function(inj1,id1) {
			return (function(inj2,id2) {
				return new Person(inj2._get("String.String name"),inj2._get("StdTypes.Int age"),inj2._get("Array.Array<StdTypes.Int> anArray"),inj2._tryGet("Array.Array<StdTypes.Int> leastFavouriteNumbers",null));
			})(inj1,id1);
		},id);
	}});
};
var Person = function(name,age,anArray,leastFavouriteNumbers) {
	this.name = name;
	this.age = age;
	this.favouriteNumbers = anArray;
	this.leastFavouriteNumbers = leastFavouriteNumbers;
};
var dodrugs_UntypedInjector = function(parent,mappings) {
	var _gthis = this;
	this.parent = parent;
	this.mappings = mappings;
	if(!Object.prototype.hasOwnProperty.call(mappings,"dodrugs.UntypedInjector.UntypedInjector")) {
		mappings["dodrugs.UntypedInjector.UntypedInjector"] = function(_,_1) {
			return _gthis;
		};
	}
};
dodrugs_UntypedInjector.prototype = {
	_get: function(id,injectorThatRequested) {
		if(injectorThatRequested == null) {
			injectorThatRequested = this;
		}
		var wildcardId = id.split(" ")[0];
		if(Object.prototype.hasOwnProperty.call(this.mappings,id)) {
			return this.mappings[id](injectorThatRequested,id);
		} else if(wildcardId != id && Object.prototype.hasOwnProperty.call(this.mappings,wildcardId)) {
			return this.mappings[wildcardId](injectorThatRequested,wildcardId);
		} else if(this.parent != null) {
			return this.parent._get(id,injectorThatRequested);
		} else {
			throw new js__$Boot_HaxeError("The injection had no mapping for \"" + id + "\" in injector \"" + this.name + "\"");
		}
	}
	,_tryGet: function(id,fallback) {
		try {
			return this._get(id);
		} catch( e ) {
			return fallback;
		}
	}
	,_getSingleton: function(injectorThatRequested,mapping,id) {
		var val = mapping(this,id);
		injectorThatRequested.mappings[id] = function(_,_1) {
			return val;
		};
		return val;
	}
};
var dodrugs_Injector = function(name,parent,mappings) {
	var _gthis = this;
	dodrugs_UntypedInjector.call(this,parent,mappings);
	this.name = name;
	if(!Object.prototype.hasOwnProperty.call(mappings,"dodrugs.Injector.Injector<\"" + name + "\">")) {
		mappings["dodrugs.Injector.Injector<\"" + name + "\">"] = function(_,_1) {
			return _gthis;
		};
	}
};
dodrugs_Injector.__super__ = dodrugs_UntypedInjector;
dodrugs_Injector.prototype = $extend(dodrugs_UntypedInjector.prototype,{
});
var js__$Boot_HaxeError = function(val) {
	Error.call(this);
	this.val = val;
	this.message = String(val);
	if(Error.captureStackTrace) {
		Error.captureStackTrace(this,js__$Boot_HaxeError);
	}
};
js__$Boot_HaxeError.wrap = function(val) {
	if((val instanceof Error)) {
		return val;
	} else {
		return new js__$Boot_HaxeError(val);
	}
};
js__$Boot_HaxeError.__super__ = Error;
js__$Boot_HaxeError.prototype = $extend(Error.prototype,{
});
Example.main();
})();
