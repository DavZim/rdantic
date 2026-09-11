#' Where models register themselves by name
#'
#' Only [ref()] reads it, and only once per reference: instances carry their own
#' spec, so redefining a model cannot retype values that already exist.
#'
#' @keywords internal
#' @noRd
.registry <- new.env(parent = emptyenv())

#' A model's signature, for spotting redefinitions
#'
#' @param spec A model spec.
#' @return A single string.
#' @keywords internal
#' @examples
#' rdantic:::.sig(rdantic:::.spec(model("SigDemo", x = int[1])))
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

#' Refer to a model by name
#'
#' Lets a model refer to itself, or to one that is defined later. The name is
#' resolved on first use and then cached, so redefining a model in a live
#' session cannot silently retype the models that already refer to it.
#'
#' @param name The model's name.
#' @return A type.
#' @export
#' @seealso [opt()] for the common `ref(name) | NULL` case.
#' @examples
#' Node <- model("Node", value = int[1], next_ = opt("Node"))
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
            'unknown model `%s`: define it with model("%s", ...) before validating',
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
#' itself a type, so models nest and can be used anywhere a type can. Instances
#' are plain named lists with a class, which means they copy on modify like
#' every other R value.
#'
#' Where a model is expected, a plain list is parsed into it. That is what makes
#' JSON input work with no separate JSON mode.
#'
#' @param ... The model's name as the single unnamed string, then named fields,
#'   one type each. `.extra = "forbid"` rejects unknown keys when parsing a
#'   list; `.parents` is set by [extend()] and is not usually written by hand.
#' @return A constructor of class `typed_model`, which is also a type.
#' @export
#' @seealso [extend()], [partial()], [list_of()], [fields()]
#' @examples
#' Account <- model("Account",
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
#' try(from_list(model("Shut", x = int[1], .extra = "forbid"), list(x = 1, y = 2)))
model <- function(...) {
  # model("Name", field = T, ...): the single unnamed string is the name, so no
  # formal argument can ever collide with a field (e.g. a field called `name`).
  args <- list(...)
  nms <- names(args)
  if (is.null(nms)) nms <- rep("", length(args))
  is_name <- nms == "" &
    vapply(args, function(a) is.character(a) && length(a) == 1, NA)
  if (sum(is_name) != 1)
    stop('model() needs exactly one unnamed name: model("User", ...)')
  name <- args[[which(is_name)]]
  parents <- if (".parents" %in% nms) args[[".parents"]] else character()
  extra <- if (".extra" %in% nms)
    match.arg(args[[".extra"]], c("ignore", "forbid")) else "ignore"
  fields <- args[!is_name & !nms %in% c(".parents", ".extra")]
  if (length(fields) && any(!nzchar(names(fields))))
    stop("all model fields must be named")
  fields <- lapply(fields, as_type)
  spec <- list(name = name, fields = fields, parents = parents, extra = extra)
  spec$validate <- function(x, path) {
    if (inherits(x, name)) return(x)
    # instances are lists, so a *different* model must not be parsed as one
    if (inherits(x, "typed_instance"))
      return(.bad(path, paste0("<", name, ">"), .got(x)))
    if (is.list(x) && !is.data.frame(x)) return(.new_instance(spec, x, path))
    .bad(path, paste0("<", name, ">"), .got(x))
  }
  spec$schema <- function() {
    list(
      type = "object",
      title = name,
      properties = lapply(fields, function(f) .spec(f)$schema()),
      required = as.list(.required_fields(fields)),
      additionalProperties = FALSE
    )
  }
  ctor <- .make_model(spec)
  # scoped, so the previous constructor is not captured by this model's closures
  local({
    prev <- get0(name, envir = .registry, inherits = FALSE)
    if (!is.null(prev) && !identical(.sig(.spec(prev)), .sig(spec)))
      warning(
        sprintf(
          "model `%s` redefined; values and refs made earlier keep the previous definition",
          name
        ),
        call. = FALSE
      )
  })
  assign(name, ctor, envir = .registry)
  ctor
}

#' Compile a model spec into a constructor
#'
#' The constructor gets one formal per field, so `args()`, autocomplete and
#' R's own "unused argument" error all work before any validation runs.
#'
#' @param spec A model spec.
#' @return A constructor of class `typed_model`.
#' @keywords internal
#' @examples
#' args(rdantic:::.make_model(rdantic:::.spec(model("MkDemo", a = int[1], b = chr[1]))))
.make_model <- function(spec) {
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
      r <- .new_instance(.spec_, .args, "")
      if (.is_bad(r)) .abort(r, .spec_$name)
      r
    })
  ))
  env <- new.env(parent = environment(.make_model))
  env$.spec_ <- spec
  environment(ctor) <- env
  attr(ctor, "spec") <- spec
  class(ctor) <- c("typed_model", "type")
  ctor
}

#' Validate arguments and build an instance
#'
#' @param spec A model spec.
#' @param args The supplied named values.
#' @param path The path prefix for problem records.
#' @return An instance, or a `typed_problems` object.
#' @keywords internal
#' @examples
#' rdantic:::.new_instance(rdantic:::.spec(model("NewDemo", a = int[1])), list(a = 1), "")
.new_instance <- function(spec, args, path) {
  vals <- .check_fields(
    spec$fields,
    args,
    path,
    spec$extra,
    paste0("<", spec$name, ">")
  )
  if (.is_bad(vals)) return(vals)
  .bind_instance(spec, vals)
}

