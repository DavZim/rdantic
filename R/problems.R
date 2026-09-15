#' Report a validation failure
#'
#' A validator returns the (possibly coerced) value on success, or the object
#' built here on failure, so the happy path allocates nothing beyond the value
#' itself. [.is_bad()] tells the two apart.
#'
#' @param problems A list of `{path, expected, got, hint}` records.
#' @return A list of problem records, of class `typed_problems`.
#' @keywords internal
#' @examples
#' p <- rdantic:::.fail(list(list(path = "$x", expected = "int", got = "chr[1]")))
#' rdantic:::.is_bad(p)
.fail <- function(problems) structure(problems, class = "typed_problems")

#' Report a single validation failure
#'
#' @param path Where the bad value sits, e.g. `"$user$id"`. `""` is the value
#'   itself.
#' @param expected Name of the type that was expected.
#' @param got Description of what arrived, usually from [.got()].
#' @param hint Optional one-line explanation of how to fix it.
#' @return A `typed_problems` object holding one record.
#' @keywords internal
#' @examples
#' rdantic:::.bad("$id", "int[1]", "chr[1] \"x\"", "strings are never parsed")
.bad <- function(path, expected, got, hint = NULL)
  .fail(list(list(path = path, expected = expected, got = got, hint = hint)))

#' Is a validator result a failure?
#'
#' @param r The return value of a validator.
#' @return `TRUE` if `r` carries problems rather than a value.
#' @keywords internal
#' @examples
#' rdantic:::.is_bad(1L)
#' rdantic:::.is_bad(rdantic:::.bad("", "int", "chr[1]"))
.is_bad <- function(r) inherits(r, "typed_problems")

#' Rename the expectation of top-level problems
#'
#' A wrapper type such as `int[1]` delegates to `int`, then relabels whatever
#' came back so the message names the composed type, not the inner one.
#'
#' @param r A `typed_problems` object.
#' @param path The path whose records should be relabelled.
#' @param name The type name to put in `expected`.
#' @return A `typed_problems` object.
#' @keywords internal
#' @examples
#' rdantic:::.relabel(rdantic:::.bad("", "int", "num[1] 1.5"), "", "int[1]")
.relabel <- function(r, path, name)
  .fail(lapply(unclass(r), function(p) {
    if (identical(p$path, path)) p$expected <- name
    p
  }))

#' Validation context
#'
#' `strict` caches `getOption("rdantic.strict")` for the duration of one
#' top-level validation instead of re-reading it per value. `parsing` marks
#' input that came from JSON or a plain list, which is the only place where
#' list-shaped input is reshaped into vectors and data frames.
#'
#' @keywords internal
#' @noRd
.ctx <- new.env(parent = emptyenv())
.ctx$strict <- NULL
.ctx$parsing <- FALSE

#' Is coercion switched off?
#'
#' @return `TRUE` when `rdantic.strict` is on, using the cached value if one
#'   top-level validation is already running.
#' @keywords internal
#' @examples
#' rdantic:::.strict()
.strict <- function()
  if (is.null(.ctx$strict)) isTRUE(getOption("rdantic.strict", FALSE)) else
    .ctx$strict

#' Run one top-level validation
#'
#' Establishes the validation context and restores whatever was there before,
#' so nested entries (a struct inside a `from_json()`) keep the outer settings.
#'
#' @param expr The validation to run. Evaluated in the caller's frame.
#' @param parsing Whether the input came from JSON or a plain list.
#' @return The value of `expr`.
#' @keywords internal
#' @examples
#' rdantic:::.entry(rdantic:::.strict())
.entry <- function(expr, parsing = FALSE) {
  old_strict <- .ctx$strict
  old_parsing <- .ctx$parsing
  on.exit({
    .ctx$strict <- old_strict
    .ctx$parsing <- old_parsing
  })
  .ctx$strict <- isTRUE(getOption("rdantic.strict", FALSE))
  .ctx$parsing <- parsing || old_parsing
  expr
}

#' Describe the type of a value the way rdantic names types
#'
#' Length is part of the description, because in R it is part of the type:
#' `int[1]` and `int[3]` are different shapes with different bugs.
#'
#' @param x Any R value.
#' @return A single string, e.g. `"int[3]"`, `"<User>"`, `"data.frame[2 x 3]"`.
#' @export
#' @examples
#' type_of(1:3)
#' type_of(1.5)
#' type_of("a")
#' type_of(Sys.Date())
#' type_of(data.frame(a = 1:2))
#' type_of(NULL)
type_of <- function(x) {
  if (is.null(x)) return("NULL")
  if (inherits(x, "typed_instance")) return(paste0("<", class(x)[1], ">"))
  if (is.data.frame(x)) return(sprintf("data.frame[%d x %d]", nrow(x), ncol(x)))
  if (inherits(x, "Date")) return(sprintf("date[%d]", length(x)))
  if (inherits(x, "POSIXct")) return(sprintf("datetime[%d]", length(x)))
  if (is.factor(x)) return(sprintf("factor[%d]", length(x)))
  if (is.list(x)) return(sprintf("list[%d]", length(x)))
  base <- if (is.integer(x)) "int" else if (is.double(x)) "num" else if (
    is.character(x)
  )
    "chr" else if (is.logical(x)) "lgl" else class(x)[1]
  sprintf("%s[%d]", base, length(x))
}

