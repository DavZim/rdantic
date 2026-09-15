# rdantic

[![R-CMD-check](https://github.com/DavZim/rdantic/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/DavZim/rdantic/actions/workflows/R-CMD-check.yaml)

**Declared types, checked at the boundary.** pydantic’s idea, in base R.

> **Status: proof of concept.** No S4, no R6, no code generation —
> closures, attributes and plain lists.

> **Feedback wanted!**

Concept by humans, implemented by AI.

``` r

library(rdantic)   # base R only; jsonlite is needed for the JSON helpers
```

## TL;DR

``` r

# define a struct with typed fields, optional fields, defaults and descriptions
User <- struct(
  .name = "User",
  .description = "A registered user.",
  id   = int[1][. > 0] %doc% "Unique, positive identifier.",
  name = chr[1] %doc% "Full name.",
  role = one_of("admin", "user") %default% "user" %doc% "Access level.",
  age  = (int[1] | NULL) %doc% "Age in years, if known."
)
User
#> <struct> User
#>   id   : int[1][. > 0]
#>   name : chr[1]
#>   role : one_of("admin", "user") = "user"
#>   age  : int[1] | NULL

# create a new instance, validated and coerced
ada <- User(id = 42, name = "Ada")

str(ada, give.attr = FALSE) # the object is a plain list, but it carries its own spec
#> List of 4
#>  $ id  : int 42
#>  $ name: chr "Ada"
#>  $ role: chr "user"
#>  $ age : NULL

# wrong id type, no implicit conversion
wrong <- User(id = "42", name = "Ada")
#> Error:
#> ! 1 validation problem in User
#>   $id  expected int[1][. > 0], got chr[1] "42"  -- strings are never parsed implicitly

to_json(schema(User))                     # descriptions land in the schema, not just a comment
#> {
#>   "type": "object",
#>   "title": "User",
#>   "description": "A registered user.",
#>   "properties": {
#>     "id": {
#>       "type": "integer",
#>       "description": "Unique, positive identifier."
#>     },
#>     "name": {
#>       "type": "string",
#>       "description": "Full name."
#>     },
#>     "role": {
#>       "enum": [
#>         "admin",
#>         "user"
#>       ],
#>       "description": "Access level."
#>     },
#>     "age": {
#>       "type": ["integer", "null"],
#>       "description": "Age in years, if known."
#>     }
#>   },
#>   "required": [
#>     "id",
#>     "name"
#>   ],
#>   "additionalProperties": false
#> }

greet <- fn(u = User, ~ chr[1], { paste("Hi,", u$name) })

greet(ada)                                # right: a real User
#> [1] "Hi, Ada"
greet(User(id = "1", name = "Ada"))       # wrong: every problem, with its path
#> Error:
#> ! 1 validation problem in User
#>   $id  expected int[1][. > 0], got chr[1] "1"  -- strings are never parsed implicitly
greet(User(id = 2, name = "Bob"))         # combined: build and call in one step
#> [1] "Hi, Bob"

greet_wrong <- fn(u = User, ~ chr[1], { paste0("Hi, ", u$name, "(", seq(u$id), ")") }) # wrong: return type is wrong
greet_wrong(ada)
#> Error:
#> ! 1 validation problem in greet_wrong()
#>   <return>  expected chr[1], got chr[42]  -- length is 42, not 1
```

Details about the types, structs, functions and JSON follow.

``` r

int[1][. > 0](5)                          # a type is a value: calling it validates + coerces
#> [1] 5
int[1][. > 0](-1)
#> Error:
#> ! 1 validation problem in int[1][. > 0]
#>   <value>  expected int[1][. > 0], got num[1] -1
```

``` r

ada$role                                  # "user" -- filled in by %default%
#> [1] "user"
ada$age <- "old"                          # instances stay valid: checked on assignment too
#> Error:
#> ! 1 validation problem in User
#>   $age  expected int[1] | NULL, got chr[1] "old"  -- strings are never parsed implicitly
```

``` r

budget <- map_of(int[1][. > 0])           # a map: any keys, one value type
budget(list(cpu = 4, memory = 16))
#> $cpu
#> [1] 4
#> 
#> $memory
#> [1] 16
```

``` r

from_json(User, '{"id": 1, "name": "Ada"}')
#> <User>
#>   id   : 1L
#>   name : "Ada"
#>   role : "user"
#>   age  : NULL
from_json(User, '{"id": -1, "name": "Ada"}')  # JSON in, validated against the same declaration
#> Error:
#> ! 1 validation problem in User
#>   $id  expected int[1][. > 0], got int[1] -1L
```

|  |  |
|----|----|
| **Types are values** | `int[1]`, `num[. > 0]`, `chr[1] \| NULL` — built from `[` and `\|`, no new syntax |
| **Length is part of the type** | `int` is any integer vector, `int[1]` is exactly one |
| **Every problem, with a path** | not the first failure — all of them, each saying where |
| **Lossless coercion only** | `1` → `1L` yes; `1.5` → `1L` no; `"1"` → `1L` never |
| **Records and functions** | [`struct()`](https://davzim.github.io/rdantic/reference/struct.md) for validated objects, [`fn()`](https://davzim.github.io/rdantic/reference/fn.md) for typed functions |
| **JSON in, JSON out** | [`from_json()`](https://davzim.github.io/rdantic/reference/from_json.md), [`to_json()`](https://davzim.github.io/rdantic/reference/to_json.md), [`schema()`](https://davzim.github.io/rdantic/reference/schema.md) |

## Motivation

A payload arrives from somewhere you don’t control. Plain R happily
computes an answer.

``` r

payload <- list(id = "1042", qty = 3, unit_price = 19.99, coupon = 1.2)

total <- function(o) o$qty * o$unit_price * (1 - o$coupon)
total(payload)
#> [1] -11.994
```

A negative total. No warning, no error. `id` is a string, `coupon` is
above 1, and the bug surfaces three calls later, in a report. Most R
bugs look like this: not a crash, but a value that was the wrong shape
all along.

Declare what the data *is*, once:

``` r

Order <- struct("Order",                  # name, then one `field = type` per column
  id         = int[1][. > 0],
  qty        = int[1][. > 0],
  unit_price = num[1][. >= 0],
  coupon     = num[1][0 <= . & . <= 1] %default% 0
)

Order(id = "1042", qty = 3, unit_price = 19.99, coupon = 1.2)
#> Error:
#> ! 2 validation problems in Order
#>   $id      expected int[1][. > 0], got chr[1] "1042"  -- strings are never parsed implicitly
#>   $coupon  expected num[1][0 <= . & . <= 1], got num[1] 1.2
```

Both mistakes at once, each naming the field and the rule it broke. Good
data goes through, coerced where that is lossless:

``` r

order <- Order(id = 1042, qty = 3, unit_price = 19.99)
order
#> <Order>
#>   id         : 1042L
#>   qty        : 3L
#>   unit_price : 19.99
#>   coupon     : 0
str(order$id)                            # the double 1042 arrived as an integer
#>  int 1042
```

Instances stay valid for their whole life, and a typed function can
neither be called nor return the wrong thing:

``` r

order$qty <- 0
#> Error:
#> ! 1 validation problem in Order
#>   $qty  expected int[1][. > 0], got num[1] 0

net <- fn(o = Order, ~ num[1][. >= 0], {  # arg = type, ..., ~ return type, then the body
  o$qty * o$unit_price * (1 - o$coupon)
})
net(order)
#> [1] 59.97
net(payload)
#> Error:
#> ! 2 validation problems in net()
#>   o$id      expected int[1][. > 0], got chr[1] "1042"  -- strings are never parsed implicitly
#>   o$coupon  expected num[1][0 <= . & . <= 1], got num[1] 1.2
```

The same declaration is also a contract with a model you don’t control.
Structured-output APIs want a JSON Schema up front, and whatever they
hand back still has to be checked before you trust it — normally two
artifacts, written by hand, free to drift apart.

``` r

Extraction <- struct("Extraction",
  name = chr[1],
  age  = int[1][. > 0],
  tags = list_of(chr[1])                  # list_of(T): a list of any length, all elements T
)

to_json(schema(Extraction))               # schema(T) builds a JSON Schema; to_json() serializes it
#> {
#>   "type": "object",
#>   "title": "Extraction",
#>   "properties": {
#>     "name": {
#>       "type": "string"
#>     },
#>     "age": {
#>       "type": "integer",
#>       "description": "satisfies . > 0"
#>     },
#>     "tags": {
#>       "type": "array",
#>       "items": {
#>         "type": "string"
#>       }
#>     }
#>   },
#>   "required": [
#>     "name",
#>     "age",
#>     "tags"
#>   ],
#>   "additionalProperties": false
#> }
```

Send that schema as the response format; whatever comes back goes
through
[`from_json()`](https://davzim.github.io/rdantic/reference/from_json.md)
— one declaration on both ends, so a reply that ignores the schema is
still caught.

``` r

reply <- '{"name": "Ada", "age": -1, "tags": ["r", "stats"]}'
from_json(Extraction, reply)              # from_json(T, txt): parse JSON text, validate against T
#> Error:
#> ! 1 validation problem in Extraction
#>   $age  expected int[1][. > 0], got int[1] -1L
```

That is the whole idea. The rest of this document is that idea applied
to vectors, records, nested data and JSON.

## Types

The four primitives cover R’s atomic vectors; `[ ]` adds length and
constraints, `|` adds alternatives, and a handful of constructors add
structure.

``` r

int; num; chr; lgl
#> <type> int
#> <type> num
#> <type> chr
#> <type> lgl
```

``` r

int[1]
#> <type> int[1]
num[. > 0]
#> <type> num[. > 0]
chr[1] | NULL
#> <type> chr[1] | NULL
no_na(num)                                # no_na(T): T, but NA is rejected
#> <type> no_na(num)
one_of("low", "mid", "high")              # one_of(...): an enum of these exact values
#> <type> one_of("low", "mid", "high")
fct("low", "mid", "high")                 # fct(...): a factor restricted to these levels
#> <type> fct("low", "mid", "high")
list_of(int[1])                           # list_of(T): a list of any length, all elements T
#> <type> list_of(int[1])
map_of(int[1])                            # map_of(T): arbitrary keys, one value type
#> <type> map_of(int[1])
list_of(cpu = int[1], memory = int[1])    # list_of(a = T, b = T, ...): fixed keys, one type each
#> <type> list_of(cpu, memory)
frame(id = int, label = chr)              # frame(col = T, ...): a data.frame with typed columns
#> <type> frame(id, label)
```

Because types are values, you name them and reuse them:

``` r

id_t    <- int[1][. > 0]
email_t <- chr[1][grepl("@", ., fixed = TRUE)]
```

A type is callable: calling it validates a value and hands it back,
coerced when that loses nothing.

``` r

int(c(1, 2, 3))          # whole doubles  -> integer
#> [1] 1 2 3
num(2L)                  # integer        -> double
#> [1] 2
chr(factor("a"))         # factor         -> character
#> [1] "a"
int(1.5)                 # lossy
#> Error:
#> ! 1 validation problem in int
#>   <value>  expected int, got num[1] 1.5  -- not a whole number
int("3")                 # parsing strings is never implicit
#> Error:
#> ! 1 validation problem in int
#>   <value>  expected int, got chr[1] "3"  -- strings are never parsed implicitly
lgl(1)
#> Error:
#> ! 1 validation problem in lgl
#>   <value>  expected lgl, got num[1] 1  -- 0/1 is not TRUE/FALSE
```

Every error names *what was expected* and *what arrived* — type, length,
and for scalars the value. That shape is the same everywhere in the
system.

Want no coercion at all? Values must then already be the right R type:

``` r

options(rdantic.strict = TRUE)
int(1)
#> Error:
#> ! 1 validation problem in int
#>   <value>  expected int, got num[1] 1  -- rdantic.strict = TRUE, so no coercion was attempted
options(rdantic.strict = FALSE)
```

## Length

R’s central data structure is the vector, so a type without a length is
a type of vectors. `T[n]` fixes the length; `T[1]` is a scalar.

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

The `[1]` matters more than it looks: most bugs from R’s recycling rules
come from a vector arriving where one value was meant.

## Constraints

Anything inside `[ ]` that mentions `.` is a predicate over the value.
It must return `TRUE` for every element. Constraints and lengths chain
in any order.

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
error tells the reader the rule that was broken, not just that one was.

## Unions, optionals, defaults

`A | B` accepts either. `T | NULL` is the idiom for optional.
`%default%` attaches a default value, used by structs and typed
functions when a value is not supplied.

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

one_of("admin", "user") %default% "user"
#> <type> one_of("admin", "user")  (default: "user")
int[1] | NULL %default% NULL              # a default on either side applies to the union
#> <type> int[1] | NULL  (default: NULL)
```

## Dates, factors, missing values

R’s other quiet failure modes: a `Date` is a number wearing a class, a
factor is an integer wearing labels, and `NA` sails through every
operator. Each gets a type.

``` r

date("2024-05-17")                        # ISO-8601 is unambiguous, so it is parsed
#> [1] "2024-05-17"
date("17/05/2024")
#> Error:
#> ! 1 validation problem in date
#>   <value>  expected date, got chr[1] "17/05/2024"  -- expected YYYY-MM-DD
num(Sys.Date())                           # ... but a Date is never silently a number
#> Error:
#> ! 1 validation problem in num
#>   <value>  expected num, got date[1] "2026-09-15"  -- a <Date> is never silently unclassed
fct("low", "high")("high")
#> [1] high
#> Levels: low high
no_na(num)(c(1, NA))
#> Error:
#> ! 1 validation problem in no_na(num)
#>   <value>  expected no_na(num), got num[2]  -- contains NA
```

When nothing built in fits,
[`type_from()`](https://davzim.github.io/rdantic/reference/type_from.md)
takes a plain predicate and an optional coercion:

``` r

# type_from(name, predicate, coerce = NULL)
hex <- type_from("hex", function(x) is.character(x) && all(grepl("^#[0-9a-f]{6}$", x)))
hex("#00ff99")
#> [1] "#00ff99"
hex("green")
#> Error:
#> ! 1 validation problem in hex
#>   <value>  expected hex, got chr[1] "green"
```

## Named lists

Give [`map_of()`](https://davzim.github.io/rdantic/reference/map_of.md)
one type and you get a map: any keys, one value type. Keys are kept, and
a failure is reported by key rather than by position — this is what a
JSON object with arbitrary keys parses into.
[`list_of()`](https://davzim.github.io/rdantic/reference/list_of.md)
given one type is the array counterpart: it only accepts an unnamed
list, so the two never overlap.

``` r

budget <- map_of(int[1][. > 0])

budget(list(cpu = 4, memory = 16))
#> $cpu
#> [1] 4
#> 
#> $memory
#> [1] 16
budget(list(cpu = 4, memory = 0, disk = "big"))
#> Error:
#> ! 2 validation problems in map_of(int[1][. > 0])
#>   $memory  expected int[1][. > 0], got num[1] 0
#>   $disk    expected int[1][. > 0], got chr[1] "big"  -- strings are never parsed implicitly
```

Name the arguments of
[`list_of()`](https://davzim.github.io/rdantic/reference/list_of.md)
instead and you get a third shape: a fixed key set with one rule per key
— still a plain named list on the way out, with no class and no struct
name.

``` r

limits <- list_of(cpu = int[1][0 < . & . < 12], memory = int[1][0 < . & . < 128])
limits
#> <type> list_of(cpu, memory)

str(limits(list(cpu = 4, memory = 16)))
#> List of 2
#>  $ cpu   : int 4
#>  $ memory: int 16
limits(list(cpu = 16, memory = 512))
#> Error:
#> ! 2 validation problems in list_of(cpu, memory)
#>   $cpu     expected int[1][0 < . & . < 12], got num[1] 16
#>   $memory  expected int[1][0 < . & . < 128], got num[1] 512
limits(list(cpu = 4))
#> Error:
#> ! 1 validation problem in list_of(cpu, memory)
#>   $memory  expected int[1][0 < . & . < 128], got <missing>
to_json(limits(list(cpu = 4L, memory = 16L)))
#> {
#>   "cpu": 4,
#>   "memory": 16
#> }
```

Missing keys are reported, `%default%` fills them in, and
`.extra = "forbid"` refuses unknown ones — the same record rules
[`struct()`](https://davzim.github.io/rdantic/reference/struct.md) uses.
Reach for a struct when the record deserves a name, a class and
inheritance; reach for `list_of(a = T, ...)` when it is just a shape.

## Records: `struct()`

A struct is a set of named, typed fields.
[`struct()`](https://davzim.github.io/rdantic/reference/struct.md)
returns a constructor, and that constructor is itself a type (so structs
nest and can be used anywhere a type is).

``` r

User <- struct("User",
  id     = id_t,
  name   = chr[1],
  email  = email_t,
  age    = int[1] | NULL,
  role   = one_of("admin", "user") %default% "user",
  tags   = chr %default% character(),
  friend = opt("User")                    # optional, refers to this struct by name
)
User
#> <struct> User
#>   id     : int[1][. > 0]
#>   name   : chr[1]
#>   email  : chr[1][grepl("@", ., fixed = TRUE)]
#>   age    : int[1] | NULL
#>   role   : one_of("admin", "user") = "user"
#>   tags   : chr = character(0)
#>   friend : User | NULL
```

Construct one like any R function — the constructor has real formals, so
autocomplete works:

``` r

ada <- User(id = 1, name = "Ada", email = "ada@lovelace.org")
ada
#> <User>
#>   id     : 1L
#>   name   : "Ada"
#>   email  : "ada@lovelace.org"
#>   age    : NULL
#>   role   : "user"
#>   tags   : character(0)
#>   friend : NULL
str(ada$id)                              # coerced to integer on the way in
#>  int 1
```

A field is required unless it has a default or accepts `NULL`. Every
problem is reported:

``` r

User(name = 42, email = "nope", role = "god")
#> Error:
#> ! 4 validation problems in User
#>   $id     expected int[1][. > 0], got <missing>
#>   $name   expected chr[1], got num[1] 42
#>   $email  expected chr[1][grepl("@", ., fixed = TRUE)], got chr[1] "nope"
#>   $role   expected one_of("admin", "user"), got chr[1] "god"
```

Fields are validated on assignment too, and the object is sealed — a
typo cannot quietly invent a field, or quietly read a different one.
`$<-`, `[[<-` and `[<-` all run the same check, so there is no
assignment form that skips it:

``` r

ada$age <- 36L
ada$age
#> [1] 36
ada$age <- "thirty-six"
#> Error:
#> ! 1 validation problem in User
#>   $age  expected int[1] | NULL, got chr[1] "thirty-six"  -- strings are never parsed implicitly
ada["age"] <- "thirty-six"               # [<- checks the field just like $<- does
#> Error:
#> ! 1 validation problem in User
#>   $age  expected int[1] | NULL, got chr[1] "thirty-six"  -- strings are never parsed implicitly
ada$nickname <- "Countess"
#> Error:
#> ! 1 validation problem in User
#>   $nickname  expected <no such field>, got chr[1] "Countess"
ada$nam
#> Error:
#> ! <User> has no field `nam` -- did you mean `name`?
#>   fields: id, name, email, age, role, tags, friend
```

A field name that collides with rdantic’s own internals (like `.args`)
is rejected when the struct is declared:

``` r

struct("Broken", .args = int[1])
#> Error:
#> ! field name `.args` is reserved for rdantic's internals; choose a different name
```

Instances are plain lists, so they behave like every other R value: copy
on modify, no action at a distance.

``` r

copy <- ada
copy$name <- "Grace"
c(ada$name, copy$name)
#> [1] "Ada"   "Grace"
identical(ada, User(id = 1, name = "Ada", email = "ada@lovelace.org", age = 36L))
#> [1] TRUE
```

## Nesting, and errors that report everything

Since a struct is a type, structs compose. Where a struct is expected, a
plain list is accepted and parsed — this is what makes JSON input work
later.

``` r

Team <- struct("Team",
  lead    = User,
  members = list_of(User),
  roster  = frame(id = int, name = chr)
)

bob  <- User(id = 2, name = "Bob", email = "bob@example.org", friend = ada)
team <- Team(lead = ada, members = list(bob),
             roster = data.frame(id = c(1, 2), name = c("Ada", "Bob")))
team
#> <Team>
#>   lead    : <User>
#>   members : <list of 1>
#>   roster  : <data.frame 2 x 2>
team$members[[1]]$friend$name
#> [1] "Ada"
```

Three mistakes at three depths, one error:

``` r

Team(
  lead    = list(id = 1, name = "Ada", email = "ada.lovelace"),
  members = list(list(id = 2, name = "Bob", email = "b@b", age = 34.5)),
  roster  = data.frame(id = c(1, 2.5), name = c("a", "b"))
)
#> Error:
#> ! 3 validation problems in Team
#>   $lead$email        expected chr[1][grepl("@", ., fixed = TRUE)], got chr[1] "ada.lovelace"
#>   $members[[1]]$age  expected int[1] | NULL, got num[1] 34.5  -- not a whole number
#>   $roster$id         expected int, got num[2]  -- not a whole number
```

Errors are machine-readable: a condition of class `typed_error` whose
`$problems` is a list of `path` / `expected` / `got` / `hint` records,
so tooling can consume it, not just people.

``` r

tryCatch(User(id = "x", name = 1), typed_error = function(e)
  data.frame(
    path     = vapply(e$problems, `[[`, "", "path"),
    expected = vapply(e$problems, `[[`, "", "expected"),
    got      = vapply(e$problems, `[[`, "", "got")
  ))
#>     path                            expected        got
#> 1    $id                       int[1][. > 0] chr[1] "x"
#> 2  $name                              chr[1]   num[1] 1
#> 3 $email chr[1][grepl("@", ., fixed = TRUE)]  <missing>
```

When wrong input is expected rather than exceptional — a web form, an
upload — use
[`try_parse()`](https://davzim.github.io/rdantic/reference/try_parse.md),
which returns the same records instead of throwing:

``` r

r <- try_parse(User, list(id = 1.5, name = "Ada", email = "nope"))  # (T, x): validate, don't throw
r$ok
#> [1] FALSE
str(r$problems[[2]])
#> List of 4
#>  $ path    : chr "$email"
#>  $ expected: chr "chr[1][grepl(\"@\", ., fixed = TRUE)]"
#>  $ got     : chr "chr[1] \"nope\""
#>  $ hint    : NULL
is_valid(User, list(id = 1, name = "Ada", email = "a@b"))            # (T, x): TRUE/FALSE, no detail
#> [1] TRUE
```

## Inheritance, partials, unknown fields

``` r

Admin <- extend(User, "Admin", permissions = list_of(chr[1]))  # (Base, "Name", extra field = type, ...)
root  <- Admin(id = 1, name = "root", email = "root@example.org",
               permissions = list("all"))
inherits(root, "User")
#> [1] TRUE
ada$friend <- root                       # an Admin is a User

UserPatch <- partial(User)               # every field optional, defaults dropped
UserPatch(name = "Grace")
#> <PartialUser>
#>   id     : NULL
#>   name   : "Grace"
#>   email  : NULL
#>   age    : NULL
#>   role   : NULL
#>   tags   : NULL
#>   friend : NULL
```

When parsing from a list, unknown keys are ignored by default (as in
pydantic, and so that JSON written from a subclass still parses as the
parent). A struct can forbid them:

``` r

Strict <- struct("Strict", x = int[1], .extra = "forbid")
from_list(Strict, list(x = 1, y = 2))     # from_list(T, x): parse/validate a plain list as T
#> Error:
#> ! 1 validation problem in Strict
#>   $y  expected <no such field>, got num[1] 2  -- did you mean `x`?
```

[`frame()`](https://davzim.github.io/rdantic/reference/frame.md) has the
same `.extra`, enforced the same way whether the rows arrive as a
data.frame already or as JSON that gets reshaped into one:

``` r

Rows <- frame(id = int, .extra = "forbid")
Rows(data.frame(id = 1L, extra = 2))
#> Error:
#> ! 1 validation problem in frame(id)
#>   $extra  expected <no such column>, got num[1] 2
from_json(Rows, '[{"id": 1, "extra": 2}]')
#> Error:
#> ! 1 validation problem in frame(id)
#>   $extra  expected <no such column>, got <present in JSON>
```

## Typed functions: `fn()`

Types sit where R would put defaults; an unnamed formula `~ T` declares
the return type; the last unnamed expression is the body. Defaults use
`%default%`; arguments whose type accepts `NULL` may be omitted.

``` r

greet <- fn(name = chr[1], greeting = chr[1] %default% "Hello", ~ chr[1], {
  paste0(greeting, ", ", name, "!")
})
greet
#> <fn> (name: chr[1], greeting: chr[1] = "Hello") -> chr[1]
greet("Ada")
#> [1] "Hello, Ada!"
greet("Ada", "Bonjour")
#> [1] "Bonjour, Ada!"
greet(c("Ada", "Bob"))
#> Error:
#> ! 1 validation problem in greet()
#>   name  expected chr[1], got chr[2]  -- length is 2, not 1
```

The return value is checked as well — a typed function cannot leak a
wrong result, and an explicit
[`return()`](https://rdrr.io/r/base/function.html) is checked exactly
like a value that falls through:

``` r

half <- fn(x = int[1], ~ int[1], { x / 2 })
half(4)                                  # 2 is a whole double: coerces to 2L
#> [1] 2
half(3)                                  # 1.5 is not an int
#> Error:
#> ! 1 validation problem in half()
#>   <return>  expected int[1], got num[1] 1.5  -- not a whole number

early <- fn(x = int[1], ~ int[1], { if (x < 0) return("negative"); x })
early(-1)                                # return()'s value is checked too
#> Error:
#> ! 1 validation problem in early()
#>   <return>  expected int[1], got chr[1] "negative"  -- strings are never parsed implicitly
```

An argument name that collides with rdantic’s own internals (like
`.probs_`) is rejected when the function is declared, rather than
silently shadowed:

``` r

fn(.probs_ = int[1], ~ int[1], { .probs_ })
#> Error:
#> ! argument name `.probs_` is reserved for rdantic's internals; choose a different name
```

Give `...` a type to check everything passed through it. Every bad
argument is reported in one error, as with structs:

``` r

log_line <- fn(level = one_of("info", "warn"), ... = chr[1], ~ chr[1], {
  paste0("[", level, "] ", paste(..., collapse = " "))
})
log_line("info", "disk", "full")
#> [1] "[info] disk full"
log_line("debug", "disk", 3)
#> Error:
#> ! 2 validation problems in log_line()
#>   level  expected one_of("info", "warn"), got chr[1] "debug"
#>   ..2    expected chr[1], got num[1] 3
```

Checks are compiled once, when the function is defined, and cost tens of
microseconds per call — nothing at an API boundary, noticeable in a
tight loop. Turn them off globally when you no longer want to pay for
them:

``` r

options(rdantic.check = FALSE)
half(3)
#> [1] 1.5
options(rdantic.check = TRUE)
```

## Composing typed functions

Since a type is just a value plus a predicate, a *function* type needs
no new machinery:

``` r

pricing_rule <- anything[inherits(., "typed_fn")]
Money        <- num[1][. >= 0]
```

`rule_for()` **returns** a typed function; `invoice()` **takes** one.
Three typed functions, stacked:

``` r

rule_for <- fn(kind = one_of("standard", "bulk", "clearance"), ~ pricing_rule, {
  switch(kind,
    standard  = fn(o = Order, ~ Money, { o$qty * o$unit_price }),
    bulk      = fn(o = Order, ~ Money, { o$qty * o$unit_price * 0.9 }),
    clearance = fn(o = Order, ~ Money, { o$qty * o$unit_price - 500 })
  )
})

invoice <- fn(o = Order, rule = pricing_rule, ~ Money, {
  round(rule(o), 2)
})

invoice(order, rule_for("bulk"))
#> [1] 53.97
```

The `clearance` rule is well-typed on the way in and wrong on the way
out. Nothing catches it until the arithmetic has already run:

``` r

invoice(order, rule_for("clearance"))
#> Error:
#> ! 1 validation problem in rule()
#>   <return>  expected num[1][. >= 0], got num[1] -440.03
```

The report names the frame that produced the bad value (`rule()`, the
innermost of the three) and the stage (`<return>`), not the outer call
the user made. Compare the other three places the same pipeline can
break — each one is caught as early as it possibly can be:

``` r

rule_for("half off")                     # (1) argument, at the door
#> Error:
#> ! 1 validation problem in rule_for()
#>   kind  expected one_of("standard", "bulk", "clearance"), got chr[1] "half off"
invoice(order, function(o) 0)            # (2) argument: a function, but not a typed one
#> Error:
#> ! 1 validation problem in invoice()
#>   rule  expected anything[inherits(., "typed_fn")], got function[1]
invoice(payload, rule_for("bulk"))       # (2) argument: raw list, parsed then rejected
#> Error:
#> ! 2 validation problems in invoice()
#>   o$id      expected int[1][. > 0], got chr[1] "1042"  -- strings are never parsed implicitly
#>   o$coupon  expected num[1][0 <= . & . <= 1], got num[1] 1.2
```

And a factory that forgets to return a function is caught by its own
return type, before anyone can call the result:

``` r

broken_for <- fn(kind = chr[1], ~ pricing_rule, { toupper(kind) })
broken_for("bulk")
#> Error:
#> ! 1 validation problem in broken_for()
#>   <return>  expected anything[inherits(., "typed_fn")], got chr[1] "BULK"
```

## JSON and schema

[`to_json()`](https://davzim.github.io/rdantic/reference/to_json.md) is
type-aware: a field declared `[1]` becomes a JSON scalar, any other
vector becomes an array, even when it has one element.

``` r

grace <- User(id = 3, name = "Grace", email = "grace@navy.mil", tags = "cobol")
to_json(grace)
#> {
#>   "id": 3,
#>   "name": "Grace",
#>   "email": "grace@navy.mil",
#>   "age": null,
#>   "role": "user",
#>   "tags": ["cobol"],
#>   "friend": null
#> }
```

[`from_json()`](https://davzim.github.io/rdantic/reference/from_json.md)
parses and validates in one step. JSON arrays come back as R vectors and
arrays of objects as data frames, because the types accept those shapes
— there is no separate JSON mode.

``` r

team2 <- from_json(Team, to_json(team))
str(team2$roster)
#> 'data.frame':    2 obs. of  2 variables:
#>  $ id  : int  1 2
#>  $ name: chr  "Ada" "Bob"
from_json(User, '{"id": 1.5, "name": ["a", "b"], "email": "x@y"}')
#> Error:
#> ! 2 validation problems in User
#>   $id    expected int[1][. > 0], got num[1] 1.5  -- not a whole number
#>   $name  expected chr[1], got list[2]  -- length is 2, not 1
```

And a JSON Schema for interoperating with anything else that speaks
types:

``` r

to_json(schema(User))
#> {
#>   "type": "object",
#>   "title": "User",
#>   "properties": {
#>     "id": {
#>       "type": "integer",
#>       "description": "satisfies . > 0"
#>     },
#>     "name": {
#>       "type": "string"
#>     },
#>     "email": {
#>       "type": "string",
#>       "description": "satisfies grepl(\"@\", ., fixed = TRUE)"
#>     },
#>     "age": {
#>       "type": ["integer", "null"]
#>     },
#>     "role": {
#>       "enum": [
#>         "admin",
#>         "user"
#>       ]
#>     },
#>     "tags": {
#>       "type": "array",
#>       "items": {
#>         "type": "string"
#>       }
#>     },
#>     "friend": {
#>       "anyOf": [
#>         {
#>           "$ref": "#/$defs/User"
#>         },
#>         {
#>           "type": "null"
#>         }
#>       ]
#>     }
#>   },
#>   "required": [
#>     "id",
#>     "name",
#>     "email"
#>   ],
#>   "additionalProperties": false
#> }
```

What [`schema()`](https://davzim.github.io/rdantic/reference/schema.md)
declares always matches what
[`to_json()`](https://davzim.github.io/rdantic/reference/to_json.md)
actually writes: a
[`frame()`](https://davzim.github.io/rdantic/reference/frame.md)
column’s schema describes one row’s scalar cell, not the whole column’s
vector shape, and
[`map_of()`](https://davzim.github.io/rdantic/reference/map_of.md)’s
schema is an object, matching the JSON object it serializes to.

``` r

Cell <- struct("Cell", rows = frame(id = int), tags = map_of(chr[1]))
c(schema(Cell)$properties$rows$items$properties$id$type,
  schema(Cell)$properties$tags$type)
#> [1] "integer" "object"
to_json(Cell(rows = data.frame(id = 1L), tags = list(a = "x")), pretty = FALSE)
#> {"rows":[{"id":1}],"tags":{"a":"x"}}
```

## Documenting a schema

A description belongs in the schema itself, not beside it in a comment
that can drift out of sync — this is what a structured-output model
actually reads. There are two places to attach one:
[`desc()`](https://davzim.github.io/rdantic/reference/desc.md) (or its
infix spelling `%doc%`) documents a single field’s type, and
`struct(.description = )` documents the record as a whole.

``` r

Contact <- struct("Contact",
  .description = "A single contact record.",
  name  = chr[1] %doc% "Full name of the person.",  # T %doc% "text": attach a description
  email = opt(chr[1]) %doc% "Email address, or null if unknown."
)

to_json(schema(Contact))
#> {
#>   "type": "object",
#>   "title": "Contact",
#>   "description": "A single contact record.",
#>   "properties": {
#>     "name": {
#>       "type": "string",
#>       "description": "Full name of the person."
#>     },
#>     "email": {
#>       "type": ["string", "null"],
#>       "description": "Email address, or null if unknown."
#>     }
#>   },
#>   "required": [
#>     "name"
#>   ],
#>   "additionalProperties": false
#> }
```

[`desc()`](https://davzim.github.io/rdantic/reference/desc.md)/`%doc%`
wraps a type, so — like `%default%` — it must be the outermost part of
the chain, applied after `[n]`, `[expr]`,
[`opt()`](https://davzim.github.io/rdantic/reference/opt.md)/`|` and
`%default%`:

``` r

age <- int[1][. > 0] %doc% "Age in years, must be positive."
schema(age)
#> $type
#> [1] "integer"
#> 
#> $description
#> [1] "Age in years, must be positive."
```

## Cheat sheet

| Want | Write |
|----|----|
| integer / double / string / logical vector | `int`, `num`, `chr`, `lgl` |
| exactly n elements | `T[n]` |
| constraint | `T[. > 0]`, `chr[1][nchar(.) < 20]` |
| optional | `T \| NULL`, `opt(T)`, `opt("StructName")` |
| either | `A \| B` |
| enum | `one_of("a", "b")` |
| date / time / factor | `date`, `datetime`, `fct("a", "b")` |
| no missing values | `no_na(T)` |
| custom type | `type_from("name", predicate, coerce)` |
| list of | `list_of(T)` |
| map (arbitrary keys) | `map_of(T)` |
| named list with fixed keys | `list_of(a = T, b = T)` |
| data.frame with typed columns | `frame(col = T, ...)` |
| a function value | `anything[is.function(.)]`, `anything[inherits(., "typed_fn")]` |
| default | `T %default% value` |
| record | `struct("Name", f = T, ...)` |
| field / struct description | `T %doc% "text"`, `struct(..., .description = "text")` |
| forward / self reference | `ref("Name")`, `opt("Name")` |
| subclass, partial | `extend(M, "Sub", ...)`, `partial(M)` |
| reject unknown keys | `struct(..., .extra = "forbid")`, `frame(..., .extra = "forbid")` |
| typed function | `fn(a = T, ..., ~ Ret, { body })` |
| typed `...` | `fn(a = T, ... = T, ~ Ret, { body })` |
| validate anything | `T(x)`, `parse_as(T, x)`, `from_list(M, x)` |
| validate without throwing | `try_parse(T, x)`, `is_valid(T, x)` |
| fields of a struct or value | `fields(M)`, `fields(x)` |
| no coercion / no checks | `options(rdantic.strict = TRUE)`, `options(rdantic.check = FALSE)` |
| JSON | `to_json(x)`, `from_json(T, txt)`, `schema(T)` |
| catch errors | `tryCatch(..., typed_error = function(e) e$problems)` |

## How it works

- **Types are closures** carrying a `spec` attribute (`name`,
  `validate`, `schema`). `[.type` captures its argument with
  [`substitute()`](https://rdrr.io/r/base/substitute.html) — a bare
  number is a length, an expression mentioning `.` is a predicate.
  `Ops.type` implements `|`. That is the whole DSL; there is no parser.
- **Structs compile to constructors** with real formals, built with
  `formals<-` and [`bquote()`](https://rdrr.io/r/base/bquote.html).
  Instances are **plain lists** carrying their own `spec`, so they copy
  on modify like every other R value and
  [`identical()`](https://rdrr.io/r/base/identical.html),
  [`saveRDS()`](https://rdrr.io/r/base/readRDS.html) and
  [`str()`](https://rdrr.io/r/utils/str.html) behave; `$<-` dispatches
  to a method that validates and returns the updated value.
- **Validators return the value itself**, or a `typed_problems` list of
  records. The happy path allocates nothing beyond the value, and
  `rdantic.strict` is read once per top-level validation rather than
  once per element.
- **[`fn()`](https://davzim.github.io/rdantic/reference/fn.md) rewrites
  the function**: types come off the formals, one check block is
  prepended, the return is wrapped. R 4.4 reserved
  [`declare()`](https://rdrr.io/r/base/declare.html) for exactly this
  kind of annotation; when it gains semantics,
  [`fn()`](https://davzim.github.io/rdantic/reference/fn.md) can emit it
  and the checks move into the interpreter without user code changing.
- **Coercion is lossless only**: whole doubles → int (never out of
  range), int → double, factor → character, ISO-8601 text → date. While
  parsing JSON, also: unnamed list of scalars → vector, list of records
  → data frame. Nothing else, ever.

## Not in this proof of concept

- Discriminated unions for polymorphic JSON (`{"type": "admin", ...}`
  choosing the struct).
- Generic structs (`Page(of = User)`).
- Cross-field validators (`.check = function(self) ...`) and row-wise
  constraints in
  [`frame()`](https://davzim.github.io/rdantic/reference/frame.md)
  beyond predicates over a column.
- Packaging all of this as an actual R package, with a namespace instead
  of [`source()`](https://rdrr.io/r/base/source.html).
