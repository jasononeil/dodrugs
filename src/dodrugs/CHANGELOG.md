# Releases

## development

- Added `Injector.quickExtend(mappings)`.
- Added `Injector.getWith(RequestedType, extraMappings)`
- Added `Injector.instantiate(RequestedType)`
- Added `Injector.instantiateWith(RequestedType, extraMappings)`
- New mapping syntax option: just specify a local variable, and it will be mapped with the same name and type.
    - ```haxe
      var age = 30;
      injector.create("myapp", [
          age
      ]);
      // is the same as...
      injector.create("myapp", [
          var age: Int = age;
      ]);
      ```
- New mapping syntax option: just specify a value, and it will be mapped with the known type, and no specific name.
    - ```haxe
      injector.create("myapp", [
          new Person()
      ]);
      // is the same as...
      injector.create("myapp", [
          var _: Person = new Person()
      ]);
      ```
- Changed behaviour:
    - Mapping functions now receive the injector the user called `get()` with, rather than the injector the mapping was on.
    - Singleton scoping has changed, singletons are now scoped to the calling injector and any children injectors that have not already called get(). See https://github.com/jasononeil/dodrugs/issues/11 for discussion.
- Fixed bug where `tink.core.Any` import conflicted with Injector macros.
- Fixed but where `var _:Int = "string"` was not rejected as an invalid mapping.

## 1.0.0-beta.1

- First haxelib release!