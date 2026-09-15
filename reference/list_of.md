# List types

`list_of(T)` is an array of any length whose elements are all `T`; only
an unnamed list is accepted – reach for
[`map_of()`](https://davzim.github.io/rdantic/reference/map_of.md) for a
named, arbitrary-key shape.

## Usage

``` r
list_of(..., .extra = c("ignore", "forbid"))
```

## Arguments

- ...:

  One element type, or named keys with one type each.

- .extra:

  `"ignore"` (default) or `"forbid"`, for keys that were not declared.
  Only meaningful for the keyed form.

## Value

A type.

## Details

`list_of(a = T, b = T)` is a different thing again: a fixed key set with
one rule per key, still a plain named list on the way out. Missing keys
are reported, `%default%` fills them in, and `.extra = "forbid"` refuses
unknown ones. Reach for
[`struct()`](https://davzim.github.io/rdantic/reference/struct.md) when
the record deserves a name, a class and inheritance.

## See also

[`map_of()`](https://davzim.github.io/rdantic/reference/map_of.md) for
an arbitrary-key map,
[`frame()`](https://davzim.github.io/rdantic/reference/frame.md) for a
data frame,
[`struct()`](https://davzim.github.io/rdantic/reference/struct.md) for a
named record.

## Examples

``` r
# an array of any length, one element type
tags <- list_of(chr[1])
tags(list("a", "b"))
#> [[1]]
#> [1] "a"
#> 
#> [[2]]
#> [1] "b"
#> 
try(tags(list(a = "x")))                # a named list is map_of(), not this
#> Error : 1 validation problem in list_of(chr[1])
#>   <value>  expected list_of(chr[1]), got list[1]  -- a named list is map_of(), not list_of()

# a fixed key set, one rule per key
limits <- list_of(cpu = int[1][0 < . & . < 12], memory = int[1][0 < . & . < 128])
limits
#> <type> list_of(cpu, memory)
str(limits(list(cpu = 4, memory = 16)))
#> List of 2
#>  $ cpu   : int 4
#>  $ memory: int 16
try(limits(list(cpu = 16, memory = 512)))
#> Error : 2 validation problems in list_of(cpu, memory)
#>   $cpu     expected int[1][0 < . & . < 12], got num[1] 16
#>   $memory  expected int[1][0 < . & . < 128], got num[1] 512
try(limits(list(cpu = 4)))
#> Error : 1 validation problem in list_of(cpu, memory)
#>   $memory  expected int[1][0 < . & . < 128], got <missing>

list_of(cpu = int[1], .extra = "forbid")
#> <type> list_of(cpu)
schema(limits)
#> $type
#> [1] "object"
#> 
#> $properties
#> $properties$cpu
#> $properties$cpu$type
#> [1] "integer"
#> 
#> $properties$cpu$description
#> [1] "satisfies 0 < . & . < 12"
#> 
#> 
#> $properties$memory
#> $properties$memory$type
#> [1] "integer"
#> 
#> $properties$memory$description
#> [1] "satisfies 0 < . & . < 128"
#> 
#> 
#> 
#> $required
#> $required[[1]]
#> [1] "cpu"
#> 
#> $required[[2]]
#> [1] "memory"
#> 
#> 
#> $additionalProperties
#> [1] TRUE
#> 
```
