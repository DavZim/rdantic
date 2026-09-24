# Check and coerce a set of declared fields

Check and coerce a set of declared fields

## Usage

``` r
.struct_fields(fields)
```

## Arguments

- fields:

  The `...` of a struct-like declaration.

## Value

The same list, every entry passed through
[`as_type()`](https://davzim.github.io/rdantic/reference/as_type.md).

## Examples

``` r
names(rdantic:::.struct_fields(list(a = int[1])))
#> [1] "a"
```
