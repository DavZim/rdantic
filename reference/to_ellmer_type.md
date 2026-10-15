# Convert an rdantic type or schema to an ellmer type

ellmer requires every property in a JSON Schema object to be listed in
`required`, including properties whose value may be `null`. rdantic
keeps nullable fields optional, so this adapter adds those property
names while leaving the original schema unchanged.

## Usage

``` r
to_ellmer_type(x)
```

## Arguments

- x:

  An rdantic type, or a JSON Schema list returned by
  [`schema()`](https://davzim.github.io/rdantic/reference/schema.md).

## Value

An ellmer type.

## Examples

``` r
if (FALSE) { # \dontrun{
AgeName <- struct(
  "AgeName",
  age = (int[1][. > 0] | NULL),
  name = (chr[1] | NULL)
)
to_ellmer_type(AgeName)
} # }
```
