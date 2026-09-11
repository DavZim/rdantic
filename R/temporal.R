#' Build a date or time type
#'
#' @param name The type name.
#' @param cls The R class that is accepted as-is.
#' @param parse `function(x)` parsing character input.
#' @param shape The accepted text layout, shown as a hint.
#' @param json The JSON Schema `format` value.
#' @param empty The zero-length value of this type.
#' @return A type.
#' @keywords internal
#' @examples
#' rdantic:::.temporal(
#'   "ymd", "Date", function(x) as.Date(x, "%Y-%m-%d"),
#'   "YYYY-MM-DD", "date", as.Date(character())
#' )("2024-05-17")
.temporal <- function(name, cls, parse, shape, json, empty)
  new_type(
    name,
    validate = function(x, path) {
      if (inherits(x, cls)) return(x)
      strict <- .strict()
      if (
        !strict &&
          .ctx$parsing &&
          is.list(x) &&
          !is.data.frame(x) &&
          is.null(names(x)) &&
          length(x) &&
          all(lengths(x) == 1)
      )
        x <- unlist(x)
      # ISO-8601 text is the only unambiguous serialisation of an instant, so
      # unlike numbers it is parsed -- but never silently to NA
      if (!strict && is.character(x)) {
        y <- suppressWarnings(parse(x))
        if (!any(is.na(y) & !is.na(x))) return(y)
        return(.bad(path, name, .got(x), paste("expected", shape)))
      }
      .bad(
        path,
        name,
        .got(x),
        if (is.numeric(x)) paste0("wrap it explicitly: as.", cls[1], "()")
      )
    },
    schema = function()
      list(type = "array", items = list(type = "string", format = json)),
    empty = empty
  )

#' Date and time types
#'
#' `date` accepts `Date` vectors, `datetime` accepts `POSIXct` vectors. Unlike
#' numbers, ISO-8601 text *is* parsed, because it is the one unambiguous
#' serialisation of an instant -- but never silently to `NA`: text that does
#' not parse is an error.
#'
#' @format Objects of class `type`.
#' @param x The value to validate.
#' @name datetimes
#' @seealso [primitives], [fct()]
#' @examples
#' date("2024-05-17")
#' date(as.Date("2024-05-17"))
#' datetime("2024-05-17T09:30:00")
#'
#' try(date("17/05/2024"))        # wrong layout, not a silent NA
#' try(date(19860))               # a number is not a date
#' try(num(Sys.Date()))           # ... and a date is not a number
#'
#' date[1]                        # exactly one date
#' parse_as(date, c("2024-01-01", "2024-06-30"))
NULL

#' @rdname datetimes
#' @export
date <- .temporal(
  "date",
  "Date",
  function(x) as.Date(x, format = "%Y-%m-%d"),
  "YYYY-MM-DD",
  "date",
  as.Date(character())
)

#' @rdname datetimes
#' @export
datetime <- .temporal(
  "datetime",
  "POSIXct",
  function(x) {
    y <- as.POSIXct(x, tz = "UTC", format = "%Y-%m-%dT%H:%M:%OS")
    miss <- is.na(y) & !is.na(x)
    if (any(miss))
      y[miss] <- as.POSIXct(x[miss], tz = "UTC", format = "%Y-%m-%d %H:%M:%OS")
    y
  },
  "YYYY-MM-DDThh:mm:ss",
  "date-time",
  as.POSIXct(character(), tz = "UTC")
)

#' Factor type
#'
#' `fct(a, b, ...)` accepts a factor with exactly those levels, and promotes
#' character input whose values are all among them. `fct()` with no arguments
#' accepts any factor and never coerces.
#'
#' Use [one_of()] when you want a plain string out, and `fct()` when you want a
#' factor with a fixed, ordered level set.
#'
#' @param ... The levels, in order.
#' @return A type.
#' @export
#' @seealso [one_of()], [primitives]
#' @examples
#' size <- fct("low", "mid", "high")
#' size("mid")
#' levels(size(c("high", "low")))
#' try(size("enormous"))
#'
#' fct()(factor("anything"))
#' schema(size)
fct <- function(...) {
  levs <- as.character(c(...))
  name <- if (!length(levs)) "fct()" else
    sprintf("fct(%s)", paste(encodeString(levs, quote = '"'), collapse = ", "))
  new_type(
    name,
    validate = function(x, path) {
      if (is.factor(x) && (!length(levs) || identical(levels(x), levs)))
        return(x)
      if (!length(levs)) return(.bad(path, name, .got(x)))
      chx <- if (is.factor(x)) as.character(x) else x
      if (!.strict() && is.character(chx) && all(is.na(chx) | chx %in% levs))
        return(factor(chx, levels = levs))
      .bad(
        path,
        name,
        .got(x),
        if (is.character(chx))
          paste("levels are", paste(levs, collapse = ", "))
      )
    },
    schema = function()
      list(
        type = "array",
        items = if (length(levs)) list(type = "string", enum = as.list(levs)) else
          list(type = "string")
      ),
    empty = if (length(levs)) factor(character(), levels = levs) else factor()
  )
}
