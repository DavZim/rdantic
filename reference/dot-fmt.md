# One-line summary of a field's value

One-line summary of a field's value

## Usage

``` r
.fmt(v)
```

## Arguments

- v:

  Any value.

## Value

A single string, truncated if long.

## Examples

``` r
rdantic:::.fmt(1:3)
#> [1] "1:3"
rdantic:::.fmt(data.frame(a = 1:2))
#> [1] "<data.frame 2 x 1>"
```
