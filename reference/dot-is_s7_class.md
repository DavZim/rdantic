# Is this an S7 class object?

Is this an S7 class object?

## Usage

``` r
.is_s7_class(x)
```

## Arguments

- x:

  Any R value.

## Value

`TRUE` for the object
[`S7::new_class()`](https://rconsortium.github.io/S7/reference/new_class.html)
returns.

## Examples

``` r
rdantic:::.is_s7_class(int)
#> [1] FALSE
```
