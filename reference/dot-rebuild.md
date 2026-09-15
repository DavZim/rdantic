# Rebuild a type from a modified spec

Rebuild a type from a modified spec

## Usage

``` r
.rebuild(spec)
```

## Arguments

- spec:

  A spec list, usually one that came out of
  [`.spec()`](https://davzim.github.io/rdantic/reference/dot-spec.md)
  with an entry added or removed.

## Value

A type (or a struct constructor, if the spec has fields).

## Examples

``` r
s <- rdantic:::.spec(int)
s$name <- "whole_number"
rdantic:::.rebuild(s)
#> <type> whole_number
```
