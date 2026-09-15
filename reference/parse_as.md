# Validate a value against a type

The same thing as calling the type, but usable when the type arrives in
a variable. Coercion happens only where nothing can be lost.

## Usage

``` r
parse_as(t, x)
```

## Arguments

- t:

  A type, or anything
  [`as_type()`](https://davzim.github.io/rdantic/reference/as_type.md)
  accepts.

- x:

  The value to validate.

## Value

The validated value, possibly coerced.

## Examples

``` r
parse_as(int, c(1, 2, 3))
#> [1] 1 2 3
parse_as(list_of(int[1]), list(1, 2))
#> [[1]]
#> [1] 1
#> 
#> [[2]]
#> [1] 2
#> 
try(parse_as(int[1], "3"))
#> Error : 1 validation problem in int[1]
#>   <value>  expected int[1], got chr[1] "3"  -- strings are never parsed implicitly
```
