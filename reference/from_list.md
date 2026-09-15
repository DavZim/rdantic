# Parse a plain list into a struct

The list-shaped counterpart of the constructor: unknown keys are ignored
unless the struct was declared with `.extra = "forbid"`, and nested
lists are parsed into nested structs.

## Usage

``` r
from_list(struct, x)
```

## Arguments

- struct:

  A struct, or anything
  [`as_type()`](https://davzim.github.io/rdantic/reference/as_type.md)
  accepts.

- x:

  A named list.

## Value

An instance.

## See also

[`from_json()`](https://davzim.github.io/rdantic/reference/from_json.md),
[`try_parse()`](https://davzim.github.io/rdantic/reference/try_parse.md)

## Examples

``` r
Msg <- struct("Msg", topic = chr[1], size = int[1])
from_list(Msg, list(topic = "orders", size = 12))
#> <Msg>
#>   topic : "orders"
#>   size  : 12L
from_list(Msg, list(topic = "orders", size = 12, extra = "ignored"))
#> <Msg>
#>   topic : "orders"
#>   size  : 12L
try(from_list(Msg, list(topic = "orders")))
#> Error : 1 validation problem in Msg
#>   $size  expected int[1], got <missing>
```
