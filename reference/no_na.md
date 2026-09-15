# Reject missing values

R's quietest bug: `NA` sails through every arithmetic operator and every
comparison. `no_na(T)` is `T` that also refuses `NA`.

## Usage

``` r
no_na(t)
```

## Arguments

- t:

  A type, or anything
  [`as_type()`](https://davzim.github.io/rdantic/reference/as_type.md)
  accepts.

## Value

A type.

## Examples

``` r
no_na(num)(c(1, 2))
#> [1] 1 2
try(no_na(num)(c(1, NA)))
#> Error : 1 validation problem in no_na(num)
#>   <value>  expected no_na(num), got num[2]  -- contains NA
try(no_na(chr[1])(NA_character_))
#> Error : 1 validation problem in no_na(chr[1])
#>   <value>  expected no_na(chr[1]), got chr[1] NA_character_  -- contains NA
```
