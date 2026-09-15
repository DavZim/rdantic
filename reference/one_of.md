# Enumeration of literal values

Accepts exactly one of the given values and returns it. Comparison is
type aware: `one_of("1", "2")` does not accept the number `1`, because
[`match()`](https://rdrr.io/r/base/match.html) would have stringified
it.

## Usage

``` r
one_of(...)
```

## Arguments

- ...:

  The permitted values.

## Value

A type.

## See also

[`fct()`](https://davzim.github.io/rdantic/reference/fct.md) for the
same idea with a factor result.

## Examples

``` r
role <- one_of("admin", "user")
role("admin")
#> [1] "admin"
try(role("root"))
#> Error : 1 validation problem in one_of("admin", "user")
#>   <value>  expected one_of("admin", "user"), got chr[1] "root"
try(one_of("1", "2")(1))
#> Error : 1 validation problem in one_of("1", "2")
#>   <value>  expected one_of("1", "2"), got num[1] 1  -- the literals have a different type

one_of("admin", "user") %default% "user"
#> <type> one_of("admin", "user")  (default: "user")
schema(role)
#> $enum
#> $enum[[1]]
#> [1] "admin"
#> 
#> $enum[[2]]
#> [1] "user"
#> 
#> 
```
