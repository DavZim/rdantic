# Is a validator result a failure?

Is a validator result a failure?

## Usage

``` r
.is_bad(r)
```

## Arguments

- r:

  The return value of a validator.

## Value

`TRUE` if `r` carries problems rather than a value.

## Examples

``` r
rdantic:::.is_bad(1L)
#> [1] FALSE
rdantic:::.is_bad(rdantic:::.bad("", "int", "chr[1]"))
#> [1] TRUE
```
