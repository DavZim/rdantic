#' Is the S7 package available?
#'
#' S7 is a suggested dependency: everything here is reachable only through a
#' value that S7 itself created, so the check can never fail in the middle of
#' a validation.
#'
#' @return `TRUE` when S7 can be loaded.
#' @keywords internal
#' @examples
#' rdantic:::.has_s7()
.has_s7 <- function() requireNamespace("S7", quietly = TRUE)

#' Require S7
#'
#' @param what The function that needs it, for the message.
#' @return Nothing; throws when the package is missing.
#' @keywords internal
#' @examples
#' rdantic:::.need_s7("s7_type()")
.need_s7 <- function(what)
  if (!.has_s7()) stop(what, " needs the S7 package", call. = FALSE)

#' Is this an S7 class object?
#'
#' @param x Any R value.
#' @return `TRUE` for the object `S7::new_class()` returns.
#' @keywords internal
#' @examples
#' rdantic:::.is_s7_class(int)
.is_s7_class <- function(x) inherits(x, "S7_class")

#' Is this an instance of an S7 class?
#'
#' A class object is itself an `S7_object`, so it has to be excluded.
#'
#' @param x Any R value.
#' @return `TRUE` for an S7 instance.
#' @keywords internal
#' @examples
#' rdantic:::.is_s7_object(1)
.is_s7_object <- function(x)
  inherits(x, "S7_object") && !inherits(x, "S7_class")

#' The class name of an S7 class
#'
#' @param cls An S7 class.
#' @return A single string.
#' @keywords internal
#' @examples
#' if (requireNamespace("S7", quietly = TRUE))
#'   rdantic:::.s7_name(S7::new_class("Blip"))
.s7_name <- function(cls) {
  n <- attr(cls, "name")
  if (is.null(n)) "S7_object" else n
}

#' Translate an S7 property class into a type
#'
#' S7 describes a property's class; rdantic describes its shape as well. The
#' mapping keeps what transfers -- the base types, `Date`, `POSIXct`, unions
#' and nested S7 classes -- and falls back to [anything] rather than inventing
#' a constraint S7 never made.
#'
#' @param cl A property class: an S7 base class, S3 class, union, class object
#'   or `NULL`.
#' @return A type.
#' @keywords internal
#' @examples
#' if (requireNamespace("S7", quietly = TRUE))
#'   rdantic:::.s7_prop_type(S7::class_character)
.s7_prop_type <- function(cl) {
  if (is.null(cl)) return(anything)
  if (.is_s7_class(cl)) return(s7_type(cl))
  if (inherits(cl, "S7_union"))
    return(Reduce(
      .union,
      lapply(
        unclass(cl)$classes,
        function(m) if (is.null(m)) null_t else .s7_prop_type(m)
      )
    ))
  if (inherits(cl, "S7_base_class"))
    return(switch(
      unclass(cl)$class,
      integer = int,
      double = num,
      character = chr,
      logical = lgl,
      list = list_of(anything),
      anything
    ))
  if (inherits(cl, "S7_S3_class"))
    return(switch(
      unclass(cl)$class[1],
      Date = date,
      POSIXct = datetime,
      data.frame = .s7_data_frame(),
      anything
    ))
  anything
}

#' An unconstrained data-frame type for S7 properties
#'
#' @return A type accepting any data frame and JSON arrays of row objects.
#' @keywords internal
#' @noRd
.s7_data_frame <- function()
  new_type(
    "data.frame",
    validate = function(x, path) {
      if (is.data.frame(x)) return(x)
      if (.ctx$parsing && is.list(x)) {
        y <- tryCatch(
          jsonlite::fromJSON(jsonlite::toJSON(x, auto_unbox = TRUE)),
          error = function(e) NULL
        )
        if (is.data.frame(y)) return(y)
      }
      .bad(path, "data.frame", .got(x))
    },
    schema = function()
      list(type = "array", items = list(type = "object"))
  )

