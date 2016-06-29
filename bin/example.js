// Generated by Haxe 3.3.0
(function () { "use strict";
function $extend(from, fields) {
	function Inherit() {} Inherit.prototype = from; var proto = new Inherit();
	for (var name in fields) proto[name] = fields[name];
	if( fields.toString !== Object.prototype.toString ) proto.toString = fields.toString;
	return proto;
}
var Example = function() { };
Example.main = function() {
	var person = Example.buildPerson(Example.setupInjector());
	console.log("I am " + person.name + ", I am " + person.age + " years old and I have " + person.favouriteNumbers.length + " favourite numbers");
};
Example.setupInjector = function() {
	var array = [0,1,2];
	var array2 = [-1,3,366];
	return new dodrugs_InjectorInstance("exampleInjector",null,{ 'Example.Person' : function(inj,id) {
		var o = new Person(inj._get("String name"));
		o.setFavouriteNumbers(inj._get("Array<StdTypes.Int>"));
		o.age = inj._get("StdTypes.Int age");
		o.leastFavouriteNumbers = inj._tryGet("Array<StdTypes.Int> leastFavouriteNumbers",null);
		o.afterInjection();
		return o;
	}, 'StdTypes.Int age' : function(_,_1) {
		return 28;
	}, 'String name' : function(_2,_3) {
		return "Jason";
	}, 'Array<StdTypes.Int>' : function(_4,_5) {
		return array;
	}, 'Array<StdTypes.Int> leastFavouriteNumbers' : function(_6,_7) {
		return array2;
	}});
};
Example.buildPerson = function(injector) {
	return injector._get("Example.Person");
};
var Person = function(name) {
	this.ready = false;
	this.name = name;
};
Person.prototype = {
	setFavouriteNumbers: function(arr) {
		this.favouriteNumbers = arr;
	}
	,afterInjection: function() {
		this.ready = true;
	}
};
var dodrugs_InjectorInstance = function(name,parent,mappings) {
	this.name = name;
	this.parent = parent;
	this.mappings = mappings;
};
dodrugs_InjectorInstance.prototype = {
	getFromID: function(id) {
		return this._get(id);
	}
	,_get: function(id) {
		if(Object.prototype.hasOwnProperty.call(this.mappings,id)) {
			return this.mappings[id](this,id);
		} else if(this.parent != null) {
			return this.parent.getFromID(id);
		} else {
			throw new js__$Boot_HaxeError("The injection had no mapping for \"" + id + "\"");
		}
	}
	,_tryGet: function(id,fallback) {
		try {
			return this._get(id);
		} catch( e ) {
			return fallback;
		}
	}
};
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
Person.__meta__ = { fields : { age : { inject : ["age"]}, leastFavouriteNumbers : { inject : ["leastFavouriteNumbers"]}, setFavouriteNumbers : { inject : null}, afterInjection : { post : null}, _ : { inject : ["name"]}}};
Example.main();
})();