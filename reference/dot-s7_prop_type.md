# Translate an S7 property class into a type

S7 describes a property's class; rdantic describes its shape as well.
The mapping keeps what transfers – the base types, `Date`, `POSIXct`,
unions and nested S7 classes – and falls back to
[anything](https://davzim.github.io/rdantic/reference/primitives.md)
rather than inventing a constraint S7 never made.

## Usage

``` r
.s7_prop_type(cl)
```

## Arguments

- cl:

  A property class: an S7 base class, S3 class, union, class object or
  `NULL`.

## Value

A type.

## Examples

``` r
if (requireNamespace("S7", quietly = TRUE))
  rdantic:::.s7_prop_type(S7::class_character)
#> <type> chr
```
