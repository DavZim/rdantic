# Which fields must be supplied?

A field is optional when it has a default or when its type accepts
`NULL`.

## Usage

``` r
.required_fields(fields)
```

## Arguments

- fields:

  A named list of types.

## Value

A character vector of field names.

## Examples

``` r
rdantic:::.required_fields(list(a = int[1], b = int[1] | NULL, c = chr %default% "x"))
#> [1] "a"
```
