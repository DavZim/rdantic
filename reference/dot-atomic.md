# Build a primitive vector type

Build a primitive vector type

## Usage

``` r
.atomic(name, test, coerce = NULL, json = name, empty)
```

## Arguments

- name:

  The type name (`"int"`, `"num"`, ...).

- test:

  `function(x)` recognising the R type.

- coerce:

  Optional `function(x)` returning a lossless conversion, or `NULL` when
  none is possible.

- json:

  The JSON Schema type name.

- empty:

  The zero-length vector of this type, used when a JSON `[]` arrives.

## Value

A type.

## Examples

``` r
raw_t <- rdantic:::.atomic("raw", is.raw, NULL, "string", raw())
raw_t(as.raw(1:3))
#> [1] 01 02 03
```
