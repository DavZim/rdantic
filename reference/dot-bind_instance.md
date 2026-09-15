# Wrap validated values as an instance

Instances are plain lists: copy-on-modify like every other R value,
cheap to build, and
[`identical()`](https://rdrr.io/r/base/identical.html),
[`saveRDS()`](https://rdrr.io/r/base/readRDS.html) and
[`str()`](https://rdrr.io/r/utils/str.html) all behave. The `spec`
attribute is an environment, not the spec list itself, so
[`object.size()`](https://rdrr.io/r/utils/object.size.html) – which
charges environments a small fixed cost instead of recursing into them –
does not report each instance as if it owned a private copy of the whole
(shared) struct definition.

## Usage

``` r
.bind_instance(spec, vals, spec_env = spec)
```

## Arguments

- spec:

  A struct spec.

- vals:

  The validated values.

- spec_env:

  `spec`, wrapped in an environment; defaults to `spec` itself so direct
  calls (e.g. from examples) still work.

## Value

An object of class `c(name, parents, "typed_instance")`.

## Examples

``` r
rdantic:::.bind_instance(rdantic:::.spec(struct("BindDemo", a = int[1])), list(a = 1L))
#> <BindDemo>
#>   a : 1L
```
