# A struct's signature, for spotting redefinitions

A struct's signature, for spotting redefinitions

## Usage

``` r
.sig(spec)
```

## Arguments

- spec:

  A struct spec.

## Value

A single string.

## Examples

``` r
rdantic:::.sig(rdantic:::.spec(struct("SigDemo", x = int[1])))
#> [1] "SigDemo(x: int[1]) ignore"
```
