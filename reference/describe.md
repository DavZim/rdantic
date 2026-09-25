# Describe a struct and its fields

Adds JSON Schema descriptions after a struct has been declared. This is
useful when descriptions are long enough that keeping them beside each
type would obscure the structure. The returned struct replaces the
registered definition of the same name, so assign the result back to the
original name.

## Usage

``` r
describe(x, ..., . = NULL)
```

## Arguments

- x:

  A struct.

- ...:

  Field descriptions, named for fields in `x`.

- .:

  The struct description. When omitted, the existing description is
  preserved.

## Value

A new struct definition carrying the descriptions.

## Details

Multiline descriptions are dedented: blank first and last lines and the
indentation shared by every nonblank line are removed. This makes R raw
strings convenient for long prose.

## Examples

``` r
User <- struct("DescribedUser", id = int[1], name = chr[1]) |>
  describe(
    . = r"(
      A user returned by the accounts API.
    )",
    id = "Stable user identifier.",
    name = "Full display name."
  )
schema(User)
#> $type
#> [1] "object"
#> 
#> $title
#> [1] "DescribedUser"
#> 
#> $description
#> [1] "A user returned by the accounts API."
#> 
#> $properties
#> $properties$id
#> $properties$id$type
#> [1] "integer"
#> 
#> $properties$id$description
#> [1] "Stable user identifier."
#> 
#> 
#> $properties$name
#> $properties$name$type
#> [1] "string"
#> 
#> $properties$name$description
#> [1] "Full display name."
#> 
#> 
#> 
#> $required
#> $required[[1]]
#> [1] "id"
#> 
#> $required[[2]]
#> [1] "name"
#> 
#> 
#> $additionalProperties
#> [1] FALSE
#> 
```
