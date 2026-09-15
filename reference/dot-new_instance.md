# Validate arguments and build an instance

Validate arguments and build an instance

## Usage

``` r
.new_instance(spec, args, path, spec_env = spec)
```

## Arguments

- spec:

  A struct spec.

- args:

  The supplied named values.

- path:

  The path prefix for problem records.

- spec_env:

  `spec`, wrapped in an environment; defaults to `spec` itself so direct
  calls (e.g. from examples) still work.

## Value

An instance, or a `typed_problems` object.

## Examples

``` r
rdantic:::.new_instance(rdantic:::.spec(struct("NewDemo", a = int[1])), list(a = 1), "")
#> <NewDemo>
#>   a : 1L
```
