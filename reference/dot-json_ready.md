# Walk a value alongside its declared type

A length-1 vector is only unboxed to a JSON scalar when its type says
`[1]` (or `one_of`); otherwise [`I()`](https://rdrr.io/r/base/AsIs.html)
keeps it an array, so a `tags = "a"` field declared `chr` serialises as
`["a"]`, not `"a"`.

## Usage

``` r
.json_ready(x, t)
```

## Arguments

- x:

  The value.

- t:

  Its declared type, or `NULL` when unknown.

## Value

A structure ready for
[`jsonlite::toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html).

## Examples

``` r
rdantic:::.json_ready("a", chr)
#> [1] "a"
rdantic:::.json_ready("a", chr[1])
#> [1] "a"
```
