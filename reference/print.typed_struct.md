# Print a struct

Print a struct

## Usage

``` r
# S3 method for class 'typed_struct'
print(x, ...)
```

## Arguments

- x:

  A struct.

- ...:

  Ignored.

## Value

`x`, invisibly.

## Examples

``` r
print(struct("PrintDemo", id = int[1], tag = chr[1] %default% "none"))
#> <struct> PrintDemo
#>   id  : int[1]
#>   tag : chr[1] = "none"
```
