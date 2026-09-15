# Restrict a type with a predicate

Restrict a type with a predicate

## Usage

``` r
.refined(t, expr, env)
```

## Arguments

- t:

  A type.

- expr:

  An unevaluated expression in `.`.

- env:

  The environment the expression is evaluated in.

## Value

A type.

## Examples

``` r
rdantic:::.refined(int, quote(. > 0), environment())(c(1, 2))
#> [1] 1 2
```
