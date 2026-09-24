# Names of a possibly empty list

`names(list())` is `NULL`, which would make a fieldless struct report no
field names rather than none, and serialise as a JSON array.

## Usage

``` r
.nm(x)
```

## Arguments

- x:

  A list.

## Value

A character vector, empty rather than `NULL`.

## Examples

``` r
rdantic:::.nm(list())
#> character(0)
```
