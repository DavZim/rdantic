# Date and time types

`date` accepts `Date` vectors, `datetime` accepts `POSIXct` vectors.
Unlike numbers, ISO-8601 text *is* parsed, because it is the one
unambiguous serialisation of an instant – but never silently to `NA`:
text that does not parse is an error.

## Usage

``` r
date(x)

datetime(x)
```

## Format

Objects of class `type`.

## Arguments

- x:

  The value to validate.

## See also

[primitives](https://davzim.github.io/rdantic/reference/primitives.md),
[`fct()`](https://davzim.github.io/rdantic/reference/fct.md)

## Examples

``` r
date("2024-05-17")
#> [1] "2024-05-17"
date(as.Date("2024-05-17"))
#> [1] "2024-05-17"
datetime("2024-05-17T09:30:00")
#> [1] "2024-05-17 09:30:00 UTC"

try(date("17/05/2024"))        # wrong layout, not a silent NA
#> Error : 1 validation problem in date
#>   <value>  expected date, got chr[1] "17/05/2024"  -- expected YYYY-MM-DD
try(date(19860))               # a number is not a date
#> Error : 1 validation problem in date
#>   <value>  expected date, got num[1] 19860  -- wrap it explicitly: as.Date()
try(num(Sys.Date()))           # ... and a date is not a number
#> Error : 1 validation problem in num
#>   <value>  expected num, got date[1] "2026-09-25"  -- a <Date> is never silently unclassed

date[1]                        # exactly one date
#> <type> date[1]
parse_as(date, c("2024-01-01", "2024-06-30"))
#> [1] "2024-01-01" "2024-06-30"
```
