# Use an S7 class as a type

The class becomes an ordinary rdantic type: it can be a struct field, an
argument of [`fn()`](https://davzim.github.io/rdantic/reference/fn.md),
the element type of
[`list_of()`](https://davzim.github.io/rdantic/reference/list_of.md),
and it parses a plain list – so
[`from_json()`](https://davzim.github.io/rdantic/reference/from_json.md)
builds real S7 objects, property by property, with every problem
reported under its path.

## Usage

``` r
s7_type(cls)
```

## Arguments

- cls:

  An S7 class, as returned by
  [`S7::new_class()`](https://rconsortium.github.io/S7/reference/new_class.html).

## Value

A type.

## Details

Property classes are translated where they carry over (`class_integer`,
`class_double`, `class_character`, `class_logical`, `class_list`,
`class_Date`, `class_POSIXct`, unconstrained `class_data.frame` values,
unions, and nested S7 classes); anything else validates as
[anything](https://davzim.github.io/rdantic/reference/primitives.md). A
property is required unless it declares a `default`. Expression-valued
defaults remain S7's responsibility and are evaluated for each instance.
Computed properties (a getter without a setter) are not input fields.

[`as_type()`](https://davzim.github.io/rdantic/reference/as_type.md)
calls this for you, so an S7 class can be written directly wherever a
type is expected.

## See also

[`as_s7_class()`](https://davzim.github.io/rdantic/reference/as_s7_class.md)
for the other direction.

## Examples

``` r
if (requireNamespace("S7", quietly = TRUE)) {
  library(S7)   # for `@`, which S7 supplies on R < 4.3

  Pin <- new_class("Pin", properties = list(
    lat = class_double,
    lon = class_double
  ))

  s7_type(Pin)
  schema(Pin)

  # an S7 class used as a struct field
  Trip <- struct("Trip", label = chr[1], start = Pin)
  t <- from_json(Trip, '{"label": "home", "start": {"lat": 1, "lon": 2}}')
  t$start

  try(from_list(Trip, list(label = "home", start = list(lat = "x", lon = 2))))
}
#> Error : 1 validation problem in Trip
#>   $start$lat  expected num, got chr[1] "x"  -- strings are never parsed implicitly
```
