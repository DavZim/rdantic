# Make a type optional

Shorthand for `T | NULL`, and the readable way to write a self-reference
or a forward reference by name.

## Usage

``` r
opt(t)
```

## Arguments

- t:

  A type, or a struct name.

## Value

A type.

## Examples

``` r
opt(int[1])(NULL)
#> NULL
opt(int[1])(3)
#> [1] 3
opt("User")
#> <type> User | NULL
```
