# Print an instance

Print an instance

## Usage

``` r
# S3 method for class 'typed_instance'
print(x, ...)
```

## Arguments

- x:

  An instance.

- ...:

  Ignored.

## Value

`x`, invisibly.

## Examples

``` r
Box <- struct("Box", label = chr[1], items = list_of(chr[1]))
print(Box(label = "tools", items = list("hammer", "nail")))
#> <Box>
#>   label : "tools"
#>   items : <list of 2>
```
