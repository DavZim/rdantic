#' Fix a type's length, or add a constraint
#'
#' `T[n]` is `T` with exactly `n` elements. `T[expr]`, where `expr` mentions
#' `.`, is `T` restricted to values for which the predicate holds elementwise.
#' The two chain in any order, and the source text of the predicate becomes
#' part of the type's name, so an error states the rule that was broken.
#'
#' `T[1]` is the most useful type in R: most recycling bugs are a vector
#' arriving where one value was meant.
#'
#' @param x A type.
#' @param i A length, or an expression in `.`.
#' @return A type.
#' @export
#' @examples
#' int[1](3)
#' try(int[1](c(3, 4)))
#'
#' num[. > 0](c(1, 2))
#' try(num[. > 0](c(1, -2)))
#'
#' small <- int[1][0 < . & . < 10]
#' small
#' small(7)
#' try(small(70))
#'
#' chr[1][nchar(.) <= 3]("abc")
`[.type` <- function(x, i) {
  e <- substitute(i)
  if (!("." %in% all.names(e))) .sized(x, eval(e, parent.frame())) else
    .refined(x, e, parent.frame())
}

#' Fix the length of a type
#'
#' @param t A type.
#' @param n The required length.
#' @return A type.
#' @keywords internal
#' @examples
#' rdantic:::.sized(int, 2)(c(1, 2))
.sized <- function(t, n) {
  s <- .spec(t)
  name <- sprintf("%s[%d]", s$name, n)
  new_type(
    name,
    validate = function(x, path) {
      r <- s$validate(x, path)
      if (.is_bad(r)) return(.relabel(r, path, name))
      if (length(r) != n)
        return(.bad(
          path,
          name,
          .got(x),
          sprintf("length is %d, not %d", length(r), n)
        ))
      r
    },
    schema = function() {
      inner <- s$schema()
      if (n == 1 && identical(inner$type, "array")) inner$items else
        c(inner, list(minItems = n, maxItems = n))
    },
    scalar = n == 1,
    empty = s$empty
  )
}

#' Restrict a type with a predicate
#'
#' @param t A type.
#' @param expr An unevaluated expression in `.`.
#' @param env The environment the expression is evaluated in.
#' @return A type.
#' @keywords internal
#' @examples
#' rdantic:::.refined(int, quote(. > 0), environment())(c(1, 2))
.refined <- function(t, expr, env) {
  s <- .spec(t)
  name <- sprintf("%s[%s]", s$name, deparse1(expr))
  new_type(
    name,
    validate = function(x, path) {
      r <- s$validate(x, path)
      if (.is_bad(r)) return(.relabel(r, path, name))
      hit <- eval(expr, list(. = r), env)
      if (!is.logical(hit) || !isTRUE(all(hit)))
        return(.bad(path, name, .got(x), .refine_hint(hit, r)))
      r
    },
    schema = function()
      c(s$schema(), list(description = paste("satisfies", deparse1(expr)))),
    scalar = isTRUE(s$scalar),
    empty = s$empty
  )
}

#' Say which elements failed a predicate
#'
#' @param hit The predicate's result.
#' @param value The validated value.
#' @return A one-line hint, or `NULL`.
#' @keywords internal
#' @examples
#' rdantic:::.refine_hint(c(TRUE, FALSE, FALSE), c(1, -2, -3))
.refine_hint <- function(hit, value) {
  if (!is.logical(hit)) return("the predicate did not return TRUE/FALSE")
  if (length(hit) != length(value) || length(value) < 2) return(NULL)
  bad <- which(!hit | is.na(hit))
  sprintf(
    "fails at element%s %s",
    if (length(bad) == 1) "" else "s",
    paste(
      c(as.character(utils::head(bad, 5)), if (length(bad) > 5) "..."),
      collapse = ", "
    )
  )
}

#' Union of two types
#'
#' `A | B` accepts either. `T | NULL` is the idiom for an optional value.
#' Every other operator is an error, so a typo cannot silently produce
#' something that is not a type.
#'
#' @param e1,e2 Types, or anything [as_type()] accepts.
#' @return A type.
#' @export
#' @examples
#' either <- int[1] | chr[1]
#' either(7)
#' either("seven")
#' try(either(TRUE))
#'
#' (int[1] | NULL)(NULL)
#' try(int[1] + chr[1])
Ops.type <- function(e1, e2) {
  if (.Generic != "|")
    stop("operator `", .Generic, "` is not defined for types")
  .union(as_type(e1), as_type(e2))
}

