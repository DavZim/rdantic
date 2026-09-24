# Turn a struct into an S7 class

The properties are the struct's fields and every one of them validates
through its rdantic type on construction and on `@<-`, coercing where
rdantic would coerce and raising the same `typed_error`. Use it to hand
an rdantic-checked record to code that expects S7 –
[`S7::prop()`](https://rconsortium.github.io/S7/reference/prop.html),
`@`, and S7 generics all work on the result.

## Usage

``` r
as_s7_class(x, .name = NULL)
```

## Arguments

- x:

  A struct, or anything
  [`as_type()`](https://davzim.github.io/rdantic/reference/as_type.md)
  accepts that resolves to one.

- .name:

  The class name; defaults to the struct's.

## Value

An S7 class.

## Details

Properties are declared
[`S7::class_any`](https://rconsortium.github.io/S7/reference/class_any.html),
because the real constraint is the rdantic type, not S7's class check. A
struct made with
[`extend()`](https://davzim.github.io/rdantic/reference/extend.md)
becomes an S7 subclass of its parent's class; if it retypes one of the
parent's fields the hierarchy is flattened with a warning, because S7
keeps the parent's property definition and the narrower type would be
ignored.

Reach for
[`s7_struct()`](https://davzim.github.io/rdantic/reference/s7_struct.md)
instead when there is no struct to convert.

## See also

[`s7_struct()`](https://davzim.github.io/rdantic/reference/s7_struct.md),
[`s7_type()`](https://davzim.github.io/rdantic/reference/s7_type.md) for
the other direction.

## Examples

``` r
if (requireNamespace("S7", quietly = TRUE)) {
  library(S7)   # for `@`, which S7 supplies on R < 4.3

  Account <- struct("Account",
    id     = int[1][. > 0],
    email  = chr[1][grepl("@", ., fixed = TRUE)],
    credit = num[1][. >= 0] %default% 0
  )
  S7Account <- as_s7_class(Account)

  a <- S7Account(id = 1, email = "ada@example.org")
  a@credit

  a@credit <- 10L   # coerced to double, exactly as rdantic would
  typeof(a@credit)

  try(a@id <- 0)
  try(S7Account(id = 1))
}
#> Error : 1 validation problem in <Account>
#>   @id  expected int[1][. > 0], got num[1] 0
#> Error : 1 validation problem in <Account>
#>   @email  expected chr[1][grepl("@", ., fixed = TRUE)], got <missing>
```
