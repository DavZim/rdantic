# Using rdantic with ellmer

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
library(ellmer)
```

This vignette assumes that `chat` is an ellmer chat object that has
already been created and configured. The examples use the same
structured extraction task in two styles: an ellmer type specification,
and an rdantic declaration converted to an ellmer type.

## The same type, side by side

Suppose a model should return a person’s name and positive age. With
ellmer, the response type is assembled directly from ellmer’s `type_*()`
functions:

``` r

ellmer_type <- type_object(
  age = type_integer(),
  name = type_string()
)

answer_ellmer <- chat$chat_structured(
  "My name is Bob and I'm 30 years old",
  type = ellmer_type
)
answer_ellmer
#> $age
#> [1] 30
#>
#> $name
#> [1] "Bob"
```

The equivalent rdantic declaration keeps the same shape available as an
R type. `[1]` says that each field is a scalar, and `[. > 0]` adds a
validation rule to `age`:

``` r

AgeName <- struct(
  .name = "AgeName",
  .description = "A structure representing a person's age and name",
  age = (int[1][. > 0] | NULL),
  name = (chr[1] | NULL)
)
AgeName
#> <struct> AgeName
#>   age  : int[1][. > 0] | NULL
#>   name : chr[1] | NULL
```

Convert the declaration at the boundary where ellmer needs its type:

``` r

answer_rdantic <- chat$chat_structured(
  "My name is Bob and I'm 30 years old",
  type = to_ellmer_type(AgeName)
)
answer_rdantic
#> $age
#> [1] 30
#>
#> $name
#> [1] "Bob"
```

If we want to check the answer with rdantic, we can do so with
[`from_list()`](https://davzim.github.io/rdantic/reference/from_list.md).

``` r

checked_answer <- from_list(AgeName, answer_rdantic)
checked_answer
#> <AgeName>
#>   age  : 30L
#>   name : "Bob"
```

This is better illustrated with a text that doesnt conform to the age \>
0 requirement.

``` r

answer_invalid <- chat$chat_structured(
  "My name is Alice and I'm -5 years old",
  type = to_ellmer_type(AgeName)
)
answer_invalid
#> $age
#> [1] -5
#>
#> $name
#> [1] "Alice"

from_list(AgeName, answer_invalid)
#> Error: 1 validation problem in AgeName
#>   $age  expected int[1][. > 0] | NULL, got int[1] -5L
```

[`to_ellmer_type()`](https://davzim.github.io/rdantic/reference/to_ellmer_type.md)
is equivalent to the longer form:

``` r

to_ellmer_type(AgeName)
# is equivalent to
AgeName |>
  rdantic::schema() |>
  rdantic::to_json() |>
  ellmer::type_from_schema()
```

And the
[`to_ellmer_type()`](https://davzim.github.io/rdantic/reference/to_ellmer_type.md)
result is identical to the ellmer type that would be constructed
manually using
[`type_from_schema()`](https://ellmer.tidyverse.org/reference/type_boolean.html).

``` r

AgeName <- struct(
  .name = "AgeName",
  .description = "A structure representing a person's age and name",
  age = (int[1][. > 0] | NULL),
  name = (chr[1] | NULL)
)

ellmer_age_name <- ellmer::type_object(
  age = type_integer(),
  name = type_string()
)

all.equal(to_ellmer_type(AgeName), ellmer_age_name)
#> [1] "target is ellmer::TypeJsonSchema, current is ellmer::TypeObject"

# note the ellmer type is different, so we need to do some further cosmetic adjustments
# to actually compare the values

from_rdantic <- to_ellmer_type(AgeName)
from_ellmer <- ellmer_age_name

# Both interfaces expose the same response fields and scalar types.
ellmer_properties <- S7::prop(from_ellmer, "properties")
rdantic_schema <- S7::prop(from_rdantic, "json")

all.equal(names(ellmer_properties), names(rdantic_schema$properties))
#> [1] TRUE
all.equal(
  vapply(ellmer_properties, function(x) S7::prop(x, "type"), character(1)),
  vapply(rdantic_schema$properties, function(x) {
    if (!is.null(x$type)) x$type[[1]] else x$anyOf[[1]]$type
  }, character(1))
)
#> [1] TRUE
```

The adapter also accepts a schema that has already been created:

``` r

