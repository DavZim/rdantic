# Type-aware equality

Type-aware equality

## Usage

``` r
.same_value(x, v)
```

## Arguments

- x:

  A value.

- v:

  A literal to compare against.

## Value

`TRUE` when they are the same value of a compatible type.

## Examples

``` r
rdantic:::.same_value(1, 1)
#> [1] TRUE
rdantic:::.same_value(1, "1")
#> [1] FALSE
```
