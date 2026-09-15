#' Validate a set of named, typed fields
#'
#' Record semantics, shared by `list_of(a = T, ...)` and [struct()]: one type per
#' key, defaults filled in, missing keys reported, unknown keys ignored or
#' refused. Every problem is collected, not just the first.
#'
#' @param fields A named list of types.
#' @param args The named list of supplied values.
#' @param path The path prefix for problem records.
#' @param extra `"ignore"` or `"forbid"`.
#' @param label What to call the record in a top-level problem.
#' @return The validated values in field order, or a `typed_problems` object.
#' @keywords internal
#' @examples
#' rdantic:::.check_fields(list(x = int[1]), list(x = 1), "", "ignore", "rec")
#' rdantic:::.check_fields(list(x = int[1]), list(), "", "ignore", "rec")
.check_fields <- function(fields, args, path, extra, label) {
  if (length(args) && (is.null(names(args)) || any(!nzchar(names(args)))))
    return(.bad(path, label, "unnamed values"))
  probs <- list()
  vals <- list()
  if (identical(extra, "forbid"))
    for (e in setdiff(names(args), names(fields)))
      probs <- c(
        probs,
        unclass(.bad(
          paste0(path, "$", e),
          "<no such field>",
          .got(args[[e]]),
          .did_you_mean(e, names(fields))
        ))
      )
  for (n in names(fields)) {
    t <- .spec(fields[[n]])
    p <- paste0(path, "$", n)
    supplied <- n %in% names(args)
    x <- if (supplied) args[[n]] else if (isTRUE(t$has_default)) t$default else
      NULL
    r <- t$validate(x, p)
    if (!.is_bad(r)) vals[n] <- list(r) else if (
      !supplied && !isTRUE(t$has_default)
    )
      probs <- c(probs, unclass(.bad(p, t$name, "<missing>"))) else
      probs <- c(probs, unclass(r))
  }
  if (length(probs)) .fail(probs) else vals[names(fields)]
}

#' Which fields must be supplied?
#'
#' A field is optional when it has a default or when its type accepts `NULL`.
#'
#' @param fields A named list of types.
#' @return A character vector of field names.
#' @keywords internal
#' @examples
#' rdantic:::.required_fields(list(a = int[1], b = int[1] | NULL, c = chr %default% "x"))
.required_fields <- function(fields)
  names(fields)[vapply(
    fields,
    function(f) {
      s <- .spec(f)
      if (isTRUE(s$has_default)) return(FALSE)
      tryCatch(.is_bad(s$validate(NULL, "")), error = function(e) TRUE)
    },
    NA
  )]

#' List types
#'
#' `list_of(T)` is an array of any length whose elements are all `T`; only an
#' unnamed list is accepted -- reach for [map_of()] for a named, arbitrary-key
#' shape.
#'
#' `list_of(a = T, b = T)` is a different thing again: a fixed key set with
#' one rule per key, still a plain named list on the way out. Missing keys are
#' reported, `%default%` fills them in, and `.extra = "forbid"` refuses
#' unknown ones. Reach for [struct()] when the record deserves a name, a class
#' and inheritance.
#'
#' @param ... One element type, or named keys with one type each.
#' @param .extra `"ignore"` (default) or `"forbid"`, for keys that were not
#'   declared. Only meaningful for the keyed form.
#' @return A type.
#' @export
#' @seealso [map_of()] for an arbitrary-key map, [frame()] for a data frame,
#'   [struct()] for a named record.
#' @examples
#' # an array of any length, one element type
#' tags <- list_of(chr[1])
#' tags(list("a", "b"))
#' try(tags(list(a = "x")))                # a named list is map_of(), not this
#'
#' # a fixed key set, one rule per key
#' limits <- list_of(cpu = int[1][0 < . & . < 12], memory = int[1][0 < . & . < 128])
#' limits
#' str(limits(list(cpu = 4, memory = 16)))
#' try(limits(list(cpu = 16, memory = 512)))
#' try(limits(list(cpu = 4)))
#'
#' list_of(cpu = int[1], .extra = "forbid")
#' schema(limits)
list_of <- function(..., .extra = c("ignore", "forbid")) {
  .extra <- match.arg(.extra)
  args <- list(...)
  nms <- names(args)
  if (!length(args)) stop("list_of() needs an element type or named keys")
  if (is.null(nms) || !any(nzchar(nms))) {
    if (length(args) != 1)
      stop("list_of(T) takes one element type; name them to fix the key set")
    return(.list_of_any(as_type(args[[1]])))
  }
  if (!all(nzchar(nms)))
    stop("list_of() takes one element type or named keys, not both")
  .list_of_keys(lapply(args, as_type), .extra)
}

