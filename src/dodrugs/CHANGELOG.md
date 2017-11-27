# Releases

## development

- Added `Injector.quickExtend(mappings)`.
- Added `Injector.getWith(RequestedType, extraMappings)`
- Added `Injector.instantiate(RequestedType)`
- Changed behaviour:
    - Mapping functions now receive the injector the user called `get()` with, rather than the injector the mapping was on.
    - Singleton scoping has changed, singletons are now scoped to the calling injector and any children injectors that have not already called get(). See https://github.com/jasononeil/dodrugs/issues/11 for discussion.
- Fixed bug where `tink.core.Any` import conflicted with Injector macros.
- Fixed but where `var _:Int = "string"` was not rejected as an invalid mapping.

## 1.0.0-beta.1

- First haxelib release!