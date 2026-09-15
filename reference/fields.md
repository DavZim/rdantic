# Field names of a struct or an instance

Field names of a struct or an instance

## Usage

``` r
fields(x)
```

## Arguments

- x:

  A struct, an instance, or anything
  [`as_type()`](https://davzim.github.io/rdantic/reference/as_type.md)
  accepts.

## Value

A character vector, in declaration order.

## Examples

``` r
Pt <- struct("Pt", x = num[1], y = num[1])
fields(Pt)
#> [1] "x" "y"
fields(Pt(x = 1, y = 2))
#> [1] "x" "y"
```
