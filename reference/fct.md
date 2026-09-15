# Factor type

`fct(a, b, ...)` accepts a factor with exactly those levels, and
promotes character input whose values are all among them. `fct()` with
no arguments accepts any factor and never coerces.

## Usage

``` r
fct(...)
```

## Arguments

- ...:

  The levels, in order.

## Value

A type.

## Details

Use [`one_of()`](https://davzim.github.io/rdantic/reference/one_of.md)
when you want a plain string out, and `fct()` when you want a factor
with a fixed, ordered level set.

## See also

[`one_of()`](https://davzim.github.io/rdantic/reference/one_of.md),
[primitives](https://davzim.github.io/rdantic/reference/primitives.md)

## Examples

``` r
size <- fct("low", "mid", "high")
size("mid")
#> [1] mid
#> Levels: low mid high
levels(size(c("high", "low")))
#> [1] "low"  "mid"  "high"
try(size("enormous"))
#> Error : 1 validation problem in fct("low", "mid", "high")
#>   <value>  expected fct("low", "mid", "high"), got chr[1] "enormous"  -- levels are low, mid, high

fct()(factor("anything"))
#> [1] anything
#> Levels: anything
schema(size)
#> $type
#> [1] "array"
#> 
#> $items
#> $items$type
#> [1] "string"
#> 
#> $items$enum
#> $items$enum[[1]]
#> [1] "low"
#> 
#> $items$enum[[2]]
#> [1] "mid"
#> 
#> $items$enum[[3]]
#> [1] "high"
#> 
#> 
#> 
```
