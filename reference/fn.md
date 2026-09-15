# Define a typed function

Types sit where R would put defaults, an unnamed formula `~ T` declares
the return type, and the last unnamed expression is the body. Arguments
are validated and coerced on the way in; the result is validated on the
way out, so a typed function can neither be called nor return the wrong
thing.

## Usage

``` r
fn(...)
```

## Arguments

- ...:

  Named arguments (`name = type`), an optional `~ type` return
  declaration, and exactly one unnamed expression: the body.

## Value

A function of class `typed_fn`.

## Details

Give `...` a type to check every value passed through it – those are
checked but not coerced, because `...` cannot be rebound. Every bad
argument is reported in one error.

Checks are compiled once, at definition. Set
`options(rdantic.check = FALSE)` to skip them globally when you no
longer want to pay for them.

## See also

[primitives](https://davzim.github.io/rdantic/reference/primitives.md),
and `%default%` for argument defaults.

## Examples

``` r
greet <- fn(name = chr[1], greeting = chr[1] %default% "Hello", ~ chr[1], {
  paste0(greeting, ", ", name, "!")
})
greet
#> <fn> (name: chr[1], greeting: chr[1] = "Hello") -> chr[1]
greet("Ada")
#> [1] "Hello, Ada!"
greet("Ada", "Bonjour")
#> [1] "Bonjour, Ada!"
try(greet(c("Ada", "Bob")))
#> Error : 1 validation problem in greet()
#>   name  expected chr[1], got chr[2]  -- length is 2, not 1

# the return value is checked too
half <- fn(x = int[1], ~ int[1], { x / 2 })
half(4)
#> [1] 2
try(half(3))
#> Error : 1 validation problem in half()
#>   <return>  expected int[1], got num[1] 1.5  -- not a whole number

# a typed `...`, and every problem at once
log_line <- fn(level = one_of("info", "warn"), ... = chr[1], ~ chr[1], {
  paste0("[", level, "] ", paste(..., collapse = " "))
})
log_line("info", "disk", "full")
#> [1] "[info] disk full"
try(log_line("debug", "disk", 3))
#> Error : 2 validation problems in log_line()
#>   level  expected one_of("info", "warn"), got chr[1] "debug"
#>   ..2    expected chr[1], got num[1] 3

# structs are types, so they work here as well
Money <- num[1][. >= 0]
Item <- struct("Item", qty = int[1][. > 0], price = Money)
total <- fn(i = Item, ~ Money, { i$qty * i$price })
total(Item(qty = 3, price = 19.99))
#> [1] 59.97
try(total(list(qty = 0, price = 19.99)))
#> Error : 1 validation problem in total()
#>   i$qty  expected int[1][. > 0], got num[1] 0

old <- options(rdantic.check = FALSE)
half(3)
#> [1] 1.5
options(old)
```
