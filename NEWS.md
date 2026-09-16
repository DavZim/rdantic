# rdantic 0.2.1

## Bug fixes

* `fn()`: the typed body now runs across an ordinary function-call boundary
  instead of a shadowed `return()` inside a `withRestarts()` frame. A nested
  function's own `return()` again returns to its own caller instead of
  unwinding the whole typed function, and a closure returned from a typed
  function stays callable afterwards instead of erroring with
  `no 'restart' '.rdantic_return_' found`.
* `` [<-.typed_instance `` now replaces through an ordinary base-list
  assignment and validates the result, instead of coercing every replacement
  value to a list first. `x["value"] <- list(3L)` now stores `3L` (not
  `list(3L)`) for both constrained and unconstrained (`anything`) fields,
  matching normal list-replacement semantics.
* `map_of(T)` now serializes an empty map to `{}` instead of `[]`, matching
  its `"object"` schema and the JSON produced for nonempty maps.
* `frame()`'s generated schema now converts a nullable column's cell schema
  through its union branches, so a `T | NULL` column gets a scalar type in
  its non-null branch instead of retaining the whole column's array shape.

# rdantic 0.2.0

## Bug fixes

* `fn()`: an explicit `return()` inside a typed function's body is now checked
  against the declared return type, just like a value that falls through. It
  previously bypassed the check entirely and could leak a value of the wrong
  type.
* `fn()` and `struct()` now reject argument/field names that collide with
  rdantic's own internal bookkeeping variables (e.g. `.probs_`, `.r_`,
  `.args`), with a clear error at declaration time. Such a name previously
  could be silently shadowed and produce a wrong value at runtime.
* Typed instances now validate on `` [<- `` as well as `` $<- `` and
  `` [[<- ``. Previously `` [<- `` fell through to the default list method,
  letting an instance become invalid while `is_valid()` still reported it as
  valid.
* `frame(..., .extra = "forbid")` now rejects undeclared keys in JSON rows
  (`from_json()`), not just in a data.frame passed directly. Extra keys in a
  JSON row array were previously dropped silently before the check ran.
* `frame()`'s generated schema now describes one row's scalar cell for each
  column, instead of the whole column's vector shape, so it matches the JSON
  `to_json()` actually produces.

## Breaking changes

* `list_of(T)` (the single-type, unnamed-argument form) now only accepts an
  unnamed list and always has an `"array"` schema. Passing it a named list is
  now an error.
* New `map_of(T)`: an arbitrary-key map, one value type, keyed by name --
  what `list_of(T)` used to accept for a named list. Its schema is
  `{type: "object", additionalProperties: ...}`, matching the JSON object it
  serializes to. Update any call site that passed a named list to
  `list_of(T)` to use `map_of(T)` instead.
