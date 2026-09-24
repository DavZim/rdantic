# The typed fields of an S7 class

A class built by
[`as_s7_class()`](https://davzim.github.io/rdantic/reference/as_s7_class.md)
carries the struct it came from, so a round trip keeps the original
field types instead of the erased `class_any` the properties were
declared with. Otherwise the property classes are translated one by one.
A property is optional exactly when it declares a `default`, which is
the same rule `%default%` follows.

## Usage

``` r
.s7_fields(cls)
```

## Arguments

- cls:

  An S7 class.

## Value

A named list of types, in declaration order.

## Details

A property with a `getter` and no `setter` is computed, so it is not a
field: nothing can supply it, and requiring it would make every such
class impossible to parse.

## Examples

``` r
if (requireNamespace("S7", quietly = TRUE))
  names(rdantic:::.s7_fields(
    S7::new_class("Blop", properties = list(n = S7::class_double))
  ))
#> [1] "n"
```
