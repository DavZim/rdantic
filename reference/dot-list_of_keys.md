# A named list with a fixed key set

A named list with a fixed key set

## Usage

``` r
.list_of_keys(keys, extra)
```

## Arguments

- keys:

  A named list of types.

- extra:

  `"ignore"` or `"forbid"`.

## Value

A type.

## Examples

``` r
rdantic:::.list_of_keys(list(a = int[1]), "forbid")(list(a = 1))
#> $a
#> [1] 1
#> 
```
