# Primitive vector types

The four atomic vector types, plus `anything` and the null type. Each is
an ordinary value: call it to validate, subset it with `[` to fix a
length or add a constraint, combine it with `|`.

## Usage

``` r
int(x)

num(x)

chr(x)

lgl(x)

anything(x)

null_t(x)
```

## Format

Objects of class `type`.

## Arguments

- x:

  The value to validate.

## Details

Coercion is lossless only. A whole double becomes an integer and an
integer becomes a double; `1.5` never becomes `1L`, `"1"` never becomes
`1`, and a classed atomic such as a `Date` is never quietly unclassed.
Set `options(rdantic.strict = TRUE)` to switch coercion off entirely.

## See also

[date](https://davzim.github.io/rdantic/reference/datetimes.md),
[`fct()`](https://davzim.github.io/rdantic/reference/fct.md),
[`type_from()`](https://davzim.github.io/rdantic/reference/type_from.md)

## Examples

``` r
int(c(1, 2, 3))   # whole doubles become integers
#> [1] 1 2 3
num(2L)           # integers become doubles
#> [1] 2
chr(factor("a"))  # factors become characters
#> [1] "a"
lgl(c(TRUE, NA))
#> [1] TRUE   NA
anything(list(1, "a"))
#> [[1]]
#> [1] 1
#> 
#> [[2]]
#> [1] "a"
#> 

try(int(1.5))     # lossy
#> Error : 1 validation problem in int
#>   <value>  expected int, got num[1] 1.5  -- not a whole number
try(int("3"))     # strings are never parsed
#> Error : 1 validation problem in int
#>   <value>  expected int, got chr[1] "3"  -- strings are never parsed implicitly
try(int(1e10))    # outside integer range
#> Error : 1 validation problem in int
#>   <value>  expected int, got num[1] 1e+10  -- outside integer range; use num

int[1]            # exactly one integer
#> <type> int[1]
num[. > 0]        # positive doubles
#> <type> num[. > 0]
```
