# Run one top-level validation

Establishes the validation context and restores whatever was there
before, so nested entries (a struct inside a
[`from_json()`](https://davzim.github.io/rdantic/reference/from_json.md))
keep the outer settings.

## Usage

``` r
.entry(expr, parsing = FALSE)
```

## Arguments

- expr:

  The validation to run. Evaluated in the caller's frame.

- parsing:

  Whether the input came from JSON or a plain list.

## Value

The value of `expr`.

## Examples

``` r
rdantic:::.entry(rdantic:::.strict())
#> [1] FALSE
```
