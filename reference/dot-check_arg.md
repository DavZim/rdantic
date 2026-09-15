# Validate one argument of a typed function

An omitted argument is validated as `NULL`, so a type that accepts
`NULL` makes the argument optional and anything else reports it as
missing.

## Usage

``` r
.check_arg(t, x, name)
```

## Arguments

- t:

  The argument's type.

- x:

  The supplied value, or the `.missing_` marker.

- name:

  The argument's name, used as the problem path.

## Value

The validated value, or a `typed_problems` object.

## Examples

``` r
rdantic:::.check_arg(int[1], 1, "x")
#> [1] 1
rdantic:::.check_arg(int[1], rdantic:::.missing_, "x")
#> [[1]]
#> [[1]]$path
#> [1] "x"
#> 
#> [[1]]$expected
#> [1] "int[1]"
#> 
#> [[1]]$got
#> [1] "<missing>"
#> 
#> [[1]]$hint
#> NULL
#> 
#> 
#> attr(,"class")
#> [1] "typed_problems"
```
