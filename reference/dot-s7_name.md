# The class name of an S7 class

The class name of an S7 class

## Usage

``` r
.s7_name(cls)
```

## Arguments

- cls:

  An S7 class.

## Value

A single string.

## Examples

``` r
if (requireNamespace("S7", quietly = TRUE))
  rdantic:::.s7_name(S7::new_class("Blip"))
#> [1] "Blip"
```