#' The typed fields of an S7 class
#'
#' A class built by [as_s7_class()] carries the struct it came from, so a
#' round trip keeps the original field types instead of the erased
#' `class_any` the properties were declared with. Otherwise the property
#' classes are translated one by one. A property is optional exactly when it
#' declares a `default`, which is the same rule `%default%` follows.
#'
#' A property with a `getter` and no `setter` is computed, so it is not a
#' field: nothing can supply it, and requiring it would make every such class
#' impossible to parse.
#'
#' @param cls An S7 class.
#' @return A named list of types, in declaration order.
#' @keywords internal
#' @examples
#' if (requireNamespace("S7", quietly = TRUE))
#'   names(rdantic:::.s7_fields(
#'     S7::new_class("Blop", properties = list(n = S7::class_double))
#'   ))
.s7_fields <- function(cls) {
  origin <- attr(cls, "rdantic_struct")
  if (!is.null(origin)) return(.spec(origin)$fields)
  props <- attr(cls, "properties")
  settable <- vapply(
    props,
    function(p) is.null(p$getter) || !is.null(p$setter),
    NA
  )
  lapply(props[settable], function(p) {
    t <- .s7_prop_type(p$class)
    d <- p$default
    # a quoted default is S7's business: it is evaluated per instance
    if (is.language(d)) {
      s <- .spec(t)
      s$s7_supplies_default <- TRUE
      .rebuild(s)
    } else if (is.null(d)) t else t %default% d
  })
}

#' Use an S7 class as a type
#'
#' The class becomes an ordinary rdantic type: it can be a struct field, an
#' argument of [fn()], the element type of [list_of()], and it parses a plain
#' list -- so [from_json()] builds real S7 objects, property by property, with
#' every problem reported under its path.
#'
#' Property classes are translated where they carry over (`class_integer`,
#' `class_double`, `class_character`, `class_logical`, `class_list`,
#' `class_Date`, `class_POSIXct`, unconstrained `class_data.frame` values,
#' unions, and nested S7 classes); anything else validates as [anything]. A
#' property is required unless it declares a `default`. Expression-valued
#' defaults remain S7's responsibility and are evaluated for each instance.
#' Computed properties (a getter without a setter) are not input fields.
#'
#' [as_type()] calls this for you, so an S7 class can be written directly
#' wherever a type is expected.
#'
#' @param cls An S7 class, as returned by `S7::new_class()`.
#' @return A type.
#' @export
#' @seealso [as_s7_class()] for the other direction.
#' @examples
#' if (requireNamespace("S7", quietly = TRUE)) {
#'   library(S7)   # for `@`, which S7 supplies on R < 4.3
#'
#'   Pin <- new_class("Pin", properties = list(
#'     lat = class_double,
#'     lon = class_double
#'   ))
#'
#'   s7_type(Pin)
#'   schema(Pin)
#'
#'   # an S7 class used as a struct field
#'   Trip <- struct("Trip", label = chr[1], start = Pin)
#'   t <- from_json(Trip, '{"label": "home", "start": {"lat": 1, "lon": 2}}')
#'   t$start
#'
#'   try(from_list(Trip, list(label = "home", start = list(lat = "x", lon = 2))))
#' }
s7_type <- function(cls) {
  .need_s7("s7_type()")
  if (!.is_s7_class(cls))
    stop("s7_type() needs an S7 class, as returned by S7::new_class()")
  name <- .s7_name(cls)
  label <- paste0("<", name, ">")
  fields <- .s7_fields(cls)
  s7_defaults <- names(fields)[vapply(
    fields,
    function(f) isTRUE(.spec(f)$s7_supplies_default),
    NA
  )]
  origin <- attr(cls, "rdantic_struct")
  extra <- if (is.null(origin)) "ignore" else .spec(origin)$extra
  new_type(
    name,
    validate = function(x, path) {
      if (.is_s7_object(x))
        return(if (S7::S7_inherits(x, cls)) x else .bad(path, label, .got(x)))
      # a struct instance is a list, but it is not this class's shape
      if (inherits(x, "typed_instance")) return(.bad(path, label, .got(x)))
      if (!is.list(x) || is.data.frame(x)) return(.bad(path, label, .got(x)))
      omitted_defaults <- setdiff(s7_defaults, names(x))
      vals <- .check_fields(fields[setdiff(names(fields), omitted_defaults)], x, path, extra, label)
      if (.is_bad(vals)) return(vals)
      do.call(cls, vals[!vapply(vals, is.null, NA)])
    },
    # a generated class keeps its struct's schema, so the description survives
    schema = if (!is.null(origin)) .spec(origin)$schema else
      function()
        list(
          type = "object",
          title = name,
          properties = lapply(
            stats::setNames(nm = .nm(fields)),
            function(n) .spec(fields[[n]])$schema()
          ),
          required = as.list(setdiff(.required_fields(fields), s7_defaults)),
          additionalProperties = FALSE
        ),
    s7_class = cls,
    s7_fields = fields
  )
}

#' Where S7 classes made from structs are kept
#'
#' Keyed by name and field signature, so converting the same struct twice
#' yields the same class and `S7::S7_inherits()` keeps working.
#'
#' @keywords internal
#' @noRd
.s7_cache <- new.env(parent = emptyenv())