age_name_schema <- schema(AgeName)
answer_rdantic <- chat$chat_structured(
  "My name is Bob and I'm 30 years old",
  type = to_ellmer_type(age_name_schema)
)
answer_rdantic
#> $age
#> [1] 30
#>
#> $name
#> [1] "Bob"
```

## Required fields and nullable values

rdantic distinguishes between a field that is required and a field whose
value may be `NULL`. In the declaration above, both fields accept
`NULL`, so an rdantic constructor may omit them. This is useful when
validating ordinary R records, but ellmer’s structured response format
requires every property name to appear in the JSON Schema `required`
array.

[`to_ellmer_type()`](https://davzim.github.io/rdantic/reference/to_ellmer_type.md)
adapts the schema for that boundary: `age` and `name` are both required
response properties, while their schemas still allow `null`. The model
should therefore return both keys, using `null` when a value cannot be
provided.

``` r

rdantic_schema <- schema(AgeName)
rdantic_schema$required
#> list()

ellmer_schema <- S7::prop(to_ellmer_type(AgeName), "json")
ellmer_schema$required
#> [[1]]
#> [1] "age"
#> 
#> [[2]]
#> [1] "name"
ellmer_schema$properties$age$type
#> NULL

# JSON arrays are represented as lists after ellmer parses the schema.
rdantic_schema$required <- as.list(names(rdantic_schema$properties))
rdantic_schema$properties$name$type <- as.list(rdantic_schema$properties$name$type)
all.equal(ellmer_schema, rdantic_schema)
#> [1] TRUE
```

The original rdantic schema is not modified. The stricter `required`
handling is applied only to the schema passed to ellmer.

## Nested records

The same conversion works for nested structs and arrays of structs.
Declare the inner record once, then use it in the outer declaration:

``` r

Address <- struct(
  .name = "Address",
  city = chr[1] | NULL,
  country = chr[1] | NULL
)

Person <- struct(
  .name = "Person",
  name = chr[1] | NULL,
  address = Address | NULL,
  previous_addresses = list_of(Address)
)
```

The nested object schemas are normalized as well, including the object
inside `previous_addresses`:

``` r

converted <- S7::prop(to_ellmer_type(Person), "json")
converted$required
#> [[1]]
#> [1] "name"
#> 
#> [[2]]
#> [1] "address"
#> 
#> [[3]]
#> [1] "previous_addresses"
converted$properties$address$anyOf[[1]]$required
#> [[1]]
#> [1] "city"
#> 
#> [[2]]
#> [1] "country"
converted$properties$previous_addresses$items$required
#> [[1]]
#> [1] "city"
#> 
#> [[2]]
#> [1] "country"
```

Pass the converted type to ellmer exactly as before:

``` r

answer <- chat$chat_structured(
  "Bob lives in Paris and previously lived in Berlin",
  type = to_ellmer_type(Person)
)

#__TODO__
```

## Validate the response in R

The ellmer response is typed for the model call, but the rdantic
declaration can remain the application’s validation boundary. By
default, `chat$chat_structured()` uses `convert = TRUE` and returns an R
list. Validate that list with
[`from_list()`](https://davzim.github.io/rdantic/reference/from_list.md):

``` r

answer <- list(
  name = "Bob",
  address = list(city = "Paris", country = "France"),
  previous_addresses = list(list(city = "Berlin", country = "Germany"))
)

person <- from_list(Person, answer)
person$name
#> [1] "Bob"
person$address$city
#> [1] "Paris"
```

When `convert = FALSE`, ellmer returns the structured response as JSON
text. That form can be validated with
[`from_json()`](https://davzim.github.io/rdantic/reference/from_json.md)
instead:

``` r

reply <- '{
  "name": "Bob",
  "address": {"city": "Paris", "country": "France"},
  "previous_addresses": [{"city": "Berlin", "country": "Germany"}]
}'

person_from_json <- from_json(Person, reply)
person_from_json$name
#> [1] "Bob"
```

This gives one declaration for both sides of the integration:
[`to_ellmer_type()`](https://davzim.github.io/rdantic/reference/to_ellmer_type.md)
produces the response type that ellmer needs, while
[`from_list()`](https://davzim.github.io/rdantic/reference/from_list.md)
or
[`from_json()`](https://davzim.github.io/rdantic/reference/from_json.md)
applies rdantic’s coercion and validation rules after the response
arrives.
