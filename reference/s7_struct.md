# Define an S7 class with rdantic field types

[`struct()`](https://davzim.github.io/rdantic/reference/struct.md) with
an S7 class as the result: the fields are declared exactly as they would
be for a struct, and what comes back is a real S7 class whose properties
validate – and coerce – through those types on construction and on
`@<-`, raising the usual `typed_error`.

## Usage

``` r
s7_struct(
  .name,
  ...,
  .description = NULL,
  .parent = NULL,
  .extra = c("ignore", "forbid")
)
```

## Arguments

- .name:

  The class's name, as a single string.

- ...:

  Named fields, one type each.

- .description:

  The JSON Schema `"description"` for
  [`schema()`](https://davzim.github.io/rdantic/reference/schema.md), or
  `NULL` to omit it.

- .parent:

  An S7 class to inherit from, or `NULL`. Its properties are inherited
  as typed fields.

- .extra:

  `"forbid"` rejects unknown keys when parsing a list into the class;
  the default `"ignore"` drops them.

## Value

An S7 class.

## Details

Unlike
[`struct()`](https://davzim.github.io/rdantic/reference/struct.md), the
name is *not* registered, so
[`ref()`](https://davzim.github.io/rdantic/reference/ref.md) and
`opt("Name")` will not resolve it: a name in that registry means
something that builds instances, and this builds S7 objects. Pass the
class itself instead – it is a value, and a type.

## See also

[`as_s7_class()`](https://davzim.github.io/rdantic/reference/as_s7_class.md)
to convert an existing struct,
[`struct()`](https://davzim.github.io/rdantic/reference/struct.md) for
the plain-list equivalent.

## Examples

``` r
if (requireNamespace("S7", quietly = TRUE)) {
  library(S7)   # for `@`, which S7 supplies on R < 4.3

  Account <- s7_struct("Account",
    id     = int[1][. > 0],
    email  = chr[1][grepl("@", ., fixed = TRUE)],
    credit = num[1][. >= 0] %default% 0
  )

  a <- Account(id = 1, email = "ada@example.org")
  a@credit

  a@credit <- 10L   # coerced to double, exactly as rdantic would
  typeof(a@credit)

  try(a@id <- 0)
  try(Account(id = 1))

  # it is a type, so it parses, validates and describes itself
  from_json(Account, '{"id": 2, "email": "bob@example.org"}')
  schema(Account)$required

  Premium <- s7_struct("Premium", tier = one_of("gold", "silver"),
                       .parent = Account)
  S7_inherits(Premium(id = 1, email = "a@b.org", tier = "gold"), Account)
}
#> Error : 1 validation problem in <Account>
#>   @id  expected int[1][. > 0], got num[1] 0
#> Error : 1 validation problem in <Account>
#>   @email  expected chr[1][grepl("@", ., fixed = TRUE)], got <missing>
#> [1] TRUE
```
