# Build a type from a predicate

The escape hatch for anything the built-in types do not cover, without
touching rdantic's internal problem format.

## Usage

``` r
type_from(name, test, coerce = NULL, json = "string", scalar = FALSE)
```

## Arguments

- name:

  The type's name, shown in errors.

- test:

  `function(x)` returning `TRUE` when `x` is acceptable.

- coerce:

  Optional `function(x)` returning a converted value, tried only when
  `test` fails and `rdantic.strict` is off.

- json:

  The JSON Schema type name.

- scalar:

  Whether a length-1 value should serialise as a JSON scalar rather than
  a one-element array.

## Value

A type.

## Examples

``` r
hex <- type_from("hex", function(x) is.character(x) && all(grepl("^#[0-9a-f]{6}$", x)))
hex("#00ff99")
#> [1] "#00ff99"
try(hex("green"))
#> Error : 1 validation problem in hex
#>   <value>  expected hex, got chr[1] "green"

port <- type_from(
  "port",
  function(x) is.integer(x) && length(x) == 1 && x > 0 && x < 65536,
  coerce = function(x) as.integer(x),
  json = "integer",
  scalar = TRUE
)
port(8080)
#> [1] 8080
```
