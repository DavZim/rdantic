# Structs: modeling records

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

A struct is a set of named, typed fields.
[`struct()`](https://davzim.github.io/rdantic/reference/struct.md)
returns a constructor, and that constructor is itself a type – so
structs nest inside other structs, functions and containers, and can
appear anywhere a type is expected. This vignette assumes the basics
from
[`vignette("types-in-depth")`](https://davzim.github.io/rdantic/articles/types-in-depth.md).

## Defining and constructing

``` r

User <- struct("User",
  id     = int[1][. > 0],
  name   = chr[1],
  email  = chr[1][grepl("@", ., fixed = TRUE)],
  age    = int[1] | NULL,
  role   = one_of("admin", "user") %default% "user",
  tags   = chr %default% character()
)
User
#> <struct> User
#>   id    : int[1][. > 0]
#>   name  : chr[1]
#>   email : chr[1][grepl("@", ., fixed = TRUE)]
#>   age   : int[1] | NULL
#>   role  : one_of("admin", "user") = "user"
#>   tags  : chr = character(0)
```

Construct one like any R function – the constructor has real formals, so
autocomplete works in an IDE:

``` r

ada <- User(id = 1, name = "Ada", email = "ada@lovelace.org")
ada
#> <User>
#>   id    : 1L
#>   name  : "Ada"
#>   email : "ada@lovelace.org"
#>   age   : NULL
#>   role  : "user"
#>   tags  : character(0)
str(ada$id)                              # coerced to integer on the way in
#>  int 1
```

A field is required unless it has a `%default%` or its type accepts
`NULL`. Every problem in a bad call is reported at once, not just the
first:

``` r

User(name = 42, email = "nope", role = "god")
#> Error:
#> ! 4 validation problems in User
#>   $id     expected int[1][. > 0], got <missing>
#>   $name   expected chr[1], got num[1] 42
#>   $email  expected chr[1][grepl("@", ., fixed = TRUE)], got chr[1] "nope"
#>   $role   expected one_of("admin", "user"), got chr[1] "god"
```

## Instances stay valid

Fields are validated on assignment as well as construction, and a struct
is sealed: a typo cannot quietly invent a new field, or quietly read a
different one. `$<-`, `[[<-` and `[<-` all run the same check, so there
is no assignment form that skips it:

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
#>   fields: id, name, email, age, role, tags
```

Instances are otherwise plain lists (with a class), so they behave like
every other R value: copy on modify, no action at a distance.

``` r

copy <- ada
copy$name <- "Grace"
c(ada$name, copy$name)
#> [1] "Ada"   "Grace"
```

A field name that collides with rdantic’s own internal bookkeeping (like
`.args`) is rejected when the struct is declared, rather than silently
shadowed:

``` r

struct("Broken", .args = int[1])
#> Error:
#> ! field name `.args` is reserved for rdantic's internals; choose a different name
```

## Nesting

Where a struct is expected, a plain list is accepted and parsed into it
– this is what lets JSON input work later (see
[`vignette("json-and-schemas")`](https://davzim.github.io/rdantic/articles/json-and-schemas.md))
with no separate JSON mode.

``` r

Team <- struct("Team",
  lead    = User,
  members = list_of(User)
)

bob  <- User(id = 2, name = "Bob", email = "bob@example.org")
team <- Team(lead = ada, members = list(bob))
team$members[[1]]$name
#> [1] "Bob"

# three mistakes at three depths, one error
Team(
  lead    = list(id = 1, name = "Ada", email = "ada.lovelace"),
  members = list(list(id = 2, name = "Bob", email = "b@b", age = 34.5))
)
#> Error:
#> ! 2 validation problems in Team
#>   $lead$email        expected chr[1][grepl("@", ., fixed = TRUE)], got chr[1] "ada.lovelace"
#>   $members[[1]]$age  expected int[1] | NULL, got num[1] 34.5  -- not a whole number
```

## Self- and forward-reference

A struct that needs to refer to its own type (or one defined later)
cannot write its own name as a bare symbol – `ref("Name")` resolves the
name lazily, on first use, and caches it; `opt("Name")` is the common
`ref("Name") | NULL` shorthand for an optional link:

``` r

Node <- struct("Node", value = int[1], next_ = opt("Node"))
Node(value = 1, next_ = list(value = 2))
#> <Node>
#>   value : 1L
#>   next_ : <Node>
```

## Inheritance and partials

[`extend()`](https://davzim.github.io/rdantic/reference/extend.md)
subclasses a struct: the child gets the parent’s fields plus its own,
inherits the parent’s class (so it is accepted anywhere the parent is),
and may retype a parent field by repeating its name.

``` r

Animal <- struct("Animal", name = chr[1], legs = int[1] %default% 4L)
Bird   <- extend(Animal, "Bird", can_fly = lgl[1])

tweety <- Bird(name = "Tweety", legs = 2, can_fly = TRUE)
inherits(tweety, "Animal")
#> [1] TRUE

# a child may retype a parent field
fields(extend(Animal, "Centipede", legs = int[1][. > 50]))
#> [1] "name" "legs"
```

[`partial()`](https://davzim.github.io/rdantic/reference/partial.md)
makes every field of a struct optional – for PATCH-shaped input, where
only the supplied keys mean anything. Defaults are dropped along with
requirements, so “not supplied” stays distinguishable from “set to the
default”:

``` r

Post <- struct("Post", title = chr[1], body = chr[1], draft = lgl[1] %default% TRUE)
PostPatch <- partial(Post)

patch <- PostPatch(title = "New title")
patch$title
#> [1] "New title"
patch$draft          # NULL, not the default
#> NULL
```

## Unknown fields

When parsing from a list, unknown keys are ignored by default – as in
pydantic, and so that JSON written from a subclass still parses as the
parent. Pass `.extra = "forbid"` to reject them instead:

``` r

Strict <- struct("Strict", x = int[1], .extra = "forbid")
from_list(Strict, list(x = 1, y = 2))
#> Error:
#> ! 1 validation problem in Strict
#>   $y  expected <no such field>, got num[1] 2  -- did you mean `x`?
```

## Introspection and plain-list conversion

[`fields()`](https://davzim.github.io/rdantic/reference/fields.md) lists
a struct’s (or an instance’s) field names in declaration order.
[`to_list()`](https://davzim.github.io/rdantic/reference/to_list.md)
recursively turns an instance – and any nested instances – back into
plain named lists, e.g. for code that should not know about rdantic:

``` r

fields(User)
#> [1] "id"    "name"  "email" "age"   "role"  "tags"
fields(ada)
#> [1] "id"    "name"  "email" "age"   "role"  "tags"

Pin  <- struct("Pin", lat = num[1], lon = num[1])
Trip <- struct("Trip", from = Pin, to = Pin)
str(to_list(Trip(from = Pin(lat = 1, lon = 2), to = Pin(lat = 3, lon = 4))))
#> List of 2
#>  $ from:List of 2
#>   ..$ lat: num 1
#>   ..$ lon: num 2
#>  $ to  :List of 2
#>   ..$ lat: num 3
#>   ..$ lon: num 4
```

See
[`vignette("json-and-schemas")`](https://davzim.github.io/rdantic/articles/json-and-schemas.md)
for
[`to_json()`](https://davzim.github.io/rdantic/reference/to_json.md)/[`from_json()`](https://davzim.github.io/rdantic/reference/from_json.md)/[`schema()`](https://davzim.github.io/rdantic/reference/schema.md),
and
[`vignette("errors-and-validation")`](https://davzim.github.io/rdantic/articles/errors-and-validation.md)
for reading and handling the errors a struct raises.
