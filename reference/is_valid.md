# Does a value satisfy a type?

Does a value satisfy a type?

## Usage

``` r
is_valid(t, x)
```

## Arguments

- t:

  A type, or anything
  [`as_type()`](https://davzim.github.io/rdantic/reference/as_type.md)
  accepts.

- x:

  The value to test.

## Value

`TRUE` or `FALSE`.

## Examples

``` r
is_valid(int[1], 3)
#> [1] TRUE
is_valid(int[1], 3.5)
#> [1] FALSE
is_valid(chr, letters)
#> [1] TRUE
```
