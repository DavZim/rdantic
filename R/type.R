#' Create a type
#'
#' A type is a closure that validates a value and an attached `spec` describing
#' it. Calling the type validates and returns the value; everything else in
#' rdantic is built by composing types.
#'
#' @param name The type's name, used in error messages and in `print()`.
#' @param validate `function(x, path)` returning the (possibly coerced) value,
#'   or the result of [.bad()]/[.fail()].
#' @param schema `function()` returning the JSON Schema fragment for the type.
#' @param ... Extra entries stored in the spec, such as `scalar`, `empty`,
#'   `default`, `elt` or `members`.
#' @return An object of class `type`.
#' @export
#' @examples
#' even <- new_type(
#'   "even",
#'   validate = function(x, path) {
#'     if (is.numeric(x) && all(x %% 2 == 0)) x else rdantic:::.bad(path, "even", type_of(x))
#'   },
#'   schema = function() list(type = "integer", multipleOf = 2)
#' )
#' even(c(2, 4))
#' try(even(3))
#' schema(even)
new_type <- function(name, validate, schema = function() list(), ...) {
  spec <- c(list(name = name, validate = validate, schema = schema), list(...))
  self <- function(x) {
    r <- .entry(spec$validate(x, ""))
    if (.is_bad(r)) .abort(r, spec$name)
    r
  }
  attr(self, "spec") <- spec
  class(self) <- "type"
  self
}

#' Get a type's spec
#'
#' @param t A type.
#' @return The spec list: `name`, `validate`, `schema`, plus any extras.
#' @keywords internal
#' @examples
#' names(rdantic:::.spec(int))
.spec <- function(t) attr(t, "spec")

#' Rebuild a type from a modified spec
#'
#' @param spec A spec list, usually one that came out of [.spec()] with an
#'   entry added or removed.
#' @return A type (or a model constructor, if the spec has fields).
#' @keywords internal
#' @examples
#' s <- rdantic:::.spec(int)
#' s$name <- "whole_number"
#' rdantic:::.rebuild(s)
.rebuild <- function(spec)
  if (!is.null(spec$fields)) .make_model(spec) else do.call(new_type, spec)

#' Interpret a value as a type
#'
#' Types are values, so most of the API accepts either a type, `NULL` (meaning
#' the null type) or a string (meaning a model looked up by name).
#'
#' @param x A type, `NULL`, or a model name.
#' @return A type.
#' @export
#' @examples
#' as_type(int)
#' as_type(NULL)
#' as_type("User")
as_type <- function(x) {
  if (inherits(x, "type")) return(x)
  if (is.null(x)) return(null_t)
  if (is.character(x) && length(x) == 1) return(ref(x))
  stop("not a type: ", deparse1(substitute(x)))
}

#' Print a type
#'
#' @param x A type.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
#' @examples
#' print(int[1])
#' print(one_of("a", "b") %default% "a")
print.type <- function(x, ...) {
  s <- .spec(x)
  cat(
    "<type> ",
    s$name,
    if (isTRUE(s$has_default)) paste0("  (default: ", deparse1(s$default), ")"),
    "\n",
    sep = ""
  )
  invisible(x)
}

#' Validate a value against a type
#'
#' The same thing as calling the type, but usable when the type arrives in a
#' variable. Coercion happens only where nothing can be lost.
#'
#' @param t A type, or anything [as_type()] accepts.
#' @param x The value to validate.
#' @return The validated value, possibly coerced.
#' @export
#' @examples
#' parse_as(int, c(1, 2, 3))
#' parse_as(list_of(int[1]), list(1, 2))
#' try(parse_as(int[1], "3"))
parse_as <- function(t, x) {
  t <- as_type(t)
  r <- .entry(.spec(t)$validate(x, ""))
  if (.is_bad(r)) .abort(r, .spec(t)$name)
  r
}

#' Validate without throwing
#'
#' For input that is expected to be wrong sometimes -- a web form, an upload,
#' a config file -- where you want to collect the problems rather than abort.
#'
#' @param t A type, or anything [as_type()] accepts.
#' @param x The value to validate.
#' @return A list with `ok`, `value` and `problems` (a list of
#'   `{path, expected, got, hint}` records).
#' @export
#' @examples
#' try_parse(int[1], 1)
#' r <- try_parse(int[1], "x")
#' r$ok
#' r$problems[[1]]$hint
try_parse <- function(t, x) {
  tryCatch(
    {
      t <- as_type(t)
      r <- .entry(.spec(t)$validate(x, ""))
      if (.is_bad(r)) list(ok = FALSE, value = NULL, problems = unclass(r)) else
        list(ok = TRUE, value = r, problems = list())
    },
    typed_error = function(e)
      list(ok = FALSE, value = NULL, problems = e$problems)
  )
}

#' Does a value satisfy a type?
#'
#' @param t A type, or anything [as_type()] accepts.
#' @param x The value to test.
#' @return `TRUE` or `FALSE`.
#' @export
#' @examples
#' is_valid(int[1], 3)
#' is_valid(int[1], 3.5)
#' is_valid(chr, letters)
is_valid <- function(t, x) isTRUE(try_parse(t, x)$ok)

#' JSON Schema for a type
#'
#' @param t A type, or anything [as_type()] accepts.
#' @return A list matching the JSON Schema shape; pass it to [to_json()].
#' @export
#' @examples
#' schema(int[1])
#' schema(one_of("a", "b"))
#' schema(list_of(cpu = int[1]))
schema <- function(t) .spec(as_type(t))$schema()

#' Build a type from a predicate
#'
#' The escape hatch for anything the built-in types do not cover, without
#' touching rdantic's internal problem format.
#'
#' @param name The type's name, shown in errors.
#' @param test `function(x)` returning `TRUE` when `x` is acceptable.
#' @param coerce Optional `function(x)` returning a converted value, tried only
#'   when `test` fails and `rdantic.strict` is off.
#' @param json The JSON Schema type name.
#' @param scalar Whether a length-1 value should serialise as a JSON scalar
#'   rather than a one-element array.
#' @return A type.
#' @export
#' @examples
#' hex <- type_from("hex", function(x) is.character(x) && all(grepl("^#[0-9a-f]{6}$", x)))
#' hex("#00ff99")
#' try(hex("green"))
#'
#' port <- type_from(
#'   "port",
#'   function(x) is.integer(x) && length(x) == 1 && x > 0 && x < 65536,
#'   coerce = function(x) as.integer(x),
#'   json = "integer",
#'   scalar = TRUE
#' )
#' port(8080)
type_from <- function(
  name,
  test,
  coerce = NULL,
  json = "string",
  scalar = FALSE
) {
  force(test)
  new_type(
    name,
    validate = function(x, path) {
      if (isTRUE(test(x))) return(x)
      if (!.strict() && !is.null(coerce)) {
        y <- tryCatch(coerce(x), error = function(e) NULL)
        if (!is.null(y) && isTRUE(test(y))) return(y)
      }
      .bad(path, name, .got(x))
    },
    schema = function() list(type = json),
    scalar = scalar
  )
}
