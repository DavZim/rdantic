# Fix the length of a type

Fix the length of a type

## Usage

``` r
.sized(t, n)
```

## Arguments

- t:

  A type.

- n:

  The required length.

## Value

A type.

## Examples

``` r
rdantic:::.sized(int, 2)(c(1, 2))
#> [1] 1 2
```
