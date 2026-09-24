# Is the S7 package available?

S7 is a suggested dependency: everything here is reachable only through
a value that S7 itself created, so the check can never fail in the
middle of a validation.

## Usage

``` r
.has_s7()
```

## Value

`TRUE` when S7 can be loaded.

## Examples

``` r
rdantic:::.has_s7()
```
