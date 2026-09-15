# Types in depth

``` r

library(rdantic)
#> 
#> Attaching package: 'rdantic'
#> The following object is masked from 'package:graphics':
#> 
#>     frame
#> The following object is masked from 'package:base':
#> 
#>     date
```

A type in rdantic is an ordinary R value: a closure you can call, print,
store in a variable, and pass to
[`struct()`](https://davzim.github.io/rdantic/reference/struct.md) or
[`fn()`](https://davzim.github.io/rdantic/reference/fn.md). This
vignette covers the vocabulary for building one out of R’s own atomic
vectors, `[ ]` and `|`. For records and functions see
[`vignette("structs")`](https://davzim.github.io/rdantic/articles/structs.md)
and
[`vignette("typed-functions")`](https://davzim.github.io/rdantic/articles/typed-functions.md);
for lists, maps and data frames see
[`vignette("containers")`](https://davzim.github.io/rdantic/articles/containers.md).

## The four primitives

`int`, `num`, `chr` and `lgl` cover R’s atomic vector types. Each one,
called on a value, validates it and hands it back – coerced only when
that coercion cannot lose anything.

``` r

int; num; chr; lgl
#> <type> int
#> <type> num
#> <type> chr
#> <type> lgl
```

``` r

int(c(1, 2, 3))          # whole doubles  -> integer
#> [1] 1 2 3
num(2L)                  # integer        -> double
#> [1] 2
chr(factor("a"))         # factor         -> character
#> [1] "a"
int(1.5)                 # lossy: rejected
#> Error:
#> ! 1 validation problem in int
#>   <value>  expected int, got num[1] 1.5  -- not a whole number
int("3")                 # parsing strings is never implicit
#> Error:
#> ! 1 validation problem in int
#>   <value>  expected int, got chr[1] "3"  -- strings are never parsed implicitly
lgl(1)                   # 0/1 is not TRUE/FALSE
#> Error:
#> ! 1 validation problem in lgl
#>   <value>  expected lgl, got num[1] 1  -- 0/1 is not TRUE/FALSE
```

Every error names what was expected and what arrived – type, length, and
for scalars the value itself. That shape is the same everywhere in
rdantic, whether the failure came from a bare type, a struct field or a
function argument.

Because types are values, name them and reuse them across a codebase:

``` r

id_t    <- int[1][. > 0]
email_t <- chr[1][grepl("@", ., fixed = TRUE)]
```

Use them exactly like any other type – call them to validate:

``` r

id_t(1)
#> [1] 1
id_t(c(0, 1))
#> Error:
#> ! 1 validation problem in int[1][. > 0]
#>   <value>  expected int[1][. > 0], got num[2]  -- length is 2, not 1

email_t("something@example.com")
#> [1] "something@example.com"
email_t("This is not an email")
#> Error:
#> ! 1 validation problem in chr[1][grepl("@", ., fixed = TRUE)]
#>   <value>  expected chr[1][grepl("@", ., fixed = TRUE)], got chr[1] "This is not an email"
```

### Strict mode

By default, rdantic coerces where nothing is lost. Turn that off to
require the exact R type:

``` r

options(rdantic.strict = TRUE)
int(1)                    # a double, even a whole one, no longer coerces
#> Error:
#> ! 1 validation problem in int
#>   <value>  expected int, got num[1] 1  -- rdantic.strict = TRUE, so no coercion was attempted
options(rdantic.strict = FALSE)
```

## Length

R’s central data structure is the vector, so a type without a length is
a type of vectors. `T[n]` fixes the length to exactly `n`; `T[1]` is the
common scalar case.

``` r

int[3](c(1, 2, 3))
#> [1] 1 2 3
int[3](c(1, 2))
#> Error:
#> ! 1 validation problem in int[3]
#>   <value>  expected int[3], got num[2]  -- length is 2, not 3
int[1](c(1, 2))
#> Error:
#> ! 1 validation problem in int[1]
#>   <value>  expected int[1], got num[2]  -- length is 2, not 1
```

`[1]` matters more than it looks: most bugs from R’s recycling rules
come from a vector of the wrong length arriving where a single value was
meant.

For a range rather than an exact length, use `length(.)`: inside `[ ]`,
`.` is bound to the whole vector, not one element at a time, so
`length(.)` is the vector’s length.

``` r

int[length(.) <= 3](c(1, 2))
#> [1] 1 2
int[length(.) <= 3](c(1, 2, 3, 4))
#> Error:
#> ! 1 validation problem in int[length(.) <= 3]
#>   <value>  expected int[length(.) <= 3], got num[4]

int[length(.) >= 10](1:10)
#>  [1]  1  2  3  4  5  6  7  8  9 10
int[length(.) >= 10](1:5)
#> Error:
#> ! 1 validation problem in int[length(.) >= 10]
#>   <value>  expected int[length(.) >= 10], got int[5]
```

## Constraints

Anything inside `[ ]` that mentions `.` is a predicate over the value,
applied elementwise. Length and constraints chain in any order, and can
be combined:

``` r

num[. > 0](c(1, 2))
#> [1] 1 2
num[. > 0](c(1, -2))
#> Error:
#> ! 1 validation problem in num[. > 0]
#>   <value>  expected num[. > 0], got num[2]  -- fails at element 2

int[1][. > 5](9)
#> [1] 9
int[1][. > 5](3)
#> Error:
#> ! 1 validation problem in int[1][. > 5]
#>   <value>  expected int[1][. > 5], got num[1] 3

chr[1][nchar(.) <= 3]("abcd")
#> Error:
#> ! 1 validation problem in chr[1][nchar(.) <= 3]
#>   <value>  expected chr[1][nchar(.) <= 3], got chr[1] "abcd"
```

The constraint’s source text becomes part of the type’s name, so the
error message tells the reader the rule that was broken, not just that
some rule was.

## Unions, optionals and defaults

`A | B` accepts either type. `T | NULL` (or the shorthand `opt(T)`) is
how to say “optional”. `%default%` attaches a value used when nothing is
supplied – by a struct field or a function argument, see
[`vignette("structs")`](https://davzim.github.io/rdantic/articles/structs.md)
and
[`vignette("typed-functions")`](https://davzim.github.io/rdantic/articles/typed-functions.md).

``` r

(int[1] | chr[1])(7)
#> [1] 7
(int[1] | chr[1])("seven")
#> [1] "seven"
(int[1] | chr[1])(TRUE)
#> Error:
#> ! 1 validation problem in int[1] | chr[1]
#>   <value>  expected int[1] | chr[1], got lgl[1] TRUE

(int[1] | NULL)(NULL)
#> NULL
opt(int[1])(NULL)
#> NULL

one_of("admin", "user") %default% "user"
#> <type> one_of("admin", "user")  (default: "user")
```

## Enums, missing values and custom rules

`one_of(...)` restricts a value to an exact set of options. `no_na(T)`
wraps any type to additionally reject `NA`.

``` r

one_of("low", "mid", "high")("high")
#> [1] "high"
one_of("low", "mid", "high")("medium")
#> Error:
#> ! 1 validation problem in one_of("low", "mid", "high")
#>   <value>  expected one_of("low", "mid", "high"), got chr[1] "medium"

no_na(num)(c(1, 2))
#> [1] 1 2
no_na(num)(c(1, NA))
#> Error:
#> ! 1 validation problem in no_na(num)
#>   <value>  expected no_na(num), got num[2]  -- contains NA
```

For dates, times and restricted factors, see
[`vignette("temporal-types")`](https://davzim.github.io/rdantic/articles/temporal-types.md).

When nothing built in fits,
[`type_from()`](https://davzim.github.io/rdantic/reference/type_from.md)
builds a type from a plain predicate and an optional coercion, without
touching rdantic’s internal problem format:

``` r

hex <- type_from("hex", function(x) is.character(x) && all(grepl("^#[0-9a-f]{6}$", x)))
hex("#00ff99")
#> [1] "#00ff99"
hex("green")
#> Error:
#> ! 1 validation problem in hex
#>   <value>  expected hex, got chr[1] "green"

port <- type_from(
  "port",
  function(x) is.integer(x) && length(x) == 1 && x > 0 && x < 65536,
  coerce = function(x) as.integer(x),
  json = "integer",
  scalar = TRUE
)
port(8080)
#> [1] 8080
```

For a type that needs full control over its validation logic and JSON
Schema fragment, see
[`new_type()`](https://davzim.github.io/rdantic/reference/new_type.md)
in
[`vignette("extending-rdantic")`](https://davzim.github.io/rdantic/articles/extending-rdantic.md).

## Validating a value directly

A type is callable, but three other entry points exist for when the type
is not known ahead of time, or when a thrown error is not what you want
– see
[`vignette("errors-and-validation")`](https://davzim.github.io/rdantic/articles/errors-and-validation.md)
for the full picture:

``` r

parse_as(int[1], 3)             # same as int[1](3), useful when the type is a variable
#> [1] 3
is_valid(int[1], 3.5)           # TRUE/FALSE, no detail
#> [1] FALSE
try_parse(int[1], "x")$ok       # validate without throwing
#> [1] FALSE
```
