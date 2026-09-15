# Attach a description to a type's schema

The description is what
[`schema()`](https://davzim.github.io/rdantic/reference/schema.md) puts
under the JSON Schema `"description"` key – the pydantic-style docstring
for a field. It must be the outermost wrapper in a chain (applied after
`[n]`, `[expr]`,
[`opt()`](https://davzim.github.io/rdantic/reference/opt.md)/ `|` and
`%default%`), the same implicit rule `%default%` already has, because an
outer combinator builds its own schema fragment and would otherwise
discard it. A description added this way replaces, rather than
duplicates, one
[`.refined()`](https://davzim.github.io/rdantic/reference/dot-refined.md)
wrote automatically.

## Usage

``` r
desc(t, description)

t %doc% description
```

## Arguments

- t:

  A type, or anything
  [`as_type()`](https://davzim.github.io/rdantic/reference/as_type.md)
  accepts.

- description:

  A single string.

## Value

A type carrying the description.

## Details

A struct's own top-level description is set with
`struct(.description = )` instead: `desc()` on a whole struct builds a
new, unregistered constructor, so a
[`ref()`](https://davzim.github.io/rdantic/reference/ref.md) to that
struct's name would still see the undescribed one.

## Examples

``` r
age <- int[1][. > 0] %doc% "Age in years."
schema(age)$description
#> [1] "Age in years."

Person <- struct("Person",
  name = chr[1] %doc% "Full name of the person.",
  occupation = opt(chr[1]) %doc% "Current job title, or null if unknown."
)
schema(Person)$properties$occupation
#> $type
#> [1] "string" "null"  
#> 
#> $description
#> [1] "Current job title, or null if unknown."
#> 
```
