#' Where structs register themselves by name
#'
#' Only [ref()] reads it, and only once per reference: instances carry their own
#' spec, so redefining a struct cannot retype values that already exist.
#'
#' @keywords internal
#' @noRd
.registry <- new.env(parent = emptyenv())

#' A struct's signature, for spotting redefinitions
#'
#' @param spec A struct spec.
#' @return A single string.
#' @keywords internal
#' @examples
#' rdantic:::.sig(rdantic:::.spec(struct("SigDemo", x = int[1])))
.sig <- function(spec)
  paste0(
    spec$name,
    "(",
    paste(
      names(spec$fields),
      vapply(spec$fields, function(f) .spec(f)$name, ""),
      sep = ": ",
      collapse = ", "
    ),
    ") ",
    spec$extra
  )

#' Refer to a struct by name
#'
#' Lets a struct refer to itself, or to one that is defined later. The name is
#' resolved on first use and then cached, so redefining a struct in a live
#' session cannot silently retype the structs that already refer to it.
#'
#' @param name The struct's name.
#' @return A type.
#' @export
#' @seealso [opt()] for the common `ref(name) | NULL` case.
#' @examples
#' Node <- struct("Node", value = int[1], next_ = opt("Node"))
#' Node(value = 1, next_ = list(value = 2))
#'
#' try(parse_as(ref("NeverDefined"), list()))
ref <- function(name) {
  cached <- NULL
  new_type(
    name,
    validate = function(x, path) {
      if (is.null(cached)) {
        m <- get0(name, envir = .registry, inherits = FALSE)
        if (is.null(m))
          .abort_msg(sprintf(
            'unknown struct `%s`: define it with struct("%s", ...) before validating',
            name,
            name
          ))
        cached <<- m
      }
      .spec(cached)$validate(x, path)
    },
    schema = function() list("$ref" = paste0("#/$defs/", name))
  )
}

#' Define a record type
#'
#' Returns a constructor with real formals -- so autocomplete works -- which is
#' itself a type, so structs nest and can be used anywhere a type can. Instances
#' are plain named lists with a class, which means they copy on modify like
#' every other R value.
#'
#' Where a struct is expected, a plain list is parsed into it. That is what makes
#' JSON input work with no separate JSON mode.
#'
#' @param .name The struct's name, as a single string.
#' @param ... Named fields, one type each.
#' @param .description The struct's JSON Schema `"description"`, or `NULL` to
#'   omit it. Use [desc()]/[`%doc%`] for a field's own description instead.
#' @param .parents Set by [extend()]; not usually written by hand.
#' @param .extra `"forbid"` rejects unknown keys when parsing a list into this
#'   struct; the default `"ignore"` drops them.
#' @return A constructor of class `typed_struct`, which is also a type.
#' @export
#' @seealso [extend()], [partial()], [list_of()], [fields()]
#' @examples
#' Account <- struct("Account",
#'   id      = int[1][. > 0],
#'   email   = chr[1][grepl("@", ., fixed = TRUE)],
#'   credit  = num[1][. >= 0] %default% 0,
#'   closed  = date[1] | NULL
#' )
#' Account
#'
#' a <- Account(id = 1, email = "ada@example.org")
#' a
#' a$credit
#'
#' # every problem at once, each with its path
#' try(Account(id = 0, email = "nope"))
#'
#' # fields are checked on assignment, and instances are values
#' b <- a
#' b$credit <- 10
#' c(a$credit, b$credit)
#' try(a$balance <- 10)
#'
#' # a plain list is parsed
#' from_list(Account, list(id = 2, email = "bob@example.org"))
#' try(from_list(struct("Shut", x = int[1], .extra = "forbid"), list(x = 1, y = 2)))
struct <- function(
  .name,
  ...,
  .description = NULL,
  .parents = character(),
  .extra = c("ignore", "forbid")
) {
  # dot-prefixed formals, like extend()'s `.parent`, so no field can ever
  # collide with them (e.g. a field called `name`, `parents` or `extra`).
  if (!is.character(.name) || length(.name) != 1)
    stop('struct() needs exactly one unnamed name: struct("User", ...)')
  ctor <- .struct_ctor(
    .name,
    .struct_fields(list(...)),
    .parents,
    .description,
    match.arg(.extra)
  )
  # scoped, so the previous constructor is not captured by this struct's closures
  local({
    prev <- get0(.name, envir = .registry, inherits = FALSE)
    if (!is.null(prev) && !identical(.sig(.spec(prev)), .sig(.spec(ctor))))
      warning(
        sprintf(
          "struct `%s` redefined; values and refs made earlier keep the previous definition",
          .name
        ),
        call. = FALSE
      )
  })
  assign(.name, ctor, envir = .registry)
  ctor
}

