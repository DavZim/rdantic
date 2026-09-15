# Fix a type's length, or add a constraint

`T[n]` is `T` with exactly `n` elements. `T[expr]`, where `expr`
mentions `.`, is `T` restricted to values for which the predicate holds
elementwise. The two chain in any order, and the source text of the
predicate becomes part of the type's name, so an error states the rule
that was broken.

## Usage

``` r
# S3 method for class 'type'
x[i]
```

## Arguments

- x:

  A type.

- i:

  A length, or an expression in `.`.

## Value

A type.

## Details

`T[1]` is the most useful type in R: most recycling bugs are a vector
arriving where one value was meant.

## Examples

``` r
int[1](3)
#> [1] 3
try(int[1](c(3, 4)))
#> Error : 1 validation problem in int[1]
#>   <value>  expected int[1], got num[2]  -- length is 2, not 1

num[. > 0](c(1, 2))
#> [1] 1 2
try(num[. > 0](c(1, -2)))
#> Error : 1 validation problem in num[. > 0]
#>   <value>  expected num[. > 0], got num[2]  -- fails at element 2

small <- int[1][0 < . & . < 10]
small
#> <type> int[1][0 < . & . < 10]
small(7)
#> [1] 7
try(small(70))
#> Error : 1 validation problem in int[1][0 < . & . < 10]
#>   <value>  expected int[1][0 < . & . < 10], got num[1] 70

chr[1][nchar(.) <= 3]("abc")
#> [1] "abc"
```