#' An array of any length with one element type
#'
#' @param t The element type.
#' @return A type.
#' @keywords internal
#' @examples
#' rdantic:::.list_of_any(int[1])(list(1, 2))
.list_of_any <- function(t) {
  name <- sprintf("list_of(%s)", .spec(t)$name)
  new_type(
    name,
    validate = function(x, path) {
      if (!is.list(x) || is.data.frame(x) || inherits(x, "typed_instance"))
        return(.bad(path, name, .got(x)))
      if (!is.null(names(x)) && any(nzchar(names(x))))
        return(.bad(path, name, .got(x), "a named list is map_of(), not list_of()"))
      validate <- .spec(t)$validate
      out <- vector("list", length(x))
      probs <- list()
      for (i in seq_along(x)) {
        r <- validate(x[[i]], sprintf("%s[[%d]]", path, i))
        if (.is_bad(r)) probs <- c(probs, unclass(r)) else out[i] <- list(r)
      }
      if (length(probs)) .fail(probs) else out
    },
    schema = function() list(type = "array", items = .spec(t)$schema()),
    elt = t
  )
}

#' Map types
#'
#' The map counterpart of `list_of(T)`: arbitrary keys, one value type, kept
#' by name -- and what a JSON object with arbitrary keys parses into. A
#' failure is reported by key rather than by position.
#'
#' Reach for `list_of(a = T, b = T)` instead when the key set is fixed and
#' known up front.
#'
#' @param t The value type.
#' @return A type.
#' @export
#' @seealso [list_of()] for an array, or a fixed key set.
#' @examples
#' budget <- map_of(int[1][. > 0])
#' budget(list(cpu = 4, memory = 16))
#' try(budget(list(cpu = 4, memory = 0)))
#' try(map_of(int[1])(list(1, 2)))         # unnamed input is list_of(), not this
#'
#' schema(budget)
#' from_json(map_of(int[1]), '{"cpu": 4, "memory": 16}')
map_of <- function(t) .map_of_any(as_type(t))

#' A map of any length with one element type, keyed by name
#'
#' @param t The element type.
#' @return A type.
#' @keywords internal
#' @examples
#' rdantic:::.map_of_any(int[1])(list(a = 1, b = 2))
.map_of_any <- function(t) {
  name <- sprintf("map_of(%s)", .spec(t)$name)
  new_type(
    name,
    validate = function(x, path) {
      if (!is.list(x) || is.data.frame(x) || inherits(x, "typed_instance"))
        return(.bad(path, name, .got(x)))
      if (length(x) && (is.null(names(x)) || any(!nzchar(names(x)))))
        return(.bad(path, name, .got(x), "every key must be named"))
      validate <- .spec(t)$validate
      out <- vector("list", length(x))
      names(out) <- if (length(x)) names(x) else character()
      probs <- list()
      for (i in seq_along(x)) {
        r <- validate(x[[i]], paste0(path, "$", names(x)[i]))
        if (.is_bad(r)) probs <- c(probs, unclass(r)) else out[i] <- list(r)
      }
      if (length(probs)) .fail(probs) else out
    },
    schema = function()
      list(type = "object", additionalProperties = .spec(t)$schema()),
    elt = t
  )
}

#' A named list with a fixed key set
#'
#' @param keys A named list of types.
#' @param extra `"ignore"` or `"forbid"`.
#' @return A type.
#' @keywords internal
#' @examples
#' rdantic:::.list_of_keys(list(a = int[1]), "forbid")(list(a = 1))
.list_of_keys <- function(keys, extra) {
  name <- sprintf("list_of(%s)", paste(names(keys), collapse = ", "))
  new_type(
    name,
    validate = function(x, path) {
      if (!is.list(x) || is.data.frame(x) || inherits(x, "typed_instance"))
        return(.bad(path, name, .got(x)))
      .check_fields(keys, x, path, extra, name)
    },
    schema = function()
      list(
        type = "object",
        properties = lapply(keys, function(k) .spec(k)$schema()),
        required = as.list(.required_fields(keys)),
        additionalProperties = !identical(extra, "forbid")
      ),
    keys = keys
  )
}

