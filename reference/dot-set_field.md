# Validate and set a field

Validate and set a field

## Usage

``` r
.set_field(x, name, value)
```

## Arguments

- x:

  An instance.

- name:

  A field name.

- value:

  The new value.

## Value

A new instance.

## Examples

``` r
rdantic:::.set_field(struct("SetDemo", a = int[1])(a = 1), "a", 2)
#> <SetDemo>
#>   a : 2L
```
