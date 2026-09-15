# Validate everything passed through `...`

`...` cannot be rebound, so its elements are checked but never coerced.

## Usage

``` r
.check_dots(t, dots)
```

## Arguments

- t:

  The type every element must satisfy.

- dots:

  `list(...)` from inside the function.

## Value

A list of problem records, empty when all elements pass.

## Examples

``` r
rdantic:::.check_dots(chr[1], list("a", 2))
#> [[1]]
#> [[1]]$path
#> [1] "..2"
#> 
#> [[1]]$expected
#> [1] "chr[1]"
#> 
#> [[1]]$got
#> [1] "num[1] 2"
#> 
#> [[1]]$hint
#> NULL
#> 
#> 
```
