# Combine types into a union

Unions flatten, so `A | B | C` has three members rather than a nested
pair, and a default written on either side belongs to the whole union –
which is what makes `int[1] | NULL %default% NULL` mean what it looks
like despite `%op%` binding tighter than `|`.

## Usage

``` r
.union(a, b)
```

## Arguments

- a, b:

  Types.

## Value

A type.

## Examples

``` r
rdantic:::.union(int, chr)
#> <type> int | chr
```
