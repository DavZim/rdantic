# Map types

The map counterpart of `list_of(T)`: arbitrary keys, one value type,
kept by name – and what a JSON object with arbitrary keys parses into. A
failure is reported by key rather than by position.

## Usage

``` r
map_of(t)
```

## Arguments

- t:

  The value type.

## Value

A type.

## Details

Reach for `list_of(a = T, b = T)` instead when the key set is fixed and
known up front.

## See also

[`list_of()`](https://davzim.github.io/rdantic/reference/list_of.md) for
an array, or a fixed key set.

## Examples

``` r
budget <- map_of(int[1][. > 0])
budget(list(cpu = 4, memory = 16))
#> $cpu
#> [1] 4
#> 
#> $memory
#> [1] 16
#> 
try(budget(list(cpu = 4, memory = 0)))
#> Error : 1 validation problem in map_of(int[1][. > 0])
#>   $memory  expected int[1][. > 0], got num[1] 0
try(map_of(int[1])(list(1, 2)))         # unnamed input is list_of(), not this
#> Error : 1 validation problem in map_of(int[1])
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
#> 
#> 
from_json(map_of(int[1]), '{"cpu": 4, "memory": 16}')
#> $cpu
#> [1] 4
#> 
#> $memory
#> [1] 16
#> 
```
