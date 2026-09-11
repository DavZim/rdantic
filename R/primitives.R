#' Is a value an unclassed atomic vector?
#'
#' A primitive never accepts a classed atomic: a `Date` is not a `num` and a
#' factor is not an `int`, even though both are exactly that underneath.
#'
#' @param x Any R value.
#' @return `TRUE` when `x` carries no class attribute.
#' @keywords internal
#' @examples
#' rdantic:::.plain(1:3)
#' rdantic:::.plain(Sys.Date())
.plain <- function(x) is.null(oldClass(x))

#' Build a primitive vector type
#'
#' @param name The type name (`"int"`, `"num"`, ...).
#' @param test `function(x)` recognising the R type.
#' @param coerce Optional `function(x)` returning a lossless conversion, or
#'   `NULL` when none is possible.
#' @param json The JSON Schema type name.
#' @param empty The zero-length vector of this type, used when a JSON `[]`
#'   arrives.
#' @return A type.
#' @keywords internal
#' @examples
#' raw_t <- rdantic:::.atomic("raw", is.raw, NULL, "string", raw())
#' raw_t(as.raw(1:3))
.atomic <- function(name, test, coerce = NULL, json = name, empty)
  new_type(
    name,
    validate = function(x, path) {
      if (is.null(oldClass(x)) && test(x)) return(x) # nothing to look up
      strict <- if (is.null(.ctx$strict))
        isTRUE(getOption("rdantic.strict", FALSE)) else .ctx$strict
      # lax, and only while parsing: an unnamed list of scalars (how jsonlite
      # parses a JSON array) is a vector
      if (
        !strict &&
          .ctx$parsing &&
          is.list(x) &&
          !is.data.frame(x) &&
          !inherits(x, "typed_instance") &&
          is.null(names(x))
      ) {
        if (!length(x)) x <- empty else {
          x[vapply(x, is.null, NA)] <- NA
          if (all(lengths(x) == 1) && all(vapply(x, is.atomic, NA)))
            x <- unlist(x)
        }
        if (is.null(oldClass(x)) && test(x)) return(x)
      }
      coerced <- if (!is.null(coerce)) coerce(x)
      if (!strict && !is.null(coerced)) return(coerced)
      .bad(
        path,
        name,
        .got(x),
        if (strict && !is.null(coerced))
          "rdantic.strict = TRUE, so no coercion was attempted" else
          .coerce_hint(name, x)
      )
    },
    schema = function() list(type = "array", items = list(type = json)),
    empty = empty
  )

#' Explain why a value could not be coerced
#'
#' @param name The primitive type's name.
#' @param x The value that failed.
#' @return A one-line hint, or `NULL`.
#' @keywords internal
#' @examples
#' rdantic:::.coerce_hint("int", 1.5)
#' rdantic:::.coerce_hint("int", 1e10)
#' rdantic:::.coerce_hint("num", "7")
.coerce_hint <- function(name, x) {
  if (name %in% c("int", "num") && is.character(x))
    return("strings are never parsed implicitly")
  if (name == "int" && is.double(x) && .plain(x)) {
    if (any(abs(x) > .Machine$integer.max, na.rm = TRUE))
      return("outside integer range; use num")
    return("not a whole number")
  }
  if (name == "lgl" && is.numeric(x)) return("0/1 is not TRUE/FALSE")
  if (!.plain(x) && is.atomic(x))
    return(paste0("a <", class(x)[1], "> is never silently unclassed"))
  NULL
}

#' Primitive vector types
#'
#' The four atomic vector types, plus `anything` and the null type. Each is an
#' ordinary value: call it to validate, subset it with `[` to fix a length or
#' add a constraint, combine it with `|`.
#'
#' Coercion is lossless only. A whole double becomes an integer and an integer
#' becomes a double; `1.5` never becomes `1L`, `"1"` never becomes `1`, and a
#' classed atomic such as a `Date` is never quietly unclassed. Set
#' `options(rdantic.strict = TRUE)` to switch coercion off entirely.
#'
#' @format Objects of class `type`.
#' @param x The value to validate.
#' @name primitives
#' @seealso [date], [fct()], [type_from()]
#' @examples
#' int(c(1, 2, 3))   # whole doubles become integers
#' num(2L)           # integers become doubles
#' chr(factor("a"))  # factors become characters
#' lgl(c(TRUE, NA))
#' anything(list(1, "a"))
#'
#' try(int(1.5))     # lossy
#' try(int("3"))     # strings are never parsed
#' try(int(1e10))    # outside integer range
#'
#' int[1]            # exactly one integer
#' num[. > 0]        # positive doubles
NULL

#' @rdname primitives
#' @export
int <- .atomic(
  "int",
  is.integer,
  function(x)
    if (
      .plain(x) &&
        is.double(x) &&
        all(x == trunc(x) & abs(x) <= .Machine$integer.max, na.rm = TRUE)
    )
      as.integer(x),
  "integer",
  integer()
)

#' @rdname primitives
#' @export
num <- .atomic(
  "num",
  is.double,
  function(x) if (.plain(x) && is.integer(x)) as.double(x),
  "number",
  double()
)

#' @rdname primitives
#' @export
chr <- .atomic(
  "chr",
  is.character,
  function(x) if (is.factor(x)) as.character(x),
  "string",
  character()
)

#' @rdname primitives
#' @export
lgl <- .atomic("lgl", is.logical, NULL, "boolean", logical())

#' @rdname primitives
#' @export
anything <- new_type("anything", function(x, path) x)

#' @rdname primitives
#' @export
null_t <- new_type(
  "NULL",
  function(x, path) if (is.null(x)) NULL else .bad(path, "NULL", .got(x)),
  function() list(type = "null")
)
