# Validate without throwing

For input that is expected to be wrong sometimes – a web form, an
upload, a config file – where you want to collect the problems rather
than abort.

## Usage

``` r
try_parse(t, x)
```

## Arguments

- t:

  A type, or anything
  [`as_type()`](https://davzim.github.io/rdantic/reference/as_type.md)
  accepts.

- x:

  The value to validate.

## Value

A list with `ok`, `value` and `problems` (a list of
`{path, expected, got, hint}` records).

## Examples

``` r
try_parse(int[1], 1)
#> $ok
#> [1] TRUE
#> 
#> $value
#> [1] 1
#> 
#> $problems
#> list()
#> 
r <- try_parse(int[1], "x")
r$ok
#> [1] FALSE
r$problems[[1]]$hint
#> [1] "strings are never parsed implicitly"
```
