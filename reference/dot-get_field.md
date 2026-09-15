# Read a field, without partial matching

Read a field, without partial matching

## Usage

``` r
.get_field(x, i)
```

## Arguments

- x:

  An instance.

- i:

  A field name, or a position.

## Value

The field's value.

## Examples

``` r
rdantic:::.get_field(struct("GetDemo", a = int[1])(a = 1), "a")
#> [1] 1
```
