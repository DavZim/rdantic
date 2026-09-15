# Data frame type

A data frame with typed columns. Each column is validated as a vector,
so the usual length and constraint syntax applies to it; a column that
comes back the wrong length for the number of rows is an error, as is a
missing column.

## Usage

``` r
frame(..., .extra = c("ignore", "forbid"))
```

## Arguments

- ...:

  Named columns, one type each.

- .extra:

  `"ignore"` (default) or `"forbid"`, for columns that were not
  declared.

## Value

A type.

## Details

While parsing JSON, an array of objects is reshaped into a data frame –
and a row that is missing a key is reported by name instead of quietly
producing a list column.

## See also

[`list_of()`](https://davzim.github.io/rdantic/reference/list_of.md)

## Examples

``` r
roster <- frame(id = int, name = chr)
str(roster(data.frame(id = c(1, 2), name = c("Ada", "Bob"))))
#> 'data.frame':    2 obs. of  2 variables:
#>  $ id  : int  1 2
#>  $ name: chr  "Ada" "Bob"

try(roster(data.frame(id = 1)))
#> Error : 1 validation problem in frame(id, name)
#>   $name  expected chr, got <missing column>
try(frame(id = int, .extra = "forbid")(data.frame(id = 1L, junk = 2)))
#> Error : 1 validation problem in frame(id)
#>   $junk  expected <no such column>, got num[1] 2

from_json(roster, '[{"id": 1, "name": "Ada"}, {"id": 2, "name": "Bob"}]')
#>   id name
#> 1  1  Ada
#> 2  2  Bob
try(from_json(roster, '[{"id": 1}]'))
#> Error : 1 validation problem in frame(id, name)
#>   $name  expected chr, got <missing in row 1>
nrow(from_json(roster, "[]"))
#> [1] 0
```
