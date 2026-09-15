# The element type of a list type

The element type of a list type

## Usage

``` r
.list_elt_type(s)
```

## Arguments

- s:

  A spec, or `NULL`.

## Value

The element type, or `NULL` when there is not exactly one.

## Examples

``` r
rdantic:::.list_elt_type(rdantic:::.spec(list_of(int[1])))
#> <type> int[1]
```
