# Reject names that would collide with generated code's own bindings

[`fn()`](https://davzim.github.io/rdantic/reference/fn.md) and
[`struct()`](https://davzim.github.io/rdantic/reference/struct.md)
splice user-supplied names into generated code alongside a handful of
internal bookkeeping variables; a name equal to one of those would
silently shadow it instead of erroring, so this rejects the collision up
front instead.

## Usage

``` r
.reject_reserved(nms, reserved, what)
```

## Arguments

- nms:

  The supplied names.

- reserved:

  The names that must not be used.

- what:

  What kind of name this is, e.g. `"argument"` or `"field"`.

## Value

Nothing; throws when a reserved name is used.

## Examples

``` r
rdantic:::.reject_reserved(c("x", "y"), c(".r_"), "argument")
try(rdantic:::.reject_reserved(c(".r_"), c(".r_"), "argument"))
#> Error : argument name `.r_` is reserved for rdantic's internals; choose a different name
```
