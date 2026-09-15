# Convert an instance to a list

Convert an instance to a list

## Usage

``` r
# S3 method for class 'typed_instance'
as.list(x, ...)
```

## Arguments

- x:

  An instance.

- ...:

  Ignored.

## Value

A named list.

## Examples

``` r
as.list(struct("Rgb", r = int[1], g = int[1], b = int[1])(r = 1, g = 2, b = 3))
#> $r
#> [1] 1
#> 
#> $g
#> [1] 2
#> 
#> $b
#> [1] 3
#> 
```
