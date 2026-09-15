# Create a type

A type is a closure that validates a value and an attached `spec`
describing it. Calling the type validates and returns the value;
everything else in rdantic is built by composing types.

## Usage

``` r
new_type(name, validate, schema = function() list(), ...)
```

## Arguments

- name:

  The type's name, used in error messages and in
  [`print()`](https://rdrr.io/r/base/print.html).

- validate:

  `function(x, path)` returning the (possibly coerced) value, or the
  result of
  [`.bad()`](https://davzim.github.io/rdantic/reference/dot-bad.md)/[`.fail()`](https://davzim.github.io/rdantic/reference/dot-fail.md).

- schema:

  `function()` returning the JSON Schema fragment for the type.

- ...:

  Extra entries stored in the spec, such as `scalar`, `empty`,
  `default`, `elt` or `members`.

## Value

An object of class `type`.

## Examples

``` r
even <- new_type(
  "even",
  validate = function(x, path) {
    if (is.numeric(x) && all(x %% 2 == 0)) x else rdantic:::.bad(path, "even", type_of(x))
  },
  schema = function() list(type = "integer", multipleOf = 2)
)
even(c(2, 4))
#> [1] 2 4
try(even(3))
#> Error : 1 validation problem in even
#>   <value>  expected even, got num[1]
schema(even)
#> $type
#> [1] "integer"
#> 
#> $multipleOf
#> [1] 2
#> 
```
