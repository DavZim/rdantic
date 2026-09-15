# Serialise to JSON, guided by the declared types

A field declared `[1]` becomes a JSON scalar; any other vector becomes
an array, even with one element. That is the difference R's own types
cannot express and JSON needs.

## Usage

``` r
to_json(x, pretty = TRUE, ...)
```

## Arguments

- x:

  An instance, a schema, or any value jsonlite can handle.

- pretty:

  Whether to indent the output.

- ...:

  Passed to
  [`jsonlite::toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html).

## Value

A `json` string.

## See also

[`from_json()`](https://davzim.github.io/rdantic/reference/from_json.md),
[`schema()`](https://davzim.github.io/rdantic/reference/schema.md)

## Examples

``` r
Tagged <- struct("Tagged", id = int[1], tags = chr, seen = date[1] | NULL)
to_json(Tagged(id = 3, tags = "cobol"))
#> {
#>   "id": 3,
#>   "tags": ["cobol"],
#>   "seen": null
#> } 
to_json(Tagged(id = 3, tags = c("a", "b"), seen = as.Date("2024-01-01")))
#> {
#>   "id": 3,
#>   "tags": ["a", "b"],
#>   "seen": "2024-01-01"
#> } 
to_json(schema(Tagged))
#> {
#>   "type": "object",
#>   "title": "Tagged",
#>   "properties": {
#>     "id": {
#>       "type": "integer"
#>     },
#>     "tags": {
#>       "type": "array",
#>       "items": {
#>         "type": "string"
#>       }
#>     },
#>     "seen": {
#>       "anyOf": [
#>         {
#>           "type": "string",
#>           "format": "date"
#>         },
#>         {
#>           "type": "null"
#>         }
#>       ]
#>     }
#>   },
#>   "required": [
#>     "id",
#>     "tags"
#>   ],
#>   "additionalProperties": false
#> } 
```