#' The alternatives of a type
#'
#' @param t A type.
#' @return A list of types: the union's members, or `t` itself.
#' @keywords internal
#' @examples
#' length(rdantic:::.members(int | chr | NULL))
.members <- function(t) {
  m <- .spec(t)$members
  if (is.null(m)) list(t) else m
}

#' Combine types into a union
#'
#' Unions flatten, so `A | B | C` has three members rather than a nested pair,
#' and a default written on either side belongs to the whole union -- which is
#' what makes `int[1] | NULL %default% NULL` mean what it looks like despite
#' `%op%` binding tighter than `|`.
#'
#' @param a,b Types.
#' @return A type.
#' @keywords internal
#' @examples
#' rdantic:::.union(int, chr)
.union <- function(a, b) {
  members <- c(.members(a), .members(b))
  name <- paste(
    vapply(members, function(m) .spec(m)$name, ""),
    collapse = " | "
  )
  specs <- lapply(members, .spec)
  with_default <- Filter(function(s) isTRUE(s$has_default), specs)
  extras <- if (length(with_default))
    list(default = with_default[[1]]$default, has_default = TRUE) else list()
  non_null <- Filter(function(s) s$name != "NULL", specs)
  scalar <- length(non_null) > 0 &&
    all(vapply(non_null, function(s) isTRUE(s$scalar), NA))
  do.call(
    new_type,
    c(
      list(
        name,
        validate = function(x, path) {
          nested <- NULL
          hints <- character()
          for (m in members) {
            r <- .spec(m)$validate(x, path)
            if (!.is_bad(r)) return(r)
            hints <- c(hints, .hints_of(r))
            # remember the first member that got *inside* the value (e.g. a struct
            # parsing a list) so its precise problems are reported instead of
            # a generic "expected A | B"
            if (
              is.null(nested) &&
                any(vapply(
                  unclass(r),
                  function(p) !identical(p$path, path),
                  NA
                ))
            )
              nested <- r
          }
          if (!is.null(nested)) return(nested)
          hints <- unique(hints)
          .bad(path, name, .got(x), if (length(hints) == 1) hints)
        },
        schema = function() {
          member_schemas <- lapply(members, function(m) .spec(m)$schema())
          # a union of bare scalar types (e.g. T | NULL) reads as one "type" array;
          # anything with structure (items, properties, enum, $ref, ...) needs anyOf
          simple <- vapply(
            member_schemas,
            function(s) identical(names(s), "type") && is.character(s$type) &&
              length(s$type) == 1,
            NA
          )
          if (all(simple))
            list(type = vapply(member_schemas, `[[`, "", "type")) else
            list(anyOf = member_schemas)
        },
        members = members,
        scalar = scalar
      ),
      extras
    )
  )
}

#' Collect the hints from a set of problems
#'
#' @param r A `typed_problems` object.
#' @return A character vector, possibly empty.
#' @keywords internal
#' @examples
#' rdantic:::.hints_of(rdantic:::.bad("", "int", "num[1] 1.5", "not a whole number"))
.hints_of <- function(r)
  unlist(
    lapply(unclass(r), function(p) p$hint),
    use.names = FALSE
  )

#' Make a type optional
#'
#' Shorthand for `T | NULL`, and the readable way to write a self-reference or
#' a forward reference by name.
#'
#' @param t A type, or a struct name.
#' @return A type.
#' @export
#' @examples
#' opt(int[1])(NULL)
#' opt(int[1])(3)
#' opt("User")
opt <- function(t) as_type(t) | NULL

#' Reject missing values
#'
#' R's quietest bug: `NA` sails through every arithmetic operator and every
#' comparison. `no_na(T)` is `T` that also refuses `NA`.
#'
#' @param t A type, or anything [as_type()] accepts.
#' @return A type.
#' @export
#' @examples
#' no_na(num)(c(1, 2))
#' try(no_na(num)(c(1, NA)))
#' try(no_na(chr[1])(NA_character_))
no_na <- function(t) {
  t <- as_type(t)
  s <- .spec(t)
  name <- sprintf("no_na(%s)", s$name)
  new_type(
    name,
    validate = function(x, path) {
      r <- s$validate(x, path)
      if (.is_bad(r)) return(.relabel(r, path, name))
      if (anyNA(r)) return(.bad(path, name, .got(x), "contains NA"))
      r
    },
    schema = s$schema,
    scalar = isTRUE(s$scalar),
    empty = s$empty
  )
}

