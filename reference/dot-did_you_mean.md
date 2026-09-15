# Suggest the name the user probably meant

Suggest the name the user probably meant

## Usage

``` r
.did_you_mean(name, candidates)
```

## Arguments

- name:

  The name that was not found.

- candidates:

  The names that exist.

## Value

A hint string, or `NULL` when nothing is close enough.

## Examples

``` r
rdantic:::.did_you_mean("nmae", c("name", "id"))
#> [1] "did you mean `name`?"
rdantic:::.did_you_mean("zzz", c("name", "id"))
#> NULL
```
