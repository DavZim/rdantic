# Interpret a value as a type

Types are values, so most of the API accepts either a type, `NULL`
(meaning the null type) or a string (meaning a struct looked up by
name).

## Usage

``` r
as_type(x)
```

## Arguments

- x:

  A type, `NULL`, or a struct name.

## Value

A type.

## Examples

``` r
as_type(int)
#> <type> int
as_type(NULL)
#> <type> NULL
as_type("User")
#> <type> User
```
