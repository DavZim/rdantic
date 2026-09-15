# Name a typed function for its error messages

Name a typed function for its error messages

## Usage

``` r
.fn_name(call)
```

## Arguments

- call:

  The result of [`sys.call()`](https://rdrr.io/r/base/sys.parent.html).

## Value

A string such as `"greet()"`.

## Examples

``` r
rdantic:::.fn_name(quote(greet("Ada")))
#> [1] "greet()"
rdantic:::.fn_name(quote((function(x) x)(1)))
#> [1] "<typed fn>()"
```
