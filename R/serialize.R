#' Convert an instance to plain lists
#'
#' Recursively, so nested structs come back as nested named lists.
#'
#' @param x An instance, a list, or any other value.
#' @return The same shape with every instance replaced by a named list.
#' @export
#' @examples
#' Pin <- struct("Pin", lat = num[1], lon = num[1])
#' Trip <- struct("Trip", from = Pin, to = Pin)
#' str(to_list(Trip(from = Pin(lat = 1, lon = 2), to = Pin(lat = 3, lon = 4))))
to_list <- function(x) {
  if (inherits(x, "typed_instance"))
    lapply(
      stats::setNames(nm = fields(x)),
      function(f) to_list(.subset2(x, f))
    ) else if (is.list(x) && !is.data.frame(x)) lapply(x, to_list) else x
}

#' Convert an instance to a list
#'
#' @param x An instance.
#' @param ... Ignored.
#' @return A named list.
#' @export
#' @examples
#' as.list(struct("Rgb", r = int[1], g = int[1], b = int[1])(r = 1, g = 2, b = 3))
as.list.typed_instance <- function(x, ...) to_list(x)

#' Require jsonlite
#'
#' @return Nothing; throws when the package is missing.
#' @keywords internal
#' @examples
#' rdantic:::.need_jsonlite()
.need_jsonlite <- function()
  if (!requireNamespace("jsonlite", quietly = TRUE))
    stop("to_json()/from_json() need the jsonlite package", call. = FALSE)

#' Serialise to JSON, guided by the declared types
#'
#' A field declared `[1]` becomes a JSON scalar; any other vector becomes an
#' array, even with one element. That is the difference R's own types cannot
#' express and JSON needs.
#'
#' @param x An instance, a schema, or any value jsonlite can handle.
#' @param pretty Whether to indent the output.
#' @param ... Passed to [jsonlite::toJSON()].
#' @return A `json` string.
#' @export
#' @seealso [from_json()], [schema()]
#' @examples
#' Tagged <- struct("Tagged", id = int[1], tags = chr, seen = date[1] | NULL)
#' to_json(Tagged(id = 3, tags = "cobol"))
#' to_json(Tagged(id = 3, tags = c("a", "b"), seen = as.Date("2024-01-01")))
#' to_json(schema(Tagged))
to_json <- function(x, pretty = TRUE, ...) {
  .need_jsonlite()
  jsonlite::toJSON(
    .json_ready(x, NULL),
    auto_unbox = TRUE,
    null = "null",
    na = "null",
    dataframe = "rows",
    pretty = pretty,
    digits = NA,
    ...
  )
}

#' Walk a value alongside its declared type
#'
#' A length-1 vector is only unboxed to a JSON scalar when its type says `[1]`
#' (or `one_of`); otherwise `I()` keeps it an array, so a `tags = "a"` field
#' declared `chr` serialises as `["a"]`, not `"a"`.
#'
#' @param x The value.
#' @param t Its declared type, or `NULL` when unknown.
#' @return A structure ready for [jsonlite::toJSON()].
#' @keywords internal
#' @examples
#' rdantic:::.json_ready("a", chr)
#' rdantic:::.json_ready("a", chr[1])
.json_ready <- function(x, t) {
  s <- if (is.null(t)) NULL else .spec(t)
  if (inherits(x, "typed_instance")) {
    fs <- attr(x, "spec")$fields # the instance's own spec, never a name lookup
    return(lapply(
      stats::setNames(nm = names(fs)),
      function(f) .json_ready(.subset2(x, f), fs[[f]])
    ))
  }
  if (is.data.frame(x)) return(x)
  if (is.list(x)) {
    keys <- if (is.null(s)) NULL else s$keys
    if (!is.null(keys))
      return(lapply(
        stats::setNames(nm = names(x)),
        function(k) .json_ready(x[[k]], keys[[k]])
      ))
    elt <- .list_elt_type(s)
    return(lapply(x, function(e) .json_ready(e, elt)))
  }
  if (is.atomic(x) && length(x) == 1 && !is.null(s) && !isTRUE(s$scalar))
    return(I(x))
  x
}

#' The element type of a list type
#'
#' @param s A spec, or `NULL`.
#' @return The element type, or `NULL` when there is not exactly one.
#' @keywords internal
#' @examples
#' rdantic:::.list_elt_type(rdantic:::.spec(list_of(int[1])))
.list_elt_type <- function(s) {
  if (is.null(s)) return(NULL)
  if (!is.null(s$elt)) return(s$elt)
  if (!is.null(s$members))
    for (m in s$members) if (!is.null(.spec(m)$elt)) return(.spec(m)$elt)
  NULL
}

#' Parse and validate JSON in one step
#'
#' JSON arrays come back as R vectors and arrays of objects as data frames,
#' because the declared types accept those shapes -- there is no separate JSON
#' mode. Reshaping happens only here and in [from_list()], never when a value
#' is handed straight to a type.
#'
#' @param t A type, or anything [as_type()] accepts.
#' @param txt A JSON string, or anything [jsonlite::fromJSON()] reads.
#' @return The validated value.
#' @export
#' @seealso [to_json()], [from_list()], [try_parse()]
#' @examples
#' Reading <- struct("Reading", station = chr[1], celsius = num[1], at = datetime[1])
#' from_json(Reading, '{"station": "KOA", "celsius": 21.5, "at": "2024-05-17T09:30:00"}')
#'
#' from_json(list_of(int[1]), '{"cpu": 4, "memory": 16}')
#' from_json(frame(id = int, nm = chr), '[{"id": 1, "nm": "a"}]')
#'
#' try(from_json(Reading, '{"station": ["a", "b"], "celsius": 21.5, "at": "nope"}'))
from_json <- function(t, txt) {
  .need_jsonlite()
  .entry(
    parse_as(t, jsonlite::fromJSON(txt, simplifyVector = FALSE)),
    parsing = TRUE
  )
}
