# Report a validation failure

A validator returns the (possibly coerced) value on success, or the
object built here on failure, so the happy path allocates nothing beyond
the value itself.
[`.is_bad()`](https://davzim.github.io/rdantic/reference/dot-is_bad.md)
tells the two apart.

## Usage

``` r
.fail(problems)
```

## Arguments

- problems:

  A list of `{path, expected, got, hint}` records.

## Value

A list of problem records, of class `typed_problems`.

## Examples

``` r
p <- rdantic:::.fail(list(list(path = "$x", expected = "int", got = "chr[1]")))
rdantic:::.is_bad(p)
#> [1] TRUE
```