#' Check and coerce a set of declared fields
#'
#' @param fields The `...` of a struct-like declaration.
#' @return The same list, every entry passed through [as_type()].
#' @keywords internal
#' @examples
#' names(rdantic:::.struct_fields(list(a = int[1])))
.struct_fields <- function(fields) {
  nms <- names(fields)
  if (is.null(nms)) nms <- rep("", length(fields))
  if (length(fields) && any(!nzchar(nms)))
    stop("all struct fields must be named")
  .reject_reserved(nms, c(".args", ".spec_", ".spec_env_"), "field")
  lapply(fields, as_type)
}

#' Build a struct constructor without registering it
#'
#' The part of [struct()] that makes the type. [s7_struct()] needs it without
#' the name ever entering `.registry`, because the name there would resolve to
#' something that builds instances rather than S7 objects.
#'
#' @param name The struct's name.
#' @param fields A named list of types.
#' @param parents The parent class names.
#' @param description The schema `"description"`, or `NULL`.
#' @param extra `"ignore"` or `"forbid"`.
#' @return A constructor of class `typed_struct`.
#' @keywords internal
#' @examples
#' rdantic:::.struct_ctor("Loose", list(a = int[1]), character(), NULL, "ignore")
.struct_ctor <- function(name, fields, parents, description, extra) {
  if (
    !is.null(description) &&
      (!is.character(description) || length(description) != 1)
  )
    stop("a struct's .description must be a single string, or NULL")
  spec <- list(name = name, fields = fields, parents = parents, extra = extra)
  spec$validate <- function(x, path) {
    if (inherits(x, name)) return(x)
    # instances are lists, so a *different* struct must not be parsed as one
    if (inherits(x, "typed_instance"))
      return(.bad(path, paste0("<", name, ">"), .got(x)))
    if (is.list(x) && !is.data.frame(x))
      return(.new_instance(spec, x, path, spec_env))
    .bad(path, paste0("<", name, ">"), .got(x))
  }
  spec$schema <- function() {
    header <- list(type = "object", title = name)
    if (!is.null(description)) header$description <- description
    c(
      header,
      list(
        properties = lapply(
          stats::setNames(nm = .nm(fields)),
          function(n) .spec(fields[[n]])$schema()
        ),
        required = as.list(.required_fields(fields)),
        additionalProperties = FALSE
      )
    )
  }
  # instances carry this instead of `spec` itself: object.size() charges an
  # environment a small fixed cost rather than recursing into its contents
  spec_env <- list2env(spec, parent = emptyenv())
  .make_struct(spec, spec_env)
}

#' Compile a struct spec into a constructor
#'
#' The constructor gets one formal per field, so `args()`, autocomplete and
#' R's own "unused argument" error all work before any validation runs.
#'
#' @param spec A struct spec.
#' @param spec_env `spec`, wrapped in an environment; what instances carry as
#'   their own `spec` attribute (see [.bind_instance()]).
#' @return A constructor of class `typed_struct`.
#' @keywords internal
#' @examples
#' args(rdantic:::.make_struct(rdantic:::.spec(struct("MkDemo", a = int[1], b = chr[1]))))
.make_struct <- function(spec, spec_env = list2env(spec, parent = emptyenv())) {
  fields <- spec$fields
  ctor <- function() NULL
  formals(ctor) <- stats::setNames(
    rep(list(quote(expr = )), length(fields)),
    names(fields)
  )
  collect <- lapply(
    names(fields),
    function(n)
      bquote(if (!missing(.(as.name(n)))) .args[.(n)] <- list(.(as.name(n))))
  )
  body(ctor) <- as.call(c(
    as.name("{"),
    quote(.args <- list()),
    collect,
    quote({
      r <- .new_instance(.spec_, .args, "", .spec_env_)
      if (.is_bad(r)) .abort(r, .spec_$name)
      r
    })
  ))
  env <- new.env(parent = environment(.make_struct))
  env$.spec_ <- spec
  env$.spec_env_ <- spec_env
  environment(ctor) <- env
  attr(ctor, "spec") <- spec
  class(ctor) <- c("typed_struct", "type")
  ctor
}

