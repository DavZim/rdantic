# Type for any typed function

`typed_fn` accepts any function created by
[`fn()`](https://davzim.github.io/rdantic/reference/fn.md). Use
[`fn_type()`](https://davzim.github.io/rdantic/reference/fn_type.md)
when its declared argument and return types must match a particular
signature.

## Usage

``` r
typed_fn(x)
```

## Arguments

- x:

  A value to validate.

## Value

A type.

## Examples

``` r
identity_int <- fn(x = int[1], ~ int[1], { x })
typed_fn(identity_int)
#> <fn> (x: int[1]) -> int[1]
try(typed_fn(function(x) x))
#> Error : 1 validation problem in typed_fn
#>   <value>  expected typed_fn, got function[1]
```
