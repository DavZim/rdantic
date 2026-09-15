# Validate a set of named, typed fields

Record semantics, shared by `list_of(a = T, ...)` and
[`struct()`](https://davzim.github.io/rdantic/reference/struct.md): one
type per key, defaults filled in, missing keys reported, unknown keys
ignored or refused. Every problem is collected, not just the first.

## Usage

``` r
.check_fields(fields, args, path, extra, label)
```

## Arguments

- fields:

  A named list of types.

- args:

  The named list of supplied values.

- path:

  The path prefix for problem records.

- extra:

  `"ignore"` or `"forbid"`.

- label:

  What to call the record in a top-level problem.

## Value

The validated values in field order, or a `typed_problems` object.

## Examples

``` r
rdantic:::.check_fields(list(x = int[1]), list(x = 1), "", "ignore", "rec")
#> $x
#> [1] 1
#> 
rdantic:::.check_fields(list(x = int[1]), list(), "", "ignore", "rec")
#> [[1]]
#> [[1]]$path
#> [1] "$x"
#> 
#> [[1]]$expected
#> [1] "int[1]"
#> 
#> [[1]]$got
#> [1] "<missing>"
#> 
#> [[1]]$hint
#> NULL
#> 
#> 
#> attr(,"class")
#> [1] "typed_problems"
```