#' Validate arguments and build an instance
#'
#' @param spec A struct spec.
#' @param args The supplied named values.
#' @param path The path prefix for problem records.
#' @param spec_env `spec`, wrapped in an environment; defaults to `spec`
#'   itself so direct calls (e.g. from examples) still work.
#' @return An instance, or a `typed_problems` object.
#' @keywords internal
#' @examples
#' rdantic:::.new_instance(rdantic:::.spec(struct("NewDemo", a = int[1])), list(a = 1), "")
.new_instance <- function(spec, args, path, spec_env = spec) {
  vals <- .check_fields(
    spec$fields,
    args,
    path,
    spec$extra,
    paste0("<", spec$name, ">")
  )
  if (.is_bad(vals)) return(vals)
  .bind_instance(spec, vals, spec_env)
}

#' Wrap validated values as an instance
#'
#' Instances are plain lists: copy-on-modify like every other R value, cheap to
#' build, and `identical()`, `saveRDS()` and `str()` all behave. The `spec`
#' attribute is an environment, not the spec list itself, so `object.size()`
#' -- which charges environments a small fixed cost instead of recursing into
#' them -- does not report each instance as if it owned a private copy of the
#' whole (shared) struct definition.
#'
#' @param spec A struct spec.
#' @param vals The validated values.
#' @param spec_env `spec`, wrapped in an environment; defaults to `spec`
#'   itself so direct calls (e.g. from examples) still work.
#' @return An object of class `c(name, parents, "typed_instance")`.
#' @keywords internal
#' @examples
#' rdantic:::.bind_instance(rdantic:::.spec(struct("BindDemo", a = int[1])), list(a = 1L))
.bind_instance <- function(spec, vals, spec_env = spec)
  structure(
    vals[names(spec$fields)],
    class = c(spec$name, spec$parents, "typed_instance"),
    spec = spec_env
  )

#' Field names of a struct or an instance
#'
#' @param x A struct, an instance, an S7 class or object, or anything
#'   [as_type()] accepts.
#' @return A character vector, in declaration order.
#' @export
#' @examples
#' Pt <- struct("Pt", x = num[1], y = num[1])
#' fields(Pt)
#' fields(Pt(x = 1, y = 2))
fields <- function(x) {
  if (inherits(x, "typed_instance")) return(.nm(attr(x, "spec")$fields))
  if (.is_s7_object(x)) x <- attr(x, "S7_class")
  if (.is_s7_class(x)) return(.nm(.s7_fields(x)))
  .nm(.spec(as_type(x))$fields)
}

#' Names of a possibly empty list
#'
#' `names(list())` is `NULL`, which would make a fieldless struct report no
#' field names rather than none, and serialise as a JSON array.
#'
#' @param x A list.
#' @return A character vector, empty rather than `NULL`.
#' @keywords internal
#' @examples
#' rdantic:::.nm(list())
.nm <- function(x) {
  n <- names(x)
  if (is.null(n)) character() else n
}

#' Read a field, without partial matching
#'
#' @param x An instance.
#' @param i A field name, or a position.
#' @return The field's value.
#' @keywords internal
#' @examples
#' rdantic:::.get_field(struct("GetDemo", a = int[1])(a = 1), "a")
.get_field <- function(x, i) {
  if (is.numeric(i)) return(.subset2(x, i))
  f <- fields(x)
  if (!i %in% f)
    .abort_msg(sprintf(
      "<%s> has no field `%s`%s\n  fields: %s",
      class(x)[1],
      i,
      {
        h <- .did_you_mean(i, f)
        if (is.null(h)) "" else paste0(" -- ", h)
      },
      paste(f, collapse = ", ")
    ))
  .subset2(x, i)
}

#' Read a field of an instance
#'
#' Matching is exact: `x$nam` is an error rather than a quiet hit on `name`,
#' which is what a plain list would do.
#'
#' @param x An instance.
#' @param name,i A field name, or a position.
#' @param ... Ignored.
#' @return The field's value.
#' @rdname instance-get
#' @export
#' @examples
#' Card <- struct("Card", holder = chr[1], number = chr[1])
#' cc <- Card(holder = "Ada", number = "4111")
#' cc$holder
#' cc[["number"]]
#' try(cc$holdr)
`$.typed_instance` <- function(x, name) .get_field(x, name)

