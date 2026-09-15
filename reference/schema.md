# JSON Schema for a type

JSON Schema for a type

## Usage

``` r
schema(t)
```

## Arguments

- t:

  A type, or anything
  [`as_type()`](https://davzim.github.io/rdantic/reference/as_type.md)
  accepts.

## Value

A list matching the JSON Schema shape; pass it to
[`to_json()`](https://davzim.github.io/rdantic/reference/to_json.md).

## Examples

``` r
schema(int[1])
#> $type
#> [1] "integer"
#> 
schema(one_of("a", "b"))
#> $enum
#> $enum[[1]]
#> [1] "a"
#> 
#> $enum[[2]]
#> [1] "b"
#> 
#> 
schema(list_of(cpu = int[1]))
#> $type
#> [1] "object"
#> 
#> $properties
#> $properties$cpu
#> $properties$cpu$type
#> [1] "integer"
#> 
#> 
#> 
#> $required
#> $required[[1]]
#> [1] "cpu"
#> 
#> 
#> $additionalProperties
#> [1] TRUE
#> 
```