#' Data frame type
#'
#' A data frame with typed columns. Each column is validated as a vector, so
#' the usual length and constraint syntax applies to it; a column that comes
#' back the wrong length for the number of rows is an error, as is a missing
#' column.
#'
#' While parsing JSON, an array of objects is reshaped into a data frame -- and
#' a row that is missing a key is reported by name instead of quietly producing
#' a list column.
#'
#' @param ... Named columns, one type each.
#' @param .extra `"ignore"` (default) or `"forbid"`, for columns that were not
#'   declared.
#' @return A type.
#' @export
#' @seealso [list_of()]
#' @examples
#' roster <- frame(id = int, name = chr)
#' str(roster(data.frame(id = c(1, 2), name = c("Ada", "Bob"))))
#'
#' try(roster(data.frame(id = 1)))
#' try(frame(id = int, .extra = "forbid")(data.frame(id = 1L, junk = 2)))
#'
#' from_json(roster, '[{"id": 1, "name": "Ada"}, {"id": 2, "name": "Bob"}]')
#' try(from_json(roster, '[{"id": 1}]'))
#' nrow(from_json(roster, "[]"))
frame <- function(..., .extra = c("ignore", "forbid")) {
  .extra <- match.arg(.extra)
  cols <- lapply(list(...), as_type)
  if (!length(cols) || is.null(names(cols)) || any(!nzchar(names(cols))))
    stop("frame() needs named columns: frame(id = int, ...)")
  name <- sprintf("frame(%s)", paste(names(cols), collapse = ", "))
  cell_schema <- function(s) {
    if (identical(s$type, "array")) return(s$items)
    if (!is.null(s$anyOf)) s$anyOf <- lapply(s$anyOf, cell_schema)
    s
  }
  new_type(
    name,
    validate = function(x, path) {
      if (.ctx$parsing && is.list(x) && !is.data.frame(x)) {
        x <- .rows_to_df(x, cols, path, name, .extra)
        if (.is_bad(x)) return(x)
      }
      if (!is.data.frame(x)) return(.bad(path, name, .got(x)))
      probs <- list()
      if (identical(.extra, "forbid"))
        for (e in setdiff(names(x), names(cols)))
          probs <- c(
            probs,
            unclass(.bad(
              paste0(path, "$", e),
              "<no such column>",
              .got(x[[e]])
            ))
          )
      n <- nrow(x)
      for (col in names(cols)) {
        p <- paste0(path, "$", col)
        expected <- .spec(cols[[col]])$name
        if (!col %in% names(x)) {
          probs <- c(
            probs,
            unclass(.bad(
              p,
              expected,
              "<missing column>",
              .did_you_mean(col, names(x))
            ))
          )
          next
        }
        r <- .spec(cols[[col]])$validate(x[[col]], p)
        if (.is_bad(r)) {
          probs <- c(probs, unclass(r))
        } else if (length(r) != n) {
          probs <- c(
            probs,
            unclass(.bad(
              p,
              expected,
              sprintf("%d value%s for %d rows", length(r), if (length(r) == 1)
                "" else "s", n)
            ))
          )
        } else {
          x[[col]] <- r
        }
      }
      if (length(probs)) .fail(probs) else x
    },
    schema = function()
      list(
        type = "array",
        items = list(
          type = "object",
          # a row cell is one scalar value, not the whole column's vector shape
          properties = lapply(cols, function(c) cell_schema(.spec(c)$schema()))
        )
      )
  )
}

#' Turn a list of row records into a data frame
#'
#' jsonlite parses `[{...}, {...}]` as a list of records. An empty array
#' becomes a zero-row frame with columns of the declared types.
#'
#' @param rows The list of records.
#' @param cols The named list of column types.
#' @param path The path prefix for problem records.
#' @param name The frame type's name.
#' @param extra `"ignore"` or `"forbid"`, for row keys that were not declared.
#' @return A data frame, or a `typed_problems` object.
#' @keywords internal
#' @examples
#' rdantic:::.rows_to_df(list(list(a = 1), list(a = 2)), list(a = int), "", "frame(a)", "ignore")
.rows_to_df <- function(rows, cols, path, name, extra) {
  if (!length(rows))
    return(structure(
      lapply(cols, function(t) {
        e <- .spec(t)$empty
        if (is.null(e)) logical() else e
      }),
      class = "data.frame",
      row.names = integer()
    ))
  if (!all(vapply(rows, function(r) is.list(r) && !is.null(names(r)), NA)))
    return(.bad(path, name, .got(rows)))
  probs <- list()
  if (identical(extra, "forbid"))
    for (e in setdiff(unique(unlist(lapply(rows, names))), names(cols)))
      probs <- c(
        probs,
        unclass(.bad(paste0(path, "$", e), "<no such column>", "<present in JSON>"))
      )
  out <- lapply(stats::setNames(nm = names(cols)), function(col) {
    miss <- which(!vapply(rows, function(r) col %in% names(r), NA))
    if (length(miss)) {
      probs <<- c(
        probs,
        unclass(.bad(
          paste0(path, "$", col),
          .spec(cols[[col]])$name,
          sprintf(
            "<missing in row%s %s>",
            if (length(miss) == 1) "" else "s",
            paste(utils::head(miss, 5), collapse = ", ")
          )
        ))
      )
      return(logical())
    }
    vals <- lapply(rows, function(r) r[[col]])
    if (all(lengths(vals) == 1) && all(vapply(vals, is.atomic, NA)))
      unlist(vals) else vals
  })
  if (length(probs)) return(.fail(probs))
  structure(out, class = "data.frame", row.names = seq_along(rows))
}
