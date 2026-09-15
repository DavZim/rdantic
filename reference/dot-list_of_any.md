# An array of any length with one element type

An array of any length with one element type

## Usage

``` r
.list_of_any(t)
```

## Arguments

- t:

  The element type.

## Value

A type.

## Examples

``` r
rdantic:::.list_of_any(int[1])(list(1, 2))
#> [[1]]
#> [1] 1
#> 
#> [[2]]
#> [1] 2
#> 
```
