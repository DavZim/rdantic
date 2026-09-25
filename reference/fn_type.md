# Type for a typed function with a particular signature

Builds a type that accepts functions created by
[`fn()`](https://davzim.github.io/rdantic/reference/fn.md) only when
their declared argument names, argument types, defaults, and return type
match.

## Usage

``` r
fn_type(...)
```

## Arguments

- ...:

  Named argument types and an optional `~ type` return declaration.

## Value

A type.

## Examples

``` r
int_mapper <- fn_type(x = int[1], ~ int[1])
int_mapper(fn(x = int[1], ~ int[1], { x + 1L }))
#> <fn> (x: int[1]) -> int[1]
try(int_mapper(fn(x = num[1], ~ num[1], { x + 1 })))
#> Error : 1 validation problem in <fn> (x: int[1]) -> int[1]
#>   <value>  expected <fn> (x: int[1]) -> int[1], got <fn> (x: num[1]) -> num[1]
```
