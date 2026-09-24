# Is this an instance of an S7 class?

A class object is itself an `S7_object`, so it has to be excluded.

## Usage

``` r
.is_s7_object(x)
```

## Arguments

- x:

  Any R value.

## Value

`TRUE` for an S7 instance.

## Examples

``` r
rdantic:::.is_s7_object(1)
#> [1] FALSE
```
