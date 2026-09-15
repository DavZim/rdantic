# A map of any length with one element type, keyed by name

A map of any length with one element type, keyed by name

## Usage

``` r
.map_of_any(t)
```

## Arguments

- t:

  The element type.

## Value

A type.

## Examples

``` r
rdantic:::.map_of_any(int[1])(list(a = 1, b = 2))
#> $a
#> [1] 1
#> 
#> $b
#> [1] 2
#> 
```
