# Is a value an unclassed atomic vector?

A primitive never accepts a classed atomic: a `Date` is not a `num` and
a factor is not an `int`, even though both are exactly that underneath.

## Usage

``` r
.plain(x)
```

## Arguments

- x:

  Any R value.

## Value

`TRUE` when `x` carries no class attribute.

## Examples

``` r
rdantic:::.plain(1:3)
#> [1] TRUE
rdantic:::.plain(Sys.Date())
#> [1] FALSE
```
