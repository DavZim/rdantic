# Attach a default to a type

The default is validated immediately, so a wrong default is an error
where it is written rather than where it is used. Struct fields and
[`fn()`](https://davzim.github.io/rdantic/reference/fn.md) arguments
fall back to it when no value is supplied.

## Usage

``` r
t %default% value
```

## Arguments

- t:

  A type, or anything
  [`as_type()`](https://davzim.github.io/rdantic/reference/as_type.md)
  accepts.

- value:

  The default value.

## Value

A type carrying the default.

## Examples

``` r
role <- one_of("admin", "user") %default% "user"
role
#> <type> one_of("admin", "user")  (default: "user")

Cfg <- struct("Cfg", retries = int[1] %default% 3L, tag = chr[1] | NULL)
Cfg()$retries
#> [1] 3

try(int[1] %default% "three")
#> Error : 1 validation problem in int[1]
#>   <value>  expected int[1], got chr[1] "three"  -- strings are never parsed implicitly
```
