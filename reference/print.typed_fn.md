# Print a typed function's signature

Print a typed function's signature

## Usage

``` r
# S3 method for class 'typed_fn'
print(x, ...)
```

## Arguments

- x:

  A typed function.

- ...:

  Ignored.

## Value

`x`, invisibly.

## Examples

``` r
print(fn(x = int[1], y = chr[1] %default% "a", ~ chr[1], { paste0(y, x) }))
#> <fn> (x: int[1], y: chr[1] = "a") -> chr[1]
```