#' Describe a value for an error message
#'
#' Like [type_of()], but a scalar also shows its value -- which is usually the
#' thing the reader needs.
#'
#' @param x Any R value.
#' @return A single string.
#' @keywords internal
#' @examples
#' rdantic:::.got(1.5)
#' rdantic:::.got(c(1, 2))
.got <- function(x) {
  t <- type_of(x)
  if (is.null(x) || length(x) != 1) return(t)
  if (inherits(x, c("Date", "POSIXct")) || is.factor(x))
    return(paste0(t, ' "', format(x), '"'))
  if (is.atomic(x)) paste(t, deparse1(x)) else t
}

#' Suggest the name the user probably meant
#'
#' @param name The name that was not found.
#' @param candidates The names that exist.
#' @return A hint string, or `NULL` when nothing is close enough.
#' @keywords internal
#' @examples
#' rdantic:::.did_you_mean("nmae", c("name", "id"))
#' rdantic:::.did_you_mean("zzz", c("name", "id"))
.did_you_mean <- function(name, candidates) {
  if (!length(candidates)) return(NULL)
  d <- utils::adist(name, candidates, ignore.case = TRUE)[1, ]
  i <- which.min(d)
  if (d[i] <= max(2, nchar(name) %/% 3))
    sprintf("did you mean `%s`?", candidates[i]) else NULL
}

#' Reject names that would collide with generated code's own bindings
#'
#' `fn()` and `struct()` splice user-supplied names into generated code
#' alongside a handful of internal bookkeeping variables; a name equal to one
#' of those would silently shadow it instead of erroring, so this rejects the
#' collision up front instead.
#'
#' @param nms The supplied names.
#' @param reserved The names that must not be used.
#' @param what What kind of name this is, e.g. `"argument"` or `"field"`.
#' @return Nothing; throws when a reserved name is used.
#' @keywords internal
#' @examples
#' rdantic:::.reject_reserved(c("x", "y"), c(".r_"), "argument")
#' try(rdantic:::.reject_reserved(c(".r_"), c(".r_"), "argument"))
.reject_reserved <- function(nms, reserved, what) {
  hit <- intersect(nms, reserved)
  if (length(hit))
    stop(sprintf(
      "%s name `%s` is reserved for rdantic's internals; choose a different name",
      what,
      hit[1]
    ), call. = FALSE)
}

#' Throw a validation error
#'
#' Every problem is reported, one per line, each with its path, what was
#' expected, what arrived, and a hint when there is one. The condition carries
#' the records in `$problems` so tooling can consume them.
#'
#' @param problems A `typed_problems` object or a plain list of records.
#' @param context What was being validated, used in the first line.
#' @return Nothing; throws a condition of class `typed_error`.
#' @keywords internal
#' @examples
#' try(rdantic:::.abort(rdantic:::.bad("$id", "int[1]", "chr[1] \"x\""), "User"))
.abort <- function(problems, context) {
  problems <- unclass(problems)
  n <- length(problems)
  paths <- vapply(
    problems,
    function(p) if (nzchar(p$path)) p$path else "<value>",
    ""
  )
  lines <- sprintf(
    "  %s  expected %s, got %s%s",
    formatC(paths, width = max(nchar(paths)), flag = "-"),
    vapply(problems, `[[`, "", "expected"),
    vapply(problems, `[[`, "", "got"),
    vapply(
      problems,
      function(p) if (is.null(p$hint)) "" else paste0("  -- ", p$hint),
      ""
    )
  )
  msg <- sprintf(
    "%d validation problem%s in %s\n%s",
    n,
    if (n == 1) "" else "s",
    context,
    paste(lines, collapse = "\n")
  )
  stop(structure(
    class = c("typed_error", "error", "condition"),
    list(message = msg, call = NULL, problems = problems)
  ))
}

#' Throw a typed error that is about the type, not about a value
#'
#' Used for things like an unresolvable [ref()], which must still be catchable
#' as `typed_error` rather than escaping as a bare `simpleError`.
#'
#' @param msg The message to show.
#' @return Nothing; throws a condition of class `typed_error`.
#' @keywords internal
#' @examples
#' try(rdantic:::.abort_msg("unknown struct `Nope`"))
.abort_msg <- function(msg)
  stop(structure(
    class = c("typed_error", "error", "condition"),
    list(
      message = msg,
      call = NULL,
      problems = list(list(
        path = "",
        expected = "<usable type>",
        got = msg,
        hint = NULL
      ))
    )
  ))
