# Dates and temporal types

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

R has three quiet failure modes this vignette’s types guard against: a
`Date` is a number wearing a class, a factor is an integer wearing
labels, and a plain string is neither until something parses it. rdantic
gives each of these its own type instead of letting them silently
interoperate with plain numbers and strings.

## Dates and datetimes

`date` accepts `Date` vectors, `datetime` accepts `POSIXct` vectors.
Unlike plain numbers, ISO-8601 text *is* parsed – it is the one
unambiguous serialization of an instant – but never silently to `NA`:
text that does not parse is an error, not a missing value.

``` r

date("2024-05-17")                        # ISO-8601 is unambiguous, so it is parsed
#> [1] "2024-05-17"
date(as.Date("2024-05-17"))
#> [1] "2024-05-17"
datetime("2024-05-17T09:30:00")
#> [1] "2024-05-17 09:30:00 UTC"

date("17/05/2024")                        # wrong layout, not a silent NA
#> Error:
#> ! 1 validation problem in date
#>   <value>  expected date, got chr[1] "17/05/2024"  -- expected YYYY-MM-DD
date(19860)                               # a number is not a date
#> Error:
#> ! 1 validation problem in date
#>   <value>  expected date, got num[1] 19860  -- wrap it explicitly: as.Date()
num(Sys.Date())                           # ... and a date is never silently a number
#> Error:
#> ! 1 validation problem in num
#>   <value>  expected num, got date[1] "2026-09-16"  -- a <Date> is never silently unclassed
```

Like any other type, a date can carry a length or be used inside a union
or a container:

``` r

date[1]                                   # exactly one date
#> <type> date[1]
parse_as(date, c("2024-01-01", "2024-06-30"))
#> [1] "2024-01-01" "2024-06-30"
```

## Restricted factors

`fct(a, b, ...)` accepts a factor with exactly those levels, and
promotes character input whose values are all among them. Use
[`one_of()`](https://davzim.github.io/rdantic/reference/one_of.md)
([`vignette("types-in-depth")`](https://davzim.github.io/rdantic/articles/types-in-depth.md))
when a plain string should come out; use
[`fct()`](https://davzim.github.io/rdantic/reference/fct.md) when a
factor with a fixed, ordered level set should.

``` r

size <- fct("low", "mid", "high")
size("mid")                               # character, promoted to a factor
#> [1] mid
#> Levels: low mid high
levels(size(c("high", "low")))
#> [1] "low"  "mid"  "high"
size("enormous")                          # not one of the declared levels
#> Error:
#> ! 1 validation problem in fct("low", "mid", "high")
#>   <value>  expected fct("low", "mid", "high"), got chr[1] "enormous"  -- levels are low, mid, high

fct()(factor("anything"))                 # fct() with no levels: any factor, no coercion
#> [1] anything
#> Levels: anything
```

## Missing values

`NA` sails through most R operators without complaint. `no_na(T)` wraps
any type to additionally reject it – see
[`vignette("types-in-depth")`](https://davzim.github.io/rdantic/articles/types-in-depth.md)
for [`no_na()`](https://davzim.github.io/rdantic/reference/no_na.md)
alongside the other combinators.

``` r

no_na(date)(as.Date(c("2024-01-01", NA)))
#> Error:
#> ! 1 validation problem in no_na(date)
#>   <value>  expected no_na(date), got date[2]  -- contains NA
```
