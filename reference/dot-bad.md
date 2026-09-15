# Report a single validation failure

Report a single validation failure

## Usage

``` r
.bad(path, expected, got, hint = NULL)
```

## Arguments

- path:

  Where the bad value sits, e.g. `"$user$id"`. `""` is the value itself.

- expected:

  Name of the type that was expected.

- got:

  Description of what arrived, usually from
  [`.got()`](https://davzim.github.io/rdantic/reference/dot-got.md).

- hint:

  Optional one-line explanation of how to fix it.

## Value

A `typed_problems` object holding one record.

## Examples

``` r
rdantic:::.bad("$id", "int[1]", "chr[1] \"x\"", "strings are never parsed")
#> [[1]]
#> [[1]]$path
#> [1] "$id"
#> 
#> [[1]]$expected
#> [1] "int[1]"
#> 
#> [[1]]$got
#> [1] "chr[1] \"x\""
#> 
#> [[1]]$hint
#> [1] "strings are never parsed"
#> 
#> 
#> attr(,"class")
#> [1] "typed_problems"
```
