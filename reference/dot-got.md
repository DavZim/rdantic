# Describe a value for an error message

Like
[`type_of()`](https://davzim.github.io/rdantic/reference/type_of.md),
but a scalar also shows its value – which is usually the thing the
reader needs.

## Usage

``` r
.got(x)
```

## Arguments

- x:

  Any R value.

## Value

A single string.

## Examples

``` r
rdantic:::.got(1.5)
#> [1] "num[1] 1.5"
rdantic:::.got(c(1, 2))
#> [1] "num[2]"
```
