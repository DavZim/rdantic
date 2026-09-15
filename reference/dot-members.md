# The alternatives of a type

The alternatives of a type

## Usage

``` r
.members(t)
```

## Arguments

- t:

  A type.

## Value

A list of types: the union's members, or `t` itself.

## Examples

``` r
length(rdantic:::.members(int | chr | NULL))
#> [1] 3
```