#' Validate a property the way rdantic validates a field
#'
#' An S7 `validator` may only return a message, so it can neither coerce nor
#' raise a `typed_error`. A `setter` can do both, which is why every property
#' gets one.
#'
#' @param field The property name.
#' @param t The field's type.
#' @param owner The class name, for the error's first line.
#' @param optional Whether the field has a default.
#' @return A `function(self, value)` suitable for `S7::new_property()`.
#' @keywords internal
#' @noRd
.s7_setter <- function(field, t, owner, optional) {
  force(field)
  force(t)
  force(owner)
  force(optional)
  path <- paste0("@", field)
  function(self, value) {
    r <- .entry(.spec(t)$validate(value, path))
    if (.is_bad(r)) {
      if (is.null(value) && !optional)
        r <- .bad(path, .spec(t)$name, "<missing>")
      .abort(r, paste0("<", owner, ">"))
    }
    S7::`prop<-`(self, field, check = FALSE, value = r)
  }
}

#' Decide what a generated class inherits and what it declares itself
#'
#' S7 keeps a parent's property definition and silently ignores a
#' redeclaration, so a narrower type on an inherited field would never run.
#' Flattening is the honest answer: the type is enforced, the S7 inheritance
#' is not, and the caller is told.
#'
#' @param name The class being built.
#' @param fields Every field it has, inherited ones included.
#' @param parent_cls The parent S7 class, or `NULL`.
#' @return A list of `parent` and the `own` fields to declare.
#' @keywords internal
#' @noRd
.s7_split <- function(name, fields, parent_cls) {
  if (is.null(parent_cls))
    return(list(parent = S7::S7_object, own = fields))
  inherited <- .s7_fields(parent_cls)
  shared <- intersect(names(inherited), names(fields))
  retyped <- shared[vapply(
    shared,
    function(n)
      !identical(.spec(inherited[[n]])$name, .spec(fields[[n]])$name),
    NA
  )]
  if (length(retyped)) {
    warning(
      sprintf(
        "<%s> retypes %s, which S7 cannot override on a parent class; the S7 class is flattened and does not inherit from <%s>",
        name,
        paste0("`", retyped, "`", collapse = ", "),
        .s7_name(parent_cls)
      ),
      call. = FALSE
    )
    return(list(parent = S7::S7_object, own = fields))
  }
  list(
    parent = parent_cls,
    own = fields[setdiff(names(fields), names(inherited))]
  )
}

#' Build the S7 class for a set of typed fields
#'
#' @param name The class name.
#' @param own The fields to declare as properties.
#' @param parent The parent S7 class.
#' @param origin The struct the class came from, kept on it so the field types
#'   survive the trip back through [s7_type()].
#' @return An S7 class.
#' @keywords internal
#' @noRd
.s7_build <- function(name, own, parent, origin) {
  props <- lapply(stats::setNames(nm = names(own)), function(n) {
    fs <- .spec(own[[n]])
    S7::new_property(
      S7::class_any,
      default = if (isTRUE(fs$has_default)) fs$default,
      setter = .s7_setter(n, own[[n]], name, isTRUE(fs$has_default))
    )
  })
  # package = NULL: the class belongs to the caller's struct, not to rdantic
  cls <- S7::new_class(name, parent = parent, package = NULL, properties = props)
  attr(cls, "rdantic_struct") <- origin
  cls
}

