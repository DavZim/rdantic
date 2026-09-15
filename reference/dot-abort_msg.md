# Throw a typed error that is about the type, not about a value

Used for things like an unresolvable
[`ref()`](https://davzim.github.io/rdantic/reference/ref.md), which must
still be catchable as `typed_error` rather than escaping as a bare
`simpleError`.

## Usage

``` r
.abort_msg(msg)
```

## Arguments

- msg:

  The message to show.

## Value

Nothing; throws a condition of class `typed_error`.

## Examples

``` r
try(rdantic:::.abort_msg("unknown struct `Nope`"))
#> Error : unknown struct `Nope`
```
