# Union of two types

`A | B` accepts either. `T | NULL` is the idiom for an optional value.
Every other operator is an error, so a typo cannot silently produce
something that is not a type.

## Usage

``` r
# S3 method for class 'type'
Ops(e1, e2)
```

## Arguments

- e1, e2:

  Types, or anything
  [`as_type()`](https://davzim.github.io/rdantic/reference/as_type.md)
  accepts.

## Value

A type.

## Examples

``` r
either <- int[1] | chr[1]
either(7)
#> [1] 7
either("seven")
#> [1] "seven"
try(either(TRUE))
#> Error : 1 validation problem in int[1] | chr[1]
#>   <value>  expected int[1] | chr[1], got lgl[1] TRUE

(int[1] | NULL)(NULL)
#> NULL
try(int[1] + chr[1])
#> Error in Ops.type(int[1], chr[1]) : operator `+` is not defined for types
```
