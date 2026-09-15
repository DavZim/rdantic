# Rename the expectation of top-level problems

A wrapper type such as `int[1]` delegates to `int`, then relabels
whatever came back so the message names the composed type, not the inner
one.

## Usage

``` r
.relabel(r, path, name)
```

## Arguments

- r:

  A `typed_problems` object.

- path:

  The path whose records should be relabelled.

- name:

  The type name to put in `expected`.

## Value

A `typed_problems` object.

## Examples

``` r
rdantic:::.relabel(rdantic:::.bad("", "int", "num[1] 1.5"), "", "int[1]")
#> [[1]]
#> [[1]]$path
#> [1] ""
#> 
#> [[1]]$expected
#> [1] "int[1]"
#> 
#> [[1]]$got
#> [1] "num[1] 1.5"
#> 
#> [[1]]$hint
#> NULL
#> 
#> 
#> attr(,"class")
#> [1] "typed_problems"
```