#' Wrap validated values as an instance
#'
#' Instances are plain lists: copy-on-modify like every other R value, cheap to
#' build, and `identical()`, `saveRDS()` and `str()` all behave.
#'
#' @param spec A model spec.
#' @param vals The validated values.
#' @return An object of class `c(name, parents, "typed_instance")`.
#' @keywords internal
#' @examples
#' rdantic:::.bind_instance(rdantic:::.spec(model("BindDemo", a = int[1])), list(a = 1L))
.bind_instance <- function(spec, vals)
  structure(
    vals[names(spec$fields)],
    class = c(spec$name, spec$parents, "typed_instance"),
    spec = spec
  )

#' Field names of a model or an instance
#'
#' @param x A model, an instance, or anything [as_type()] accepts.
#' @return A character vector, in declaration order.
#' @export
#' @examples
#' Pt <- model("Pt", x = num[1], y = num[1])
#' fields(Pt)
#' fields(Pt(x = 1, y = 2))
fields <- function(x) {
  s <- if (inherits(x, "typed_instance")) attr(x, "spec") else .spec(as_type(x))
  names(s$fields)
}

#' Read a field, without partial matching
#'
#' @param x An instance.
#' @param i A field name, or a position.
#' @return The field's value.
#' @keywords internal
#' @examples
#' rdantic:::.get_field(model("GetDemo", a = int[1])(a = 1), "a")
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
#' Card <- model("Card", holder = chr[1], number = chr[1])
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
#' rdantic:::.set_field(model("SetDemo", a = int[1])(a = 1), "a", 2)
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
#' Job <- model("Job", state = one_of("queued", "done"), tries = int[1])
#' j <- Job(state = "queued", tries = 0)
#' j$state <- "done"
#' j$state
#' try(j$state <- "exploded")
#' try(j$stat <- "done")
`$<-.typed_instance` <- function(x, name, value) .set_field(x, name, value)

#' @rdname instance-set
#' @export
`[[<-.typed_instance` <- function(x, i, value) .set_field(x, i, value)

#' Parse a plain list into a model
#'
#' The list-shaped counterpart of the constructor: unknown keys are ignored
#' unless the model was declared with `.extra = "forbid"`, and nested lists are
#' parsed into nested models.
#'
#' @param model A model, or anything [as_type()] accepts.
#' @param x A named list.
#' @return An instance.
#' @export
#' @seealso [from_json()], [try_parse()]
#' @examples
#' Msg <- model("Msg", topic = chr[1], size = int[1])
#' from_list(Msg, list(topic = "orders", size = 12))
#' from_list(Msg, list(topic = "orders", size = 12, extra = "ignored"))
#' try(from_list(Msg, list(topic = "orders")))
from_list <- function(model, x) .entry(parse_as(model, x), parsing = TRUE)

#' Subclass a model
#'
#' The child gets the parent's fields plus its own, inherits the parent's class
#' -- so it is accepted wherever the parent is -- and may retype a parent field
#' by repeating its name.
#'
#' @param .parent The model to extend.
#' @param ... The subclass's name as the single unnamed string, then extra or
#'   replacement fields.
#' @return A constructor of class `typed_model`.
#' @export
#' @seealso [model()], [partial()]
#' @examples
#' Animal <- model("Animal", name = chr[1], legs = int[1] %default% 4L)
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
  ps <- .spec(.parent)
  args <- list(...)
  nms <- names(args)
  if (is.null(nms)) nms <- rep("", length(args))
  name <- args[[which(nms == "")[1]]]
  fields <- ps$fields
  added <- lapply(args[nms != ""], as_type)
  fields[names(added)] <- added # a child may retype a parent's field
  do.call(
    model,
    c(
      list(name),
      fields,
      list(.parents = c(ps$name, ps$parents), .extra = ps$extra)
    )
  )
}

#' Make every field of a model optional
#'
#' For PATCH-shaped input, where only the supplied keys mean anything. Defaults
#' are dropped as well as requirements, so "not supplied" stays distinguishable
#' from "set to the default".
#'
#' @param .parent The model to weaken.
#' @param .name The new model's name.
#' @return A constructor of class `typed_model`.
#' @export
#' @seealso [model()], [extend()]
#' @examples
#' Post <- model("Post", title = chr[1], body = chr[1], draft = lgl[1] %default% TRUE)
#' PostPatch <- partial(Post)
#' PostPatch
#'
#' patch <- PostPatch(title = "New title")
#' patch$title
#' patch$draft          # NULL, not the default
partial <- function(.parent, .name = paste0("Partial", .spec(.parent)$name)) {
  fields <- lapply(.spec(.parent)$fields, function(f) {
    s <- .spec(f)
    if (!isTRUE(s$has_default)) return(f | NULL)
    s$has_default <- NULL
    s$default <- NULL
    .rebuild(s) | NULL
  })
  do.call(model, c(list(.name), fields))
}

#' Print a model
#'
#' @param x A model.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
#' @examples
#' print(model("PrintDemo", id = int[1], tag = chr[1] %default% "none"))
print.typed_model <- function(x, ...) {
  s <- .spec(x)
  w <- max(nchar(names(s$fields)))
  cat("<model> ", s$name, "\n", sep = "")
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
  if (inherits(v, "typed_instance")) paste0("<", class(v)[1], ">") else if (
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
#' Box <- model("Box", label = chr[1], items = list_of(chr[1]))
#' print(Box(label = "tools", items = list("hammer", "nail")))
print.typed_instance <- function(x, ...) {
  f <- fields(x)
  w <- max(nchar(f))
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