#' Enumeration of literal values
#'
#' Accepts exactly one of the given values and returns it. Comparison is type
#' aware: `one_of("1", "2")` does not accept the number `1`, because [match()]
#' would have stringified it.
#'
#' @param ... The permitted values.
#' @return A type.
#' @export
#' @seealso [fct()] for the same idea with a factor result.
#' @examples
#' role <- one_of("admin", "user")
#' role("admin")
#' try(role("root"))
#' try(one_of("1", "2")(1))
#'
#' one_of("admin", "user") %default% "user"
#' schema(role)
one_of <- function(...) {
  vals <- c(...)
  name <- paste0(
    "one_of(",
    paste(vapply(vals, deparse1, ""), collapse = ", "),
    ")"
  )
  new_type(
    name,
    validate = function(x, path) {
      y <- if (is.factor(x)) as.character(x) else x
      if (length(y) == 1 && is.atomic(y)) {
        hit <- which(vapply(
          seq_along(vals),
          function(k) .same_value(y, vals[k]),
          NA
        ))
        if (length(hit)) return(vals[hit[1]])
      }
      .bad(
        path,
        name,
        .got(x),
        if (length(y) == 1 && is.atomic(y) && !.comparable(y, vals))
          "the literals have a different type"
      )
    },
    schema = function() list(enum = as.list(vals)),
    scalar = TRUE,
    empty = vals[0]
  )
}

#' Could two values be equal without coercion?
#'
#' @param x,v Atomic values.
#' @return `TRUE` when comparing them would not stringify either side.
#' @keywords internal
#' @examples
#' rdantic:::.comparable(1, 2)
#' rdantic:::.comparable(1, "2")
.comparable <- function(x, v)
  is.character(x) == is.character(v) && is.logical(x) == is.logical(v)

#' Type-aware equality
#'
#' @param x A value.
#' @param v A literal to compare against.
#' @return `TRUE` when they are the same value of a compatible type.
#' @keywords internal
#' @examples
#' rdantic:::.same_value(1, 1)
#' rdantic:::.same_value(1, "1")
.same_value <- function(x, v) .comparable(x, v) && isTRUE(x == v)

#' Attach a default to a type
#'
#' The default is validated immediately, so a wrong default is an error where
#' it is written rather than where it is used. Struct fields and [fn()]
#' arguments fall back to it when no value is supplied.
#'
#' @param t A type, or anything [as_type()] accepts.
#' @param value The default value.
#' @return A type carrying the default.
#' @export
#' @examples
#' role <- one_of("admin", "user") %default% "user"
#' role
#'
#' Cfg <- struct("Cfg", retries = int[1] %default% 3L, tag = chr[1] | NULL)
#' Cfg()$retries
#'
#' try(int[1] %default% "three")
`%default%` <- function(t, value) {
  t <- as_type(t)
  s <- .spec(t)
  s["default"] <- list(parse_as(t, value))
  s$has_default <- TRUE
  .rebuild(s)
}

#' Attach a description to a type's schema
#'
#' The description is what [schema()] puts under the JSON Schema
#' `"description"` key -- the pydantic-style docstring for a field. It must be
#' the outermost wrapper in a chain (applied after `[n]`, `[expr]`, `opt()`/
#' `|` and `%default%`), the same implicit rule `%default%` already has,
#' because an outer combinator builds its own schema fragment and would
#' otherwise discard it. A description added this way replaces, rather than
#' duplicates, one [.refined()] wrote automatically.
#'
#' A struct's own top-level description is set with `struct(.description = )`
#' instead: `desc()` on a whole struct builds a new, unregistered constructor,
#' so a [ref()] to that struct's name would still see the undescribed one.
#'
#' @param t A type, or anything [as_type()] accepts.
#' @param description A single string.
#' @return A type carrying the description.
#' @export
#' @examples
#' age <- int[1][. > 0] %doc% "Age in years."
#' schema(age)$description
#'
#' Person <- struct("Person",
#'   name = chr[1] %doc% "Full name of the person.",
#'   occupation = opt(chr[1]) %doc% "Current job title, or null if unknown."
#' )
#' schema(Person)$properties$occupation
desc <- function(t, description) {
  t <- as_type(t)
  if (!is.character(description) || length(description) != 1 || is.na(description))
    stop("desc() needs a single string description")
  s <- .spec(t)
  inner_schema <- s$schema
  s$schema <- function() utils::modifyList(inner_schema(), list(description = description))
  .rebuild(s)
}

#' @rdname desc
#' @export
`%doc%` <- function(t, description) desc(t, description)
