# Print a type

Print a type

## Usage

``` r
# S3 method for class 'type'
print(x, ...)
```

## Arguments

- x:

  A type.

- ...:

  Ignored.

## Value

`x`, invisibly.

## Examples

``` r
print(int[1])
#> <type> int[1]
print(one_of("a", "b") %default% "a")
#> <type> one_of("a", "b")  (default: "a")
```
