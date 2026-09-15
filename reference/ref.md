# Refer to a struct by name

Lets a struct refer to itself, or to one that is defined later. The name
is resolved on first use and then cached, so redefining a struct in a
live session cannot silently retype the structs that already refer to
it.

## Usage

``` r
ref(name)
```

## Arguments

- name:

  The struct's name.

## Value

A type.

## See also

[`opt()`](https://davzim.github.io/rdantic/reference/opt.md) for the
common `ref(name) | NULL` case.

## Examples

``` r
Node <- struct("Node", value = int[1], next_ = opt("Node"))
Node(value = 1, next_ = list(value = 2))
#> <Node>
#>   value : 1L
#>   next_ : <Node>

try(parse_as(ref("NeverDefined"), list()))
#> Error : unknown struct `NeverDefined`: define it with struct("NeverDefined", ...) before validating
```
