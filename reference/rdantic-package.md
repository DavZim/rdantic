# rdantic: declared types, checked at the boundary

A proof-of-concept port of pydantic's central idea to R: declare what a
value is, once, and have it checked where it enters your code, with
coercion only where nothing can be lost and a complete report where it
cannot.

## Details

Types are ordinary values built from operators R already has:

- [primitives](https://davzim.github.io/rdantic/reference/primitives.md)
  – `int`, `num`, `chr`, `lgl`, `anything`

- [datetimes](https://davzim.github.io/rdantic/reference/datetimes.md)
  and [`fct()`](https://davzim.github.io/rdantic/reference/fct.md) –
  `date`, `datetime`, factors

- `T[n]` and `T[. > 0]` – length and constraints, see \[`[.type`\]

- `A | B`, [`opt()`](https://davzim.github.io/rdantic/reference/opt.md),
  [`no_na()`](https://davzim.github.io/rdantic/reference/no_na.md),
  [`one_of()`](https://davzim.github.io/rdantic/reference/one_of.md),
  `%default%`

- [`list_of()`](https://davzim.github.io/rdantic/reference/list_of.md),
  [`map_of()`](https://davzim.github.io/rdantic/reference/map_of.md) and
  [`frame()`](https://davzim.github.io/rdantic/reference/frame.md) –
  lists, maps and data frames

- [`struct()`](https://davzim.github.io/rdantic/reference/struct.md),
  [`extend()`](https://davzim.github.io/rdantic/reference/extend.md),
  [`partial()`](https://davzim.github.io/rdantic/reference/partial.md) –
  records

- [`fn()`](https://davzim.github.io/rdantic/reference/fn.md) – typed
  functions

- [`parse_as()`](https://davzim.github.io/rdantic/reference/parse_as.md),
  [`try_parse()`](https://davzim.github.io/rdantic/reference/try_parse.md),
  [`from_json()`](https://davzim.github.io/rdantic/reference/from_json.md),
  [`to_json()`](https://davzim.github.io/rdantic/reference/to_json.md),
  [`schema()`](https://davzim.github.io/rdantic/reference/schema.md)

## Options

`rdantic.strict` switches coercion off, so a value must already be the
right R type. `rdantic.check` set to `FALSE` skips the checks in
[`fn()`](https://davzim.github.io/rdantic/reference/fn.md).

## Author

**Maintainer**: David Zimmermann-Kollenda
<david_j_zimmermann@hotmail.com>

Authors:

- David Zimmermann-Kollenda <david_j_zimmermann@hotmail.com>

## Examples

``` r
Order <- struct("Order",
  id         = int[1][. > 0],
  qty        = int[1][. > 0],
  unit_price = num[1][. >= 0],
  coupon     = num[1][0 <= . & . <= 1] %default% 0
)

Order(id = 1042, qty = 3, unit_price = 19.99)
#> <Order>
#>   id         : 1042L
#>   qty        : 3L
#>   unit_price : 19.99
#>   coupon     : 0
try(Order(id = "1042", qty = 3, unit_price = 19.99, coupon = 1.2))
#> Error : 2 validation problems in Order
#>   $id      expected int[1][. > 0], got chr[1] "1042"  -- strings are never parsed implicitly
#>   $coupon  expected num[1][0 <= . & . <= 1], got num[1] 1.2

net <- fn(o = Order, ~ num[1][. >= 0], {
  o$qty * o$unit_price * (1 - o$coupon)
})
net(Order(id = 1, qty = 3, unit_price = 19.99))
#> [1] 59.97
```
