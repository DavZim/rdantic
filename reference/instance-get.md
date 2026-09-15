# Read a field of an instance

Matching is exact: `x$nam` is an error rather than a quiet hit on
`name`, which is what a plain list would do.

## Usage

``` r
# S3 method for class 'typed_instance'
x$name

# S3 method for class 'typed_instance'
x[[i, ...]]
```

## Arguments

- x:

  An instance.

- name, i:

  A field name, or a position.

- ...:

  Ignored.

## Value

The field's value.

## Examples

``` r
Card <- struct("Card", holder = chr[1], number = chr[1])
cc <- Card(holder = "Ada", number = "4111")
cc$holder
#> [1] "Ada"
cc[["number"]]
#> [1] "4111"
try(cc$holdr)
#> Error : <Card> has no field `holdr` -- did you mean `holder`?
#>   fields: holder, number
```