#' Define an S7 class with rdantic field types
#'
#' [struct()] with an S7 class as the result: the fields are declared exactly
#' as they would be for a struct, and what comes back is a real S7 class whose
#' properties validate -- and coerce -- through those types on construction and
#' on `@<-`, raising the usual `typed_error`.
#'
#' Unlike [struct()], the name is *not* registered, so [ref()] and `opt("Name")`
#' will not resolve it: a name in that registry means something that builds
#' instances, and this builds S7 objects. Pass the class itself instead -- it
#' is a value, and a type.
#'
#' @param .name The class's name, as a single string.
#' @param ... Named fields, one type each.
#' @param .description The JSON Schema `"description"` for [schema()], or
#'   `NULL` to omit it.
#' @param .parent An S7 class to inherit from, or `NULL`. Its properties are
#'   inherited as typed fields.
#' @param .extra `"forbid"` rejects unknown keys when parsing a list into the
#'   class; the default `"ignore"` drops them.
#' @return An S7 class.
#' @export
#' @seealso [as_s7_class()] to convert an existing struct, [struct()] for the
#'   plain-list equivalent.
#' @examples
#' if (requireNamespace("S7", quietly = TRUE)) {
#'   library(S7)   # for `@`, which S7 supplies on R < 4.3
#'
#'   Account <- s7_struct("Account",
#'     id     = int[1][. > 0],
#'     email  = chr[1][grepl("@", ., fixed = TRUE)],
#'     credit = num[1][. >= 0] %default% 0
#'   )
#'
#'   a <- Account(id = 1, email = "ada@example.org")
#'   a@credit
#'
#'   a@credit <- 10L   # coerced to double, exactly as rdantic would
#'   typeof(a@credit)
#'
#'   try(a@id <- 0)
#'   try(Account(id = 1))
#'
#'   # it is a type, so it parses, validates and describes itself
#'   from_json(Account, '{"id": 2, "email": "bob@example.org"}')
#'   schema(Account)$required
#'
#'   Premium <- s7_struct("Premium", tier = one_of("gold", "silver"),
#'                        .parent = Account)
#'   S7_inherits(Premium(id = 1, email = "a@b.org", tier = "gold"), Account)
#' }
s7_struct <- function(
  .name,
  ...,
  .description = NULL,
  .parent = NULL,
  .extra = c("ignore", "forbid")
) {
  .need_s7("s7_struct()")
  if (!is.character(.name) || length(.name) != 1)
    stop('s7_struct() needs exactly one unnamed name: s7_struct("User", ...)')
  if (!is.null(.parent) && !.is_s7_class(.parent))
    stop("s7_struct() needs .parent to be an S7 class, or NULL")
  fields <- if (is.null(.parent)) list() else .s7_fields(.parent)
  own <- .struct_fields(list(...))
  fields[names(own)] <- own # a child may retype a parent's property
  origin <- .struct_ctor(
    .name,
    fields,
    if (is.null(.parent)) character() else .s7_name(.parent),
    .description,
    match.arg(.extra)
  )
  split <- .s7_split(.name, fields, .parent)
  .s7_build(.name, split$own, split$parent, origin)
}

#' Turn a struct into an S7 class
#'
#' The properties are the struct's fields and every one of them validates
#' through its rdantic type on construction and on `@<-`, coercing where
#' rdantic would coerce and raising the same `typed_error`. Use it to hand an
#' rdantic-checked record to code that expects S7 -- `S7::prop()`, `@`, and
#' S7 generics all work on the result.
#'
#' Properties are declared `S7::class_any`, because the real constraint is the
#' rdantic type, not S7's class check. A struct made with [extend()] becomes
#' an S7 subclass of its parent's class; if it retypes one of the parent's
#' fields the hierarchy is flattened with a warning, because S7 keeps the
#' parent's property definition and the narrower type would be ignored.
#'
#' Reach for [s7_struct()] instead when there is no struct to convert.
#'
#' @param x A struct, or anything [as_type()] accepts that resolves to one.
#' @param .name The class name; defaults to the struct's.
#' @return An S7 class.
#' @export
#' @seealso [s7_struct()], [s7_type()] for the other direction.
#' @examples
#' if (requireNamespace("S7", quietly = TRUE)) {
#'   library(S7)   # for `@`, which S7 supplies on R < 4.3
#'
#'   Account <- struct("Account",
#'     id     = int[1][. > 0],
#'     email  = chr[1][grepl("@", ., fixed = TRUE)],
#'     credit = num[1][. >= 0] %default% 0
#'   )
#'   S7Account <- as_s7_class(Account)
#'
#'   a <- S7Account(id = 1, email = "ada@example.org")
#'   a@credit
#'
#'   a@credit <- 10L   # coerced to double, exactly as rdantic would
#'   typeof(a@credit)
#'
#'   try(a@id <- 0)
#'   try(S7Account(id = 1))
#' }
as_s7_class <- function(x, .name = NULL) {
  .need_s7("as_s7_class()")
  t <- as_type(x)
  s <- .spec(t)
  if (is.null(s$fields))
    stop("as_s7_class() needs a struct, not ", s$name)
  name <- if (is.null(.name)) s$name else .name
  key <- paste0(name, "\r", .sig(s))
  hit <- get0(key, envir = .s7_cache, inherits = FALSE)
  if (!is.null(hit)) return(hit)

  pctor <- if (length(s$parents))
    get0(s$parents[1], envir = .registry, inherits = FALSE)
  split <- .s7_split(
    name,
    s$fields,
    if (is.null(pctor)) NULL else as_s7_class(pctor)
  )
  cls <- .s7_build(name, split$own, split$parent, t)
  assign(key, cls, envir = .s7_cache)
  cls
}
