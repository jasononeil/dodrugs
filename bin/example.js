(function () { "use strict";
function $extend(from, fields) {
	function Inherit() {} Inherit.prototype = from; var proto = new Inherit();
	for (var name in fields) proto[name] = fields[name];
	if( fields.toString !== Object.prototype.toString ) proto.toString = fields.toString;
	return proto;
}
var Example = function() { };
Example.main = function() {
	var injector = Example.setupInjector();
	var action = function(inj,id) {
		var name = inj.getValueFromMappingID("String name");
		var o = new Person(name);
		var arr = inj.getValueFromMappingID("Array<StdTypes.Int>");
		o.setFavouriteNumbers(arr);
		o.age = inj.getValueFromMappingID("StdTypes.Int age");
		o.leastFavouriteNumbers = inj.getValueFromMappingID("Array<StdTypes.Int> leastFavouriteNumbers");
		o.afterInjection();
		return o;
	};
	var person;
	{
		var this1 = action(injector,"");
		person = this1;
	}
	console.log("I am " + person.name + ", I am " + person.age + " years old and I have " + person.favouriteNumbers.length + " favourite numbers");
};
Example.setupInjector = function() {
	var array = [0,1,2];
	var array2 = [-1,3,366];
	var rules = { 'StdTypes.Int age' : function(i,_) {
		return 28;
	}, 'String name' : function(i1,_1) {
		return "Jason";
	}, 'Array<StdTypes.Int>' : function(i2,_2) {
		return array;
	}, 'Array<StdTypes.Int> leastFavouriteNumbers' : function(i3,_3) {
		return array2;
	}};
	return new dodrugs_InjectorInstance(null,rules);
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
var dodrugs_InjectorInstance = function(parent,mappings) {
	this.parent = parent;
	this.mappings = mappings;
};
dodrugs_InjectorInstance.prototype = {
	getValueFromMappingID: function(id) {
		if(Object.prototype.hasOwnProperty.call(this.mappings,id)) return this.mappings[id](this,id); else if(this.parent != null) return this.parent.getValueFromMappingID(id); else throw new js__$Boot_HaxeError("The injection had no mapping for \"" + id + "\"");
	}
};
var js__$Boot_HaxeError = function(val) {
	Error.call(this);
	this.val = val;
	this.message = String(val);
	if(Error.captureStackTrace) Error.captureStackTrace(this,js__$Boot_HaxeError);
};
js__$Boot_HaxeError.__super__ = Error;
js__$Boot_HaxeError.prototype = $extend(Error.prototype,{
});
Person.__meta__ = { fields : { age : { inject : ["age"]}, leastFavouriteNumbers : { inject : ["leastFavouriteNumbers"]}, setFavouriteNumbers : { inject : null}, afterInjection : { post : null}, _ : { inject : ["name"]}}};
Example.main();
})();
