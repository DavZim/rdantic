# Collect the hints from a set of problems

Collect the hints from a set of problems

## Usage

``` r
.hints_of(r)
```

## Arguments

- r:

  A `typed_problems` object.

## Value

A character vector, possibly empty.

## Examples

``` r
rdantic:::.hints_of(rdantic:::.bad("", "int", "num[1] 1.5", "not a whole number"))
#> [1] "not a whole number"
```
