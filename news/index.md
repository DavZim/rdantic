# Changelog

## rdantic 0.3.2

### New features

- `typed_fn` is a type for any function declared with
  [`fn()`](https://davzim.github.io/rdantic/reference/fn.md), and
  [`fn_type()`](https://davzim.github.io/rdantic/reference/fn_type.md)
  builds a type for an exact declared argument and return signature.
  This makes typed function factories and higher-order arguments
  checkable without an ad hoc
  [`inherits()`](https://rdrr.io/r/base/class.html) predicate.

## rdantic 0.3.1

### New features

- [`describe()`](https://davzim.github.io/rdantic/reference/describe.md)
  adds a struct description and named field descriptions after
  declaration, keeping long documentation blocks together without
  obscuring the schema’s type structure. The returned definition is
  registered so later
  [`ref()`](https://davzim.github.io/rdantic/reference/ref.md)
  resolution uses the documented schema.
- [`desc()`](https://davzim.github.io/rdantic/reference/desc.md),
  `%doc%`, `struct(.description = )`, and
  [`describe()`](https://davzim.github.io/rdantic/reference/describe.md)
  now normalize multiline descriptions by removing blank edge lines and
  common indentation, making R raw strings convenient for long schema
  documentation.

## rdantic 0.3.0

### New features

- S7 interoperability, in both directions. S7 is a suggested dependency:
  nothing changes when it is not installed. See
  [`vignette("s7")`](https://davzim.github.io/rdantic/articles/s7.md).
- An S7 class can be used wherever a type is expected – as a struct
  field, an [`fn()`](https://davzim.github.io/rdantic/reference/fn.md)
  argument, a
  [`list_of()`](https://davzim.github.io/rdantic/reference/list_of.md)
  element type.
  [`as_type()`](https://davzim.github.io/rdantic/reference/as_type.md)
  recognises it and
  [`s7_type()`](https://davzim.github.io/rdantic/reference/s7_type.md)
  builds the type: an instance validates as itself, and a plain list is
  parsed into a real S7 object, so
  [`from_json()`](https://davzim.github.io/rdantic/reference/from_json.md)
  and
  [`from_list()`](https://davzim.github.io/rdantic/reference/from_list.md)
  construct S7 objects property by property with every problem reported
  under its path.
  [`schema()`](https://davzim.github.io/rdantic/reference/schema.md),
  [`to_list()`](https://davzim.github.io/rdantic/reference/to_list.md)
  and
  [`to_json()`](https://davzim.github.io/rdantic/reference/to_json.md)
  understand S7 objects too.
- [`as_s7_class()`](https://davzim.github.io/rdantic/reference/as_s7_class.md)
  turns a struct into an S7 class whose properties validate through
  their rdantic types on construction and on `@<-`, coercing where
  rdantic coerces and raising the same `typed_error`. A struct made with
  [`extend()`](https://davzim.github.io/rdantic/reference/extend.md)
  becomes an S7 subclass; one that retypes a parent’s field is flattened
  with a warning, because S7 cannot override an inherited property.
- [`s7_struct()`](https://davzim.github.io/rdantic/reference/s7_struct.md)
  declares an S7 class directly, with rdantic field types and
  [`struct()`](https://davzim.github.io/rdantic/reference/struct.md)’s
  `.description` and `.extra`, plus a `.parent` S7 class to inherit
  from. Unlike
  [`struct()`](https://davzim.github.io/rdantic/reference/struct.md) it
  does not register the name, since a name in that registry means
  something that builds instances rather than S7 objects.
- [`fields()`](https://davzim.github.io/rdantic/reference/fields.md) and
  [`type_of()`](https://davzim.github.io/rdantic/reference/type_of.md)
  now accept S7 classes and objects.

### Bug fixes

- A struct with no fields no longer misbehaves:
  [`fields()`](https://davzim.github.io/rdantic/reference/fields.md)
  returns [`character()`](https://rdrr.io/r/base/character.html) rather
  than `NULL`, [`print()`](https://rdrr.io/r/base/print.html) no longer
  warns (`no non-missing arguments to max`), and both the instance and
  its schema’s `properties` serialise as
  [`{}`](https://rdrr.io/r/base/Paren.html) rather than `[]`.
- A computed S7 property – one with a `getter` and no `setter` – is no
  longer treated as a field. It was reported as a missing required
  value, which made every class with one impossible to parse or
  serialise.
- [`as_type()`](https://davzim.github.io/rdantic/reference/as_type.md)
  now accepts an S7 union, so `SomeClass | NULL` and
  `class_double | class_character` are types. A `NULL` member means the
  null type rather than `anything`.
- [`to_list()`](https://davzim.github.io/rdantic/reference/to_list.md)
  and
  [`to_json()`](https://davzim.github.io/rdantic/reference/to_json.md)
  now agree on which S7 properties they emit.
- [`extend()`](https://davzim.github.io/rdantic/reference/extend.md) and
  [`partial()`](https://davzim.github.io/rdantic/reference/partial.md)
  now resolve their parent through
  [`as_type()`](https://davzim.github.io/rdantic/reference/as_type.md)
  and refuse a type that has no fields. A type that is not a struct –
  `int[1]`, `list_of(int)`, an S7 class – previously produced a struct
  silently missing the parent’s fields instead of an error. Both now
  also accept an S7 class, and carry its properties into the new struct.

## rdantic 0.2.1

### Bug fixes

- [`fn()`](https://davzim.github.io/rdantic/reference/fn.md): the typed
  body now runs across an ordinary function-call boundary instead of a
  shadowed [`return()`](https://rdrr.io/r/base/function.html) inside a
  [`withRestarts()`](https://rdrr.io/r/base/conditions.html) frame. A
  nested function’s own
  [`return()`](https://rdrr.io/r/base/function.html) again returns to
  its own caller instead of unwinding the whole typed function, and a
  closure returned from a typed function stays callable afterwards
  instead of erroring with `no 'restart' '.rdantic_return_' found`.
- `[<-.typed_instance` now replaces through an ordinary base-list
  assignment and validates the result, instead of coercing every
  replacement value to a list first. `x["value"] <- list(3L)` now stores
  `3L` (not `list(3L)`) for both constrained and unconstrained
  (`anything`) fields, matching normal list-replacement semantics.
- `map_of(T)` now serializes an empty map to
  [`{}`](https://rdrr.io/r/base/Paren.html) instead of `[]`, matching
  its `"object"` schema and the JSON produced for nonempty maps.
- [`frame()`](https://davzim.github.io/rdantic/reference/frame.md)’s
  generated schema now converts a nullable column’s cell schema through
  its union branches, so a `T | NULL` column gets a scalar type in its
  non-null branch instead of retaining the whole column’s array shape.

## rdantic 0.2.0

### Bug fixes

- [`fn()`](https://davzim.github.io/rdantic/reference/fn.md): an
  explicit [`return()`](https://rdrr.io/r/base/function.html) inside a
  typed function’s body is now checked against the declared return type,
  just like a value that falls through. It previously bypassed the check
  entirely and could leak a value of the wrong type.
- [`fn()`](https://davzim.github.io/rdantic/reference/fn.md) and
  [`struct()`](https://davzim.github.io/rdantic/reference/struct.md) now
  reject argument/field names that collide with rdantic’s own internal
  bookkeeping variables (e.g. `.probs_`, `.r_`, `.args`), with a clear
  error at declaration time. Such a name previously could be silently
  shadowed and produce a wrong value at runtime.
- Typed instances now validate on `[<-` as well as `$<-` and `[[<-`.
  Previously `[<-` fell through to the default list method, letting an
  instance become invalid while
  [`is_valid()`](https://davzim.github.io/rdantic/reference/is_valid.md)
  still reported it as valid.
- `frame(..., .extra = "forbid")` now rejects undeclared keys in JSON
  rows
  ([`from_json()`](https://davzim.github.io/rdantic/reference/from_json.md)),
  not just in a data.frame passed directly. Extra keys in a JSON row
  array were previously dropped silently before the check ran.
- [`frame()`](https://davzim.github.io/rdantic/reference/frame.md)’s
  generated schema now describes one row’s scalar cell for each column,
  instead of the whole column’s vector shape, so it matches the JSON
  [`to_json()`](https://davzim.github.io/rdantic/reference/to_json.md)
  actually produces.

### Breaking changes

- `list_of(T)` (the single-type, unnamed-argument form) now only accepts
  an unnamed list and always has an `"array"` schema. Passing it a named
  list is now an error.
- New `map_of(T)`: an arbitrary-key map, one value type, keyed by name –
  what `list_of(T)` used to accept for a named list. Its schema is
  `{type: "object", additionalProperties: ...}`, matching the JSON
  object it serializes to. Update any call site that passed a named list
  to `list_of(T)` to use `map_of(T)` instead.
