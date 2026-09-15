# Say which elements failed a predicate

Say which elements failed a predicate

## Usage

``` r
.refine_hint(hit, value)
```

## Arguments

- hit:

  The predicate's result.

- value:

  The validated value.

## Value

A one-line hint, or `NULL`.

## Examples

``` r
rdantic:::.refine_hint(c(TRUE, FALSE, FALSE), c(1, -2, -3))
#> [1] "fails at elements 2, 3"
```
