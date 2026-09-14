#' Marker for an argument that was not supplied
#'
#' @keywords internal
#' @noRd
.missing_ <- structure(list(), class = "typed_missing")

#' Validate one argument of a typed function
#'
#' An omitted argument is validated as `NULL`, so a type that accepts `NULL`
#' makes the argument optional and anything else reports it as missing.
#'
#' @param t The argument's type.
#' @param x The supplied value, or the `.missing_` marker.
#' @param name The argument's name, used as the problem path.
#' @return The validated value, or a `typed_problems` object.
#' @keywords internal
#' @examples
#' rdantic:::.check_arg(int[1], 1, "x")
#' rdantic:::.check_arg(int[1], rdantic:::.missing_, "x")
.check_arg <- function(t, x, name) {
  s <- .spec(t)
  if (inherits(x, "typed_missing")) {
    r <- s$validate(NULL, name) # optional args may be omitted
    if (!.is_bad(r)) return(r)
    return(.bad(name, s$name, "<missing>"))
  }
  s$validate(x, name)
}

#' Validate everything passed through `...`
#'
#' `...` cannot be rebound, so its elements are checked but never coerced.
#'
#' @param t The type every element must satisfy.
#' @param dots `list(...)` from inside the function.
#' @return A list of problem records, empty when all elements pass.
#' @keywords internal
#' @examples
#' rdantic:::.check_dots(chr[1], list("a", 2))
.check_dots <- function(t, dots) {
  s <- .spec(t)
  nms <- names(dots)
  probs <- list()
  for (i in seq_along(dots)) {
    label <- if (!is.null(nms) && nzchar(nms[i])) nms[i] else sprintf("..%d", i)
    r <- s$validate(dots[[i]], label)
    if (.is_bad(r)) probs <- c(probs, unclass(r))
  }
  probs
}

#' Name a typed function for its error messages
#'
#' @param call The result of `sys.call()`.
#' @return A string such as `"greet()"`.
#' @keywords internal
#' @examples
#' rdantic:::.fn_name(quote(greet("Ada")))
#' rdantic:::.fn_name(quote((function(x) x)(1)))
.fn_name <- function(call) {
  f <- if (length(call)) call[[1]] else NULL
  if (is.name(f)) paste0(as.character(f), "()") else "<typed fn>()"
}

