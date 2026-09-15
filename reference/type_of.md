# Describe the type of a value the way rdantic names types

Length is part of the description, because in R it is part of the type:
`int[1]` and `int[3]` are different shapes with different bugs.

## Usage

``` r
type_of(x)
```

## Arguments

- x:

  Any R value.

## Value

A single string, e.g. `"int[3]"`, `"<User>"`, `"data.frame[2 x 3]"`.

## Examples

``` r
type_of(1:3)
#> [1] "int[3]"
type_of(1.5)
#> [1] "num[1]"
type_of("a")
#> [1] "chr[1]"
type_of(Sys.Date())
#> [1] "date[1]"
type_of(data.frame(a = 1:2))
#> [1] "data.frame[2 x 1]"
type_of(NULL)
#> [1] "NULL"
```
