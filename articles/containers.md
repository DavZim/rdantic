# Containers: lists, maps and frames

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

R has three shapes for “more than one of something”, and rdantic has one
container type for each:
[`list_of()`](https://davzim.github.io/rdantic/reference/list_of.md) for
an array,
[`map_of()`](https://davzim.github.io/rdantic/reference/map_of.md) for
arbitrary-key/one-value-type maps, and
[`frame()`](https://davzim.github.io/rdantic/reference/frame.md) for a
data.frame with typed columns.
[`list_of()`](https://davzim.github.io/rdantic/reference/list_of.md)
also has a second form for a fixed key set. This vignette covers when to
reach for which; see
[`vignette("structs")`](https://davzim.github.io/rdantic/articles/structs.md)
for when a record deserves a name and a class instead.

## `list_of(T)`: an array of one type

`list_of(T)` accepts an unnamed list of any length, all elements of type
`T`. A named list is rejected – that is
[`map_of()`](https://davzim.github.io/rdantic/reference/map_of.md)’s
job, so the two never overlap.

``` r

tags <- list_of(chr[1])
tags(list("a", "b"))
#> [[1]]
#> [1] "a"
#> 
#> [[2]]
#> [1] "b"
tags(list(a = "x"))              # a named list is map_of(), not this
#> Error:
#> ! 1 validation problem in list_of(chr[1])
#>   <value>  expected list_of(chr[1]), got list[1]  -- a named list is map_of(), not list_of()
```

## `map_of(T)`: arbitrary keys, one value type

`map_of(T)` is the map counterpart: any keys, one value type, kept by
name. A failure is reported by key rather than by position – and this is
what a JSON object with arbitrary keys parses into (see
[`vignette("json-and-schemas")`](https://davzim.github.io/rdantic/articles/json-and-schemas.md)).

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
map_of(int[1])(list(1, 2))       # unnamed input is list_of(), not this
#> Error:
#> ! 1 validation problem in map_of(int[1])
#>   <value>  expected map_of(int[1]), got list[2]  -- every key must be named

schema(budget)
#> $type
#> [1] "object"
#> 
#> $additionalProperties
#> $additionalProperties$type
#> [1] "integer"
#> 
#> $additionalProperties$description
#> [1] "satisfies . > 0"
```

## `list_of(a = T, b = T, ...)`: a fixed key set

Name the arguments of
[`list_of()`](https://davzim.github.io/rdantic/reference/list_of.md)
instead of giving it one type, and it becomes a third shape: a fixed set
of keys with one rule per key – still a plain named list on the way out,
with no class and no struct name.

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
limits(list(cpu = 4))                    # missing key, reported
#> Error:
#> ! 1 validation problem in list_of(cpu, memory)
#>   $memory  expected int[1][0 < . & . < 128], got <missing>
```

Missing keys are reported, `%default%` fills them in, and
`.extra = "forbid"` refuses unknown ones – the same record rules
[`struct()`](https://davzim.github.io/rdantic/reference/struct.md) uses:

``` r

list_of(cpu = int[1], .extra = "forbid")(list(cpu = 1, junk = 2))
#> Error:
#> ! 1 validation problem in list_of(cpu)
#>   $junk  expected <no such field>, got num[1] 2
```

Reach for a struct
([`vignette("structs")`](https://davzim.github.io/rdantic/articles/structs.md))
when the record deserves a name, a class and inheritance; reach for
`list_of(a = T, ...)` when it is just a shape.

## `frame()`: a data.frame with typed columns

[`frame()`](https://davzim.github.io/rdantic/reference/frame.md)
describes a data.frame: each column is validated as a vector, so the
usual length and constraint syntax applies to it. A column of the wrong
length for the number of rows, or a missing column, is an error.

``` r

roster <- frame(id = int, name = chr)
str(roster(data.frame(id = c(1, 2), name = c("Ada", "Bob"))))
#> 'data.frame':    2 obs. of  2 variables:
#>  $ id  : int  1 2
#>  $ name: chr  "Ada" "Bob"

roster(data.frame(id = 1))               # missing column
#> Error:
#> ! 1 validation problem in frame(id, name)
#>   $name  expected chr, got <missing column>
frame(id = int, .extra = "forbid")(data.frame(id = 1L, junk = 2))
#> Error:
#> ! 1 validation problem in frame(id)
#>   $junk  expected <no such column>, got num[1] 2
```

While parsing JSON, an array of objects is reshaped into a data frame,
and a row missing a key is reported by name instead of quietly producing
a list column:

``` r

from_json(roster, '[{"id": 1, "name": "Ada"}, {"id": 2, "name": "Bob"}]')
#>   id name
#> 1  1  Ada
#> 2  2  Bob
from_json(roster, '[{"id": 1}]')
#> Error:
#> ! 1 validation problem in frame(id, name)
#>   $name  expected chr, got <missing in row 1>
nrow(from_json(roster, "[]"))
#> [1] 0
```

## Picking one

| Shape of the data | Use |
|----|----|
| unnamed, any length, one element type | `list_of(T)` |
| named, arbitrary keys, one value type | `map_of(T)` |
| named, fixed keys, one rule each, no class needed | `list_of(a = T, b = T, ...)` |
| rows and columns | `frame(col = T, ...)` |
| a record that deserves a name, a class, inheritance | `struct("Name", field = T, ...)` |
