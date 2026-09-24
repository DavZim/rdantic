# Subclass a struct

The child gets the parent's fields plus its own, inherits the parent's
class – so it is accepted wherever the parent is – and may retype a
parent field by repeating its name.

## Usage

``` r
extend(.parent, ...)
```

## Arguments

- .parent:

  The struct to extend, or an S7 class.

- ...:

  The subclass's name as the single unnamed string, then extra or
  replacement fields.

## Value

A constructor of class `typed_struct`.

## See also

[`struct()`](https://davzim.github.io/rdantic/reference/struct.md),
[`partial()`](https://davzim.github.io/rdantic/reference/partial.md)

## Examples

``` r
Animal <- struct("Animal", name = chr[1], legs = int[1] %default% 4L)
Bird <- extend(Animal, "Bird", can_fly = lgl[1])

tweety <- Bird(name = "Tweety", legs = 2, can_fly = TRUE)
tweety
#> <Bird>
#>   name    : "Tweety"
#>   legs    : 2L
#>   can_fly : TRUE
inherits(tweety, "Animal")
#> [1] TRUE
is_valid(Animal, tweety)
#> [1] TRUE

# a child may retype a parent field
fields(extend(Animal, "Centipede", legs = int[1][. > 50]))
#> [1] "name" "legs"
```
