# Explain why a value could not be coerced

Explain why a value could not be coerced

## Usage

``` r
.coerce_hint(name, x)
```

## Arguments

- name:

  The primitive type's name.

- x:

  The value that failed.

## Value

A one-line hint, or `NULL`.

## Examples

``` r
rdantic:::.coerce_hint("int", 1.5)
#> [1] "not a whole number"
rdantic:::.coerce_hint("int", 1e10)
#> [1] "outside integer range; use num"
rdantic:::.coerce_hint("num", "7")
#> [1] "strings are never parsed implicitly"
```
