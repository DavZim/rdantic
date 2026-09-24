# Define a record type

Returns a constructor with real formals – so autocomplete works – which
is itself a type, so structs nest and can be used anywhere a type can.
Instances are plain named lists with a class, which means they copy on
modify like every other R value.

## Usage

``` r
struct(
  .name,
  ...,
  .description = NULL,
  .parents = character(),
  .extra = c("ignore", "forbid")
)
```

## Arguments

- .name:

  The struct's name, as a single string.

- ...:

  Named fields, one type each.

- .description:

  The struct's JSON Schema `"description"`, or `NULL` to omit it. Use
  [`desc()`](https://davzim.github.io/rdantic/reference/desc.md)/[`%doc%`](https://davzim.github.io/rdantic/reference/desc.md)
  for a field's own description instead.

- .parents:

  Set by
  [`extend()`](https://davzim.github.io/rdantic/reference/extend.md);
  not usually written by hand.

- .extra:

  `"forbid"` rejects unknown keys when parsing a list into this struct;
  the default `"ignore"` drops them.

## Value

A constructor of class `typed_struct`, which is also a type.

## Details

Where a struct is expected, a plain list is parsed into it. That is what
makes JSON input work with no separate JSON mode.

## See also

[`extend()`](https://davzim.github.io/rdantic/reference/extend.md),
[`partial()`](https://davzim.github.io/rdantic/reference/partial.md),
[`list_of()`](https://davzim.github.io/rdantic/reference/list_of.md),
[`fields()`](https://davzim.github.io/rdantic/reference/fields.md)

## Examples

``` r
Account <- struct("Account",
  id      = int[1][. > 0],
  email   = chr[1][grepl("@", ., fixed = TRUE)],
  credit  = num[1][. >= 0] %default% 0,
  closed  = date[1] | NULL
)
#> Warning: struct `Account` redefined; values and refs made earlier keep the previous definition
Account
#> <struct> Account
#>   id     : int[1][. > 0]
#>   email  : chr[1][grepl("@", ., fixed = TRUE)]
#>   credit : num[1][. >= 0] = 0
#>   closed : date[1] | NULL

a <- Account(id = 1, email = "ada@example.org")
a
#> <Account>
#>   id     : 1L
#>   email  : "ada@example.org"
#>   credit : 0
#>   closed : NULL
a$credit
#> [1] 0

# every problem at once, each with its path
try(Account(id = 0, email = "nope"))
#> Error : 2 validation problems in Account
#>   $id     expected int[1][. > 0], got num[1] 0
#>   $email  expected chr[1][grepl("@", ., fixed = TRUE)], got chr[1] "nope"

# fields are checked on assignment, and instances are values
b <- a
b$credit <- 10
c(a$credit, b$credit)
#> [1]  0 10
try(a$balance <- 10)
#> Error : 1 validation problem in Account
#>   $balance  expected <no such field>, got num[1] 10

# a plain list is parsed
from_list(Account, list(id = 2, email = "bob@example.org"))
#> <Account>
#>   id     : 2L
#>   email  : "bob@example.org"
#>   credit : 0
#>   closed : NULL
try(from_list(struct("Shut", x = int[1], .extra = "forbid"), list(x = 1, y = 2)))
#> Error : 1 validation problem in Shut
#>   $y  expected <no such field>, got num[1] 2  -- did you mean `x`?
```
