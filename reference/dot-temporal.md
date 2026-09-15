# Build a date or time type

Build a date or time type

## Usage

``` r
.temporal(name, cls, parse, shape, json, empty)
```

## Arguments

- name:

  The type name.

- cls:

  The R class that is accepted as-is.

- parse:

  `function(x)` parsing character input.

- shape:

  The accepted text layout, shown as a hint.

- json:

  The JSON Schema `format` value.

- empty:

  The zero-length value of this type.

## Value

A type.

## Examples

``` r
rdantic:::.temporal(
  "ymd", "Date", function(x) as.Date(x, "%Y-%m-%d"),
  "YYYY-MM-DD", "date", as.Date(character())
)("2024-05-17")
#> [1] "2024-05-17"
```