#' @rdname instance-get
#' @export
`[[.typed_instance` <- function(x, i, ...) .get_field(x, i)

#' Validate and set a field
#'
#' @param x An instance.
#' @param name A field name.
#' @param value The new value.
#' @return A new instance.
#' @keywords internal
#' @examples
#' rdantic:::.set_field(struct("SetDemo", a = int[1])(a = 1), "a", 2)
.set_field <- function(x, name, value) {
  spec <- attr(x, "spec")
  t <- spec$fields[[name]]
  if (is.null(t))
    .abort(
      .bad(
        paste0("$", name),
        "<no such field>",
        .got(value),
        .did_you_mean(name, names(spec$fields))
      ),
      class(x)[1]
    )
  r <- .spec(t)$validate(value, paste0("$", name))
  if (.is_bad(r)) .abort(r, spec$name)
  y <- unclass(x)
  y[name] <- list(r)
  attr(y, "spec") <- spec
  class(y) <- class(x)
  y
}

#' Set a field of an instance
#'
#' The field's type runs on the way in, so an instance cannot become invalid
#' after it is built, and a field that was never declared cannot be invented by
#' a typo. Assignment returns a new value; instances are not references.
#'
#' @param x An instance.
#' @param name,i A field name.
#' @param value The new value.
#' @return A new instance.
#' @rdname instance-set
#' @export
#' @examples
#' Job <- struct("Job", state = one_of("queued", "done"), tries = int[1])
#' j <- Job(state = "queued", tries = 0)
#' j$state <- "done"
#' j$state
#' try(j$state <- "exploded")
#' try(j$stat <- "done")
`$<-.typed_instance` <- function(x, name, value) .set_field(x, name, value)

#' @rdname instance-set
#' @export
`[[<-.typed_instance` <- function(x, i, value) .set_field(x, i, value)

#' @rdname instance-set
#' @export
#' @examples
#' k <- Job(state = "queued", tries = 0)
#' k["tries"] <- 1
#' k$tries
#' try(k["state"] <- "exploded")
`[<-.typed_instance` <- function(x, i, value) {
  candidate <- unclass(x)
  if (missing(i)) candidate[] <- value else candidate[i] <- value
  if (!identical(names(candidate), names(x)))
    .abort_msg("Replacement must preserve the declared fields.")
  selected <- if (missing(i)) names(x) else names(candidate[i])
  for (n in unique(selected[!is.na(selected)]))
    x <- .set_field(x, n, candidate[[n]])
  x
}

#' Parse a plain list into a struct
#'
#' The list-shaped counterpart of the constructor: unknown keys are ignored
#' unless the struct was declared with `.extra = "forbid"`, and nested lists are
#' parsed into nested structs.
#'
#' @param struct A struct, or anything [as_type()] accepts.
#' @param x A named list.
#' @return An instance.
#' @export
#' @seealso [from_json()], [try_parse()]
#' @examples
#' Msg <- struct("Msg", topic = chr[1], size = int[1])
#' from_list(Msg, list(topic = "orders", size = 12))
#' from_list(Msg, list(topic = "orders", size = 12, extra = "ignored"))
#' try(from_list(Msg, list(topic = "orders")))
from_list <- function(struct, x) .entry(parse_as(struct, x), parsing = TRUE)

#' The fields a type can be subclassed or weakened through
#'
#' @param t A type.
#' @param what The calling function, for the error message.
#' @return A named list of types.
#' @keywords internal
#' @examples
#' names(rdantic:::.members_of(struct("FieldsDemo", a = int[1]), "extend()"))
.members_of <- function(t, what) {
  s <- .spec(t)
  f <- if (!is.null(s$fields)) s$fields else s$s7_fields
  if (is.null(f))
    stop(what, " needs a struct or an S7 class, not ", s$name, call. = FALSE)
  f
}

