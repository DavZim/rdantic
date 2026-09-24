# Build a struct constructor without registering it

The part of
[`struct()`](https://davzim.github.io/rdantic/reference/struct.md) that
makes the type.
[`s7_struct()`](https://davzim.github.io/rdantic/reference/s7_struct.md)
needs it without the name ever entering `.registry`, because the name
there would resolve to something that builds instances rather than S7
objects.

## Usage

``` r
.struct_ctor(name, fields, parents, description, extra)
```

## Arguments

- name:

  The struct's name.

- fields:

  A named list of types.

- parents:

  The parent class names.

- description:

  The schema `"description"`, or `NULL`.

- extra:

  `"ignore"` or `"forbid"`.

## Value

A constructor of class `typed_struct`.

## Examples

``` r
rdantic:::.struct_ctor("Loose", list(a = int[1]), character(), NULL, "ignore")
#> <struct> Loose
#>   a : int[1]
```
