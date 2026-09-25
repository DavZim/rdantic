# Typed functions

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

[`fn()`](https://davzim.github.io/rdantic/reference/fn.md) declares a
function whose arguments and return value are both checked. Types sit
where R would put defaults; an unnamed formula `~ T` declares the return
type; the last unnamed expression is the body.

## Basics

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
greet(c("Ada", "Bob"))          # a vector where one value was meant
#> Error:
#> ! 1 validation problem in greet()
#>   name  expected chr[1], got chr[2]  -- length is 2, not 1
```

`%default%` supplies a value used when an argument is omitted, exactly
as it does for a struct field
([`vignette("structs")`](https://davzim.github.io/rdantic/articles/structs.md));
an argument whose type accepts `NULL` may also be omitted.

## The return value is checked too

A typed function cannot leak a wrong result. An explicit
[`return()`](https://rdrr.io/r/base/function.html) goes through exactly
the same check as a value that falls through at the end of the body:

``` r

half <- fn(x = int[1], ~ int[1], { x / 2 })
half(4)                                  # 2 is a whole double: coerces to 2L
#> [1] 2
half(3)                                  # 1.5 is not an int
#> Error:
#> ! 1 validation problem in half()
#>   <return>  expected int[1], got num[1] 1.5  -- not a whole number

early <- fn(x = int[1], ~ int[1], { if (x < 0) return("negative"); x })
early(-1)                                # return()'s value is checked too
#> Error:
#> ! 1 validation problem in early()
#>   <return>  expected int[1], got chr[1] "negative"  -- strings are never parsed implicitly
```

## Reserved names and typed `...`

An argument name that collides with rdantic’s own internal bookkeeping
(like `.probs_`) is rejected when the function is declared, rather than
silently shadowed:

``` r

fn(.probs_ = int[1], ~ int[1], { .probs_ })
#> Error:
#> ! argument name `.probs_` is reserved for rdantic's internals; choose a different name
```

Give `...` a type to check every value passed through it. Values passed
via `...` are checked but not coerced (`...` cannot be rebound), and
every bad argument is reported in one error, as with a struct:

``` r

log_line <- fn(level = one_of("info", "warn"), ... = chr[1], ~ chr[1], {
  paste0("[", level, "] ", paste(..., collapse = " "))
})
log_line("info", "disk", "full")
#> [1] "[info] disk full"
log_line("debug", "disk", 3)
#> Error:
#> ! 2 validation problems in log_line()
#>   level  expected one_of("info", "warn"), got chr[1] "debug"
#>   ..2    expected chr[1], got num[1] 3
```

## Turning checks off

Checks are compiled once, when the function is defined, and cost tens of
microseconds per call – nothing at an API boundary, but possibly
noticeable in a tight inner loop. Turn them off globally when that cost
matters more than the safety:

``` r

options(rdantic.check = FALSE)
half(3)                                  # no longer checked
#> [1] 1.5
options(rdantic.check = TRUE)
```

## Composing typed functions

`typed_fn` accepts any function created by
[`fn()`](https://davzim.github.io/rdantic/reference/fn.md). More often,
higher-order code needs a particular signature:
`fn_type(o = Order, ~ Money)` accepts only a typed function with that
declared argument and return type.

``` r

Order <- struct("Order",
  id         = int[1][. > 0],
  qty        = int[1][. > 0],
  unit_price = num[1][. >= 0],
  coupon     = num[1][0 <= . & . <= 1] %default% 0
)
order <- Order(id = 1042, qty = 3, unit_price = 19.99)

Money        <- num[1][. >= 0]
pricing_rule <- fn_type(o = Order, ~ Money)
```

`rule_for()` **returns** a typed function; `invoice()` **takes** one.
Three typed functions, stacked:

``` r

rule_for <- fn(kind = one_of("standard", "bulk", "clearance"), ~ pricing_rule, {
  switch(kind,
    standard  = fn(o = Order, ~ Money, { o$qty * o$unit_price }),
    bulk      = fn(o = Order, ~ Money, { o$qty * o$unit_price * 0.9 }),
    clearance = fn(o = Order, ~ Money, { o$qty * o$unit_price - 500 })
  )
})

invoice <- fn(o = Order, rule = pricing_rule, ~ Money, {
  round(rule(o), 2)
})

invoice(order, rule_for("bulk"))
#> [1] 53.97
```

Signature checks include argument names and defaults. They compare
declarations rather than calling the function, so no user code runs
during validation. Use the broader `typed_fn` type when any declared
signature is acceptable.

The `clearance` rule is well-typed on the way in and wrong on the way
out (a negative total). Nothing catches it until the arithmetic has
already run:

``` r

invoice(order, rule_for("clearance"))
#> Error:
#> ! 1 validation problem in rule()
#>   <return>  expected num[1][. >= 0], got num[1] -440.03
```

The report names the frame that produced the bad value (`rule()`, the
innermost of the three) and the stage (`<return>`), not the outer call
the user made. Compare the other places the same pipeline can break –
each is caught as early as it possibly can be:

``` r

rule_for("half off")                     # (1) argument, at the door
#> Error:
#> ! 1 validation problem in rule_for()
#>   kind  expected one_of("standard", "bulk", "clearance"), got chr[1] "half off"
invoice(order, function(o) 0)            # (2) argument: a function, but not a typed one
#> Error:
#> ! 1 validation problem in invoice()
#>   rule  expected <fn> (o: Order) -> num[1][. >= 0], got function[1]
```

And a factory that forgets to return a function is caught by its own
return type, before anyone can call the result:

``` r

broken_for <- fn(kind = chr[1], ~ pricing_rule, { toupper(kind) })
broken_for("bulk")
#> Error:
#> ! 1 validation problem in broken_for()
#>   <return>  expected <fn> (o: Order) -> num[1][. >= 0], got chr[1] "BULK"
```