#' Define a typed function
#'
#' Types sit where R would put defaults, an unnamed formula `~ T` declares the
#' return type, and the last unnamed expression is the body. Arguments are
#' validated and coerced on the way in; the result is validated on the way out,
#' so a typed function can neither be called nor return the wrong thing.
#'
#' Give `...` a type to check every value passed through it -- those are checked
#' but not coerced, because `...` cannot be rebound. Every bad argument is
#' reported in one error.
#'
#' Checks are compiled once, at definition. Set
#' `options(rdantic.check = FALSE)` to skip them globally when you no longer
#' want to pay for them.
#'
#' @param ... Named arguments (`name = type`), an optional `~ type` return
#'   declaration, and exactly one unnamed expression: the body.
#' @return A function of class `typed_fn`.
#' @export
#' @seealso [primitives], and `%default%` for argument defaults.
#' @examples
#' greet <- fn(name = chr[1], greeting = chr[1] %default% "Hello", ~ chr[1], {
#'   paste0(greeting, ", ", name, "!")
#' })
#' greet
#' greet("Ada")
#' greet("Ada", "Bonjour")
#' try(greet(c("Ada", "Bob")))
#'
#' # the return value is checked too
#' half <- fn(x = int[1], ~ int[1], { x / 2 })
#' half(4)
#' try(half(3))
#'
#' # a typed `...`, and every problem at once
#' log_line <- fn(level = one_of("info", "warn"), ... = chr[1], ~ chr[1], {
#'   paste0("[", level, "] ", paste(..., collapse = " "))
#' })
#' log_line("info", "disk", "full")
#' try(log_line("debug", "disk", 3))
#'
#' # structs are types, so they work here as well
#' Money <- num[1][. >= 0]
#' Item <- struct("Item", qty = int[1][. > 0], price = Money)
#' total <- fn(i = Item, ~ Money, { i$qty * i$price })
#' total(Item(qty = 3, price = 19.99))
#' try(total(list(qty = 0, price = 19.99)))
#'
#' old <- options(rdantic.check = FALSE)
#' half(3)
#' options(old)
fn <- function(...) {
  exprs <- as.list(substitute(list(...)))[-1]
  nms <- names(exprs)
  if (is.null(nms)) nms <- rep("", length(exprs))
  env <- parent.frame()
  is_formula <- function(e)
    is.call(e) && identical(e[[1]], as.name("~")) && length(e) == 2
  arg_i <- which(nms != "")
  ret_i <- which(nms == "" & vapply(exprs, is_formula, NA))
  body_i <- setdiff(which(nms == ""), ret_i)
  if (length(body_i) != 1) stop("fn() needs exactly one body expression")
  if (length(ret_i) > 1) stop("fn() accepts one return-type formula (~ T)")

  types <- lapply(exprs[arg_i], function(e) as_type(eval(e, env)))
  names(types) <- nms[arg_i]
  ret <- if (length(ret_i)) as_type(eval(exprs[[ret_i]][[2]], env)) else
    anything

  checks <- lapply(names(types), function(n) {
    if (n == "...")
      return(bquote(
        .probs_ <- c(.probs_, .check_dots(.types_[["..."]], list(...)))
      ))
    sym <- as.name(n)
    val <- if (isTRUE(.spec(types[[n]])$has_default)) sym else
      bquote(if (missing(.(sym))) .missing_ else .(sym))
    bquote({
      .r_ <- .check_arg(.types_[[.(n)]], .(val), .(n))
      if (.is_bad(.r_)) .probs_ <- c(.probs_, unclass(.r_)) else
        .(sym) <- .r_
    })
  })

  f <- function() NULL
  formals(f) <- lapply(types, function(t) {
    s <- .spec(t)
    if (isTRUE(s$has_default)) s$default else quote(expr = )
  })
  body(f) <- bquote({
    if (isTRUE(getOption("rdantic.check", TRUE))) {
      .probs_ <- list()
      .entry(.(as.call(c(as.name("{"), checks))))
      if (length(.probs_)) .abort(.probs_, .fn_name(sys.call()))
      .result_ <- .entry(.check_arg(.ret_, .(exprs[[body_i]]), "<return>"))
      if (.is_bad(.result_)) .abort(.result_, .fn_name(sys.call()))
      .result_
    } else .(exprs[[body_i]])
  })
  fenv <- new.env(parent = env)
  fenv$.types_ <- types
  fenv$.ret_ <- ret
  # the generated body closes over the caller's environment, which cannot see
  # rdantic's namespace, so the helpers it calls travel with it
  helpers <- environment(fn)
  for (h in c(
    ".entry",
    ".abort",
    ".is_bad",
    ".check_arg",
    ".check_dots",
    ".fn_name",
    ".missing_"
  ))
    assign(h, get(h, envir = helpers), envir = fenv)
  environment(f) <- fenv
  attr(f, "types") <- types
  attr(f, "ret") <- ret
  class(f) <- c("typed_fn", "function")
  f
}

#' Print a typed function's signature
#'
#' @param x A typed function.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
#' @examples
#' print(fn(x = int[1], y = chr[1] %default% "a", ~ chr[1], { paste0(y, x) }))
print.typed_fn <- function(x, ...) {
  types <- attr(x, "types")
  args <- vapply(
    names(types),
    function(n) {
      s <- .spec(types[[n]])
      if (n == "...") return(paste0("...: ", s$name))
      paste0(
        n,
        ": ",
        s$name,
        if (isTRUE(s$has_default)) paste0(" = ", deparse1(s$default))
      )
    },
    ""
  )
  cat(
    "<fn> (",
    paste(args, collapse = ", "),
    ") -> ",
    .spec(attr(x, "ret"))$name,
    "\n",
    sep = ""
  )
  invisible(x)
}
