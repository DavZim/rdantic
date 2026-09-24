# Extending rdantic: new_type()

``` r

library(rdantic)
#> 
#> Attaching package: 'rdantic'
#> The following object is masked from 'package:graphics':
#> 
#>     frame
#> The following object is masked from 'package:base':
#> 
#>     date
```

Most custom rules fit inside
[`type_from()`](https://davzim.github.io/rdantic/reference/type_from.md)
([`vignette("types-in-depth")`](https://davzim.github.io/rdantic/articles/types-in-depth.md)):
a predicate, an optional coercion, and rdantic looks after the problem
format for you. This vignette covers
[`new_type()`](https://davzim.github.io/rdantic/reference/new_type.md),
the lower-level constructor that everything else in the package – `int`,
[`list_of()`](https://davzim.github.io/rdantic/reference/list_of.md),
[`struct()`](https://davzim.github.io/rdantic/reference/struct.md),
[`fn()`](https://davzim.github.io/rdantic/reference/fn.md) – is itself
built from, for when a type needs full control over its validation and
its JSON Schema fragment.

## What a type actually is

A type is a closure that validates a value, carrying a `spec` attribute
describing it (`name`, `validate`, `schema`, and whatever else the
constructor stored). Calling a type runs
[`validate()`](https://rconsortium.github.io/S7/reference/validate.html);
printing it, or asking
[`schema()`](https://davzim.github.io/rdantic/reference/schema.md) for
its JSON Schema, reads the rest of the spec.
[`new_type()`](https://davzim.github.io/rdantic/reference/new_type.md)
is how that closure gets built:

``` r

even <- new_type(
  "even",
  validate = function(x, path) {
    if (is.numeric(x) && all(x %% 2 == 0)) x else rdantic:::.bad(path, "even", type_of(x))
  },
  schema = function() list(type = "integer", multipleOf = 2)
)
even
#> <type> even
even(c(2, 4))
#> [1] 2 4
```

``` r

even(3)
#> Error:
#> ! 1 validation problem in even
#>   <value>  expected even, got num[1]
```

`validate` receives the value and the `path` at which it appears (so an
error nested inside a struct or a list reports the right location) and
returns either the – possibly coerced – value, or a problem record built
by rdantic’s internal helpers.
[`type_of()`](https://davzim.github.io/rdantic/reference/type_of.md)
(exported, used above) renders a value the way rdantic names types in
its own error messages, so a custom type’s errors read the same as a
built-in one’s.

``` r

schema(even)
#> $type
#> [1] "integer"
#> 
#> $multipleOf
#> [1] 2
```

## When to reach for this vs. `type_from()`

| Need | Use |
|----|----|
| A predicate, maybe a coercion, default JSON Schema shape | [`type_from()`](https://davzim.github.io/rdantic/reference/type_from.md) |
| Full control over the problem message, or a custom JSON Schema fragment | [`new_type()`](https://davzim.github.io/rdantic/reference/new_type.md) |
| A restricted set of exact values | [`one_of()`](https://davzim.github.io/rdantic/reference/one_of.md) |
| A record with named fields | [`struct()`](https://davzim.github.io/rdantic/reference/struct.md) |

In practice
[`new_type()`](https://davzim.github.io/rdantic/reference/new_type.md)
is rarely needed directly – it exists so the rest of rdantic can be
implemented in terms of it, and remains available for the rare case a
project’s own domain type needs the same level of control.
