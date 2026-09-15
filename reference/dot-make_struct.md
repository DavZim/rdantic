# Compile a struct spec into a constructor

The constructor gets one formal per field, so
[`args()`](https://rdrr.io/r/base/args.html), autocomplete and R's own
"unused argument" error all work before any validation runs.

## Usage

``` r
.make_struct(spec, spec_env = list2env(spec, parent = emptyenv()))
```

## Arguments

- spec:

  A struct spec.

- spec_env:

  `spec`, wrapped in an environment; what instances carry as their own
  `spec` attribute (see
  [`.bind_instance()`](https://davzim.github.io/rdantic/reference/dot-bind_instance.md)).

## Value

A constructor of class `typed_struct`.

## Examples

``` r
args(rdantic:::.make_struct(rdantic:::.spec(struct("MkDemo", a = int[1], b = chr[1]))))
#> function (a, b) 
#> NULL
```
