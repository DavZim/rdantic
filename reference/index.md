# Package index

## All functions

- [`Ops(`*`<type>`*`)`](https://davzim.github.io/rdantic/reference/Ops.type.md)
  : Union of two types
- [`as.list(`*`<typed_instance>`*`)`](https://davzim.github.io/rdantic/reference/as.list.typed_instance.md)
  : Convert an instance to a list
- [`as_s7_class()`](https://davzim.github.io/rdantic/reference/as_s7_class.md)
  : Turn a struct into an S7 class
- [`as_type()`](https://davzim.github.io/rdantic/reference/as_type.md) :
  Interpret a value as a type
- [`date()`](https://davzim.github.io/rdantic/reference/datetimes.md)
  [`datetime()`](https://davzim.github.io/rdantic/reference/datetimes.md)
  : Date and time types
- [`desc()`](https://davzim.github.io/rdantic/reference/desc.md)
  [`` `%doc%` ``](https://davzim.github.io/rdantic/reference/desc.md) :
  Attach a description to a type's schema
- [`describe()`](https://davzim.github.io/rdantic/reference/describe.md)
  : Describe a struct and its fields
- [`extend()`](https://davzim.github.io/rdantic/reference/extend.md) :
  Subclass a struct
- [`fct()`](https://davzim.github.io/rdantic/reference/fct.md) : Factor
  type
- [`fields()`](https://davzim.github.io/rdantic/reference/fields.md) :
  Field names of a struct or an instance
- [`fn()`](https://davzim.github.io/rdantic/reference/fn.md) : Define a
  typed function
- [`fn_type()`](https://davzim.github.io/rdantic/reference/fn_type.md) :
  Type for a typed function with a particular signature
- [`frame()`](https://davzim.github.io/rdantic/reference/frame.md) :
  Data frame type
- [`from_json()`](https://davzim.github.io/rdantic/reference/from_json.md)
  : Parse and validate JSON in one step
- [`from_list()`](https://davzim.github.io/rdantic/reference/from_list.md)
  : Parse a plain list into a struct
- [`` `%default%` ``](https://davzim.github.io/rdantic/reference/grapes-default-grapes.md)
  : Attach a default to a type
- [`` `$`( ``*`<typed_instance>`*`)`](https://davzim.github.io/rdantic/reference/instance-get.md)
  [`` `[[`( ``*`<typed_instance>`*`)`](https://davzim.github.io/rdantic/reference/instance-get.md)
  : Read a field of an instance
- [`` `$<-`( ``*`<typed_instance>`*`)`](https://davzim.github.io/rdantic/reference/instance-set.md)
  [`` `[[<-`( ``*`<typed_instance>`*`)`](https://davzim.github.io/rdantic/reference/instance-set.md)
  [`` `[<-`( ``*`<typed_instance>`*`)`](https://davzim.github.io/rdantic/reference/instance-set.md)
  : Set a field of an instance
- [`is_valid()`](https://davzim.github.io/rdantic/reference/is_valid.md)
  : Does a value satisfy a type?
- [`list_of()`](https://davzim.github.io/rdantic/reference/list_of.md) :
  List types
- [`map_of()`](https://davzim.github.io/rdantic/reference/map_of.md) :
  Map types
- [`new_type()`](https://davzim.github.io/rdantic/reference/new_type.md)
  : Create a type
- [`no_na()`](https://davzim.github.io/rdantic/reference/no_na.md) :
  Reject missing values
- [`one_of()`](https://davzim.github.io/rdantic/reference/one_of.md) :
  Enumeration of literal values
- [`opt()`](https://davzim.github.io/rdantic/reference/opt.md) : Make a
  type optional
- [`parse_as()`](https://davzim.github.io/rdantic/reference/parse_as.md)
  : Validate a value against a type
- [`partial()`](https://davzim.github.io/rdantic/reference/partial.md) :
  Make every field of a struct optional
- [`int()`](https://davzim.github.io/rdantic/reference/primitives.md)
  [`num()`](https://davzim.github.io/rdantic/reference/primitives.md)
  [`chr()`](https://davzim.github.io/rdantic/reference/primitives.md)
  [`lgl()`](https://davzim.github.io/rdantic/reference/primitives.md)
  [`anything()`](https://davzim.github.io/rdantic/reference/primitives.md)
  [`null_t()`](https://davzim.github.io/rdantic/reference/primitives.md)
  : Primitive vector types
- [`print(`*`<type>`*`)`](https://davzim.github.io/rdantic/reference/print.type.md)
  : Print a type
- [`print(`*`<typed_fn>`*`)`](https://davzim.github.io/rdantic/reference/print.typed_fn.md)
  : Print a typed function's signature
- [`print(`*`<typed_instance>`*`)`](https://davzim.github.io/rdantic/reference/print.typed_instance.md)
  : Print an instance
- [`print(`*`<typed_struct>`*`)`](https://davzim.github.io/rdantic/reference/print.typed_struct.md)
  : Print a struct
- [`ref()`](https://davzim.github.io/rdantic/reference/ref.md) : Refer
  to a struct by name
- [`s7_struct()`](https://davzim.github.io/rdantic/reference/s7_struct.md)
  : Define an S7 class with rdantic field types
- [`s7_type()`](https://davzim.github.io/rdantic/reference/s7_type.md) :
  Use an S7 class as a type
- [`schema()`](https://davzim.github.io/rdantic/reference/schema.md) :
  JSON Schema for a type
- [`struct()`](https://davzim.github.io/rdantic/reference/struct.md) :
  Define a record type
- [`` `[`( ``*`<type>`*`)`](https://davzim.github.io/rdantic/reference/sub-.type.md)
  : Fix a type's length, or add a constraint
- [`to_json()`](https://davzim.github.io/rdantic/reference/to_json.md) :
  Serialise to JSON, guided by the declared types
- [`to_list()`](https://davzim.github.io/rdantic/reference/to_list.md) :
  Convert an instance to plain lists
- [`try_parse()`](https://davzim.github.io/rdantic/reference/try_parse.md)
  : Validate without throwing
- [`type_from()`](https://davzim.github.io/rdantic/reference/type_from.md)
  : Build a type from a predicate
- [`type_of()`](https://davzim.github.io/rdantic/reference/type_of.md) :
  Describe the type of a value the way rdantic names types
- [`typed_fn()`](https://davzim.github.io/rdantic/reference/typed_fn.md)
  : Type for any typed function
