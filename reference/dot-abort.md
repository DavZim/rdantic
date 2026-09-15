# Throw a validation error

Every problem is reported, one per line, each with its path, what was
expected, what arrived, and a hint when there is one. The condition
carries the records in `$problems` so tooling can consume them.

## Usage

``` r
.abort(problems, context)
```

## Arguments

- problems:

  A `typed_problems` object or a plain list of records.

- context:

  What was being validated, used in the first line.

## Value

Nothing; throws a condition of class `typed_error`.

## Examples

``` r
try(rdantic:::.abort(rdantic:::.bad("$id", "int[1]", "chr[1] \"x\""), "User"))
#> Error : 1 validation problem in User
#>   $id  expected int[1], got chr[1] "x"
```