#' Subclass a struct
#'
#' The child gets the parent's fields plus its own, inherits the parent's class
#' -- so it is accepted wherever the parent is -- and may retype a parent field
#' by repeating its name.
#'
#' @param .parent The struct to extend, or an S7 class.
#' @param ... The subclass's name as the single unnamed string, then extra or
#'   replacement fields.
#' @return A constructor of class `typed_struct`.
#' @export
#' @seealso [struct()], [partial()]
#' @examples
#' Animal <- struct("Animal", name = chr[1], legs = int[1] %default% 4L)
#' Bird <- extend(Animal, "Bird", can_fly = lgl[1])
#'
#' tweety <- Bird(name = "Tweety", legs = 2, can_fly = TRUE)
#' tweety
#' inherits(tweety, "Animal")
#' is_valid(Animal, tweety)
#'
#' # a child may retype a parent field
#' fields(extend(Animal, "Centipede", legs = int[1][. > 50]))
extend <- function(.parent, ...) {
  ps <- .spec(as_type(.parent))
  fields <- .members_of(as_type(.parent), "extend()")
  args <- list(...)
  nms <- names(args)
  if (is.null(nms)) nms <- rep("", length(args))
  name <- args[[which(nms == "")[1]]]
  added <- lapply(args[nms != ""], as_type)
  fields[names(added)] <- added # a child may retype a parent's field
  do.call(
    struct,
    c(
      list(name),
      fields,
      list(.parents = c(ps$name, ps$parents), .extra = ps$extra)
    )
  )
}

#' Make every field of a struct optional
#'
#' For PATCH-shaped input, where only the supplied keys mean anything. Defaults
#' are dropped as well as requirements, so "not supplied" stays distinguishable
#' from "set to the default".
#'
#' @param .parent The struct to weaken, or an S7 class.
#' @param .name The new struct's name.
#' @return A constructor of class `typed_struct`.
#' @export
#' @seealso [struct()], [extend()]
#' @examples
#' Post <- struct("Post", title = chr[1], body = chr[1], draft = lgl[1] %default% TRUE)
#' PostPatch <- partial(Post)
#' PostPatch
#'
#' patch <- PostPatch(title = "New title")
#' patch$title
#' patch$draft          # NULL, not the default
partial <- function(
  .parent,
  .name = paste0("Partial", .spec(as_type(.parent))$name)
) {
  fields <- lapply(.members_of(as_type(.parent), "partial()"), function(f) {
    s <- .spec(f)
    if (!isTRUE(s$has_default)) return(f | NULL)
    s$has_default <- NULL
    s$default <- NULL
    .rebuild(s) | NULL
  })
  do.call(struct, c(list(.name), fields))
}

#' Print a struct
#'
#' @param x A struct.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
#' @examples
#' print(struct("PrintDemo", id = int[1], tag = chr[1] %default% "none"))
print.typed_struct <- function(x, ...) {
  s <- .spec(x)
  w <- if (length(s$fields)) max(nchar(names(s$fields))) else 0L
  cat("<struct> ", s$name, "\n", sep = "")
  for (n in names(s$fields)) {
    f <- .spec(s$fields[[n]])
    cat(
      "  ",
      formatC(n, width = w, flag = "-"),
      " : ",
      f$name,
      if (isTRUE(f$has_default)) paste0(" = ", deparse1(f$default)),
      "\n",
      sep = ""
    )
  }
  invisible(x)
}

#' One-line summary of a field's value
#'
#' @param v Any value.
#' @return A single string, truncated if long.
#' @keywords internal
#' @examples
#' rdantic:::.fmt(1:3)
#' rdantic:::.fmt(data.frame(a = 1:2))
.fmt <- function(v) {
  if (inherits(v, "typed_instance") || .is_s7_object(v))
    paste0("<", class(v)[1], ">") else if (
    is.data.frame(v)
  )
    sprintf("<data.frame %d x %d>", nrow(v), ncol(v)) else if (is.list(v))
    sprintf("<list of %d>", length(v)) else if (
    inherits(v, c("Date", "POSIXct"))
  )
    paste(format(v), collapse = ", ") else {
    s <- deparse1(v)
    if (nchar(s) > 60) paste0(substr(s, 1, 57), "...") else s
  }
}

#' Print an instance
#'
#' @param x An instance.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
#' @examples
#' Box <- struct("Box", label = chr[1], items = list_of(chr[1]))
#' print(Box(label = "tools", items = list("hammer", "nail")))
print.typed_instance <- function(x, ...) {
  f <- fields(x)
  w <- if (length(f)) max(nchar(f)) else 0L
  cat("<", class(x)[1], ">\n", sep = "")
  for (n in f)
    cat(
      "  ",
      formatC(n, width = w, flag = "-"),
      " : ",
      .fmt(.subset2(x, n)),
      "\n",
      sep = ""
    )
  invisible(x)
}
