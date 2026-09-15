# Could two values be equal without coercion?

Could two values be equal without coercion?

## Usage

``` r
.comparable(x, v)
```

## Arguments

- x, v:

  Atomic values.

## Value

`TRUE` when comparing them would not stringify either side.

## Examples

``` r
rdantic:::.comparable(1, 2)
#> [1] TRUE
rdantic:::.comparable(1, "2")
#> [1] FALSE
```
