# Interpret a value as a type

Types are values, so most of the API accepts either a type, `NULL`
(meaning the null type), a string (meaning a struct looked up by name)
or an S7 class (see
[`s7_type()`](https://davzim.github.io/rdantic/reference/s7_type.md)).

## Usage

``` r
as_type(x)
```

## Arguments

- x:

  A type, `NULL`, a struct name, or an S7 class.

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
