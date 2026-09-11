#' rdantic: declared types, checked at the boundary
#'
#' A proof-of-concept port of pydantic's central idea to R: declare what a value
#' is, once, and have it checked where it enters your code, with coercion only
#' where nothing can be lost and a complete report where it cannot.
#'
#' Types are ordinary values built from operators R already has:
#'
#' * [primitives] -- `int`, `num`, `chr`, `lgl`, `anything`
#' * [datetimes] and [fct()] -- `date`, `datetime`, factors
#' * `T[n]` and `T[. > 0]` -- length and constraints, see [`[.type`]
#' * `A | B`, [opt()], [no_na()], [one_of()], `%default%`
#' * [list_of()] and [frame()] -- lists, maps and data frames
#' * [model()], [extend()], [partial()] -- records
#' * [fn()] -- typed functions
#' * [parse_as()], [try_parse()], [from_json()], [to_json()], [schema()]
#'
#' @section Options:
#' `rdantic.strict` switches coercion off, so a value must already be the right
#' R type. `rdantic.check` set to `FALSE` skips the checks in [fn()].
#'
#' @examples
#' Order <- model("Order",
#'   id         = int[1][. > 0],
#'   qty        = int[1][. > 0],
#'   unit_price = num[1][. >= 0],
#'   coupon     = num[1][0 <= . & . <= 1] %default% 0
#' )
#'
#' Order(id = 1042, qty = 3, unit_price = 19.99)
#' try(Order(id = "1042", qty = 3, unit_price = 19.99, coupon = 1.2))
#'
#' net <- fn(o = Order, ~ num[1][. >= 0], {
#'   o$qty * o$unit_price * (1 - o$coupon)
#' })
#' net(Order(id = 1, qty = 3, unit_price = 19.99))
#' @keywords internal
"_PACKAGE"
