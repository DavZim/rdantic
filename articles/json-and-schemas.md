# JSON and schemas

``` r

library(rdantic)   # jsonlite must also be installed for the JSON helpers
#> 
#> Attaching package: 'rdantic'
#> The following object is masked from 'package:graphics':
#> 
#>     frame
#> The following object is masked from 'package:base':
#> 
#>     date
```

A struct declared once is also a JSON contract:
[`schema()`](https://davzim.github.io/rdantic/reference/schema.md)
builds a JSON Schema fragment from the same declaration that
[`to_json()`](https://davzim.github.io/rdantic/reference/to_json.md) and
[`from_json()`](https://davzim.github.io/rdantic/reference/from_json.md)
use to serialize and validate, so the two can never drift apart. This is
especially useful for talking to a structured-output API: send the
schema as the response format, then run whatever comes back through
[`from_json()`](https://davzim.github.io/rdantic/reference/from_json.md)
before trusting it.

## Serializing

[`to_json()`](https://davzim.github.io/rdantic/reference/to_json.md) is
type-aware: a field declared `[1]` becomes a JSON scalar, any other
vector – even one with a single element – becomes a JSON array.

``` r

User <- struct("User",
  id   = int[1][. > 0],
  name = chr[1],
  role = one_of("admin", "user") %default% "user",
  tags = chr %default% character()
)

grace <- User(id = 3, name = "Grace", tags = "cobol")
to_json(grace)
#> {
#>   "id": 3,
#>   "name": "Grace",
#>   "role": "user",
#>   "tags": ["cobol"]
#> }
```

## Parsing and validating

[`from_json()`](https://davzim.github.io/rdantic/reference/from_json.md)
parses and validates in one step. A JSON array of scalars comes back as
an R vector, and an array of objects becomes a data frame, because the
declared types accept those shapes – there is no separate “JSON mode”.

``` r

from_json(User, '{"id": 1, "name": "Ada"}')
#> <User>
#>   id   : 1L
#>   name : "Ada"
#>   role : "user"
#>   tags : character(0)
from_json(User, '{"id": -1, "name": "Ada"}')   # validated against the same declaration
#> Error:
#> ! 1 validation problem in User
#>   $id  expected int[1][. > 0], got int[1] -1L
from_json(User, '{"id": 1.5, "name": ["a", "b"]}')
#> Error:
#> ! 2 validation problems in User
#>   $id    expected int[1][. > 0], got num[1] 1.5  -- not a whole number
#>   $name  expected chr[1], got list[2]  -- length is 2, not 1
```

Round-tripping a struct through JSON returns an equivalent instance:

``` r

grace2 <- from_json(User, to_json(grace))
identical(grace$name, grace2$name)
#> [1] TRUE
```

## Schemas

[`schema()`](https://davzim.github.io/rdantic/reference/schema.md)
builds a JSON Schema list; pass it to
[`to_json()`](https://davzim.github.io/rdantic/reference/to_json.md) to
serialize it for sending to an API.

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
#>     }
#>   },
#>   "required": [
#>     "id",
#>     "name"
#>   ],
#>   "additionalProperties": false
#> }
```

What [`schema()`](https://davzim.github.io/rdantic/reference/schema.md)
declares always matches what
[`to_json()`](https://davzim.github.io/rdantic/reference/to_json.md)
actually writes. A
[`frame()`](https://davzim.github.io/rdantic/reference/frame.md)
column’s schema describes one row’s scalar cell, not the whole column’s
vector shape, and
[`map_of()`](https://davzim.github.io/rdantic/reference/map_of.md)’s
schema is a JSON object, matching the object it serializes to (see
[`vignette("containers")`](https://davzim.github.io/rdantic/articles/containers.md)
for both):

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
that can drift out of sync – this is what a structured-output model
actually reads. There are two places to attach one:
[`desc()`](https://davzim.github.io/rdantic/reference/desc.md) (or its
infix spelling `%doc%`) documents a single field’s type, and
`struct(.description = )` documents the record as a whole.

``` r

Contact <- struct("Contact",
  .description = "A single contact record.",
  name  = chr[1] %doc% "Full name of the person.",
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
wraps a type, so – like `%default%` – it must be the outermost part of a
chain, applied after `[n]`, `[expr]`,
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

## An end-to-end example

Putting it together: declare the shape once, hand the schema to a model,
and validate whatever it returns.

``` r

Extraction <- struct("Extraction",
  name = chr[1],
  age  = int[1][. > 0],
  tags = list_of(chr[1])
)

to_json(schema(Extraction))   # send this as the response format
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

reply <- '{"name": "Ada", "age": -1, "tags": ["r", "stats"]}'
from_json(Extraction, reply)  # a reply that ignores the schema is still caught
#> Error:
#> ! 1 validation problem in Extraction
#>   $age  expected int[1][. > 0], got int[1] -1L
```
