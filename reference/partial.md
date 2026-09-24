# Make every field of a struct optional

For PATCH-shaped input, where only the supplied keys mean anything.
Defaults are dropped as well as requirements, so "not supplied" stays
distinguishable from "set to the default".

## Usage

``` r
partial(.parent, .name = paste0("Partial", .spec(as_type(.parent))$name))
```

## Arguments

- .parent:

  The struct to weaken, or an S7 class.

- .name:

  The new struct's name.

## Value

A constructor of class `typed_struct`.

## See also

[`struct()`](https://davzim.github.io/rdantic/reference/struct.md),
[`extend()`](https://davzim.github.io/rdantic/reference/extend.md)

## Examples

``` r
Post <- struct("Post", title = chr[1], body = chr[1], draft = lgl[1] %default% TRUE)
PostPatch <- partial(Post)
PostPatch
#> <struct> PartialPost
#>   title : chr[1] | NULL
#>   body  : chr[1] | NULL
#>   draft : lgl[1] | NULL

patch <- PostPatch(title = "New title")
patch$title
#> [1] "New title"
patch$draft          # NULL, not the default
#> NULL
```
