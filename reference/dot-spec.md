# Get a type's spec

Get a type's spec

## Usage

``` r
.spec(t)
```

## Arguments

- t:

  A type.

## Value

The spec list: `name`, `validate`, `schema`, plus any extras.

## Examples

``` r
names(rdantic:::.spec(int))
#> [1] "name"     "validate" "schema"   "empty"   
```
