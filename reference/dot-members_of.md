# The fields a type can be subclassed or weakened through

The fields a type can be subclassed or weakened through

## Usage

``` r
.members_of(t, what)
```

## Arguments

- t:

  A type.

- what:

  The calling function, for the error message.

## Value

A named list of types.

## Examples

``` r
names(rdantic:::.members_of(struct("FieldsDemo", a = int[1]), "extend()"))
#> [1] "a"
```
