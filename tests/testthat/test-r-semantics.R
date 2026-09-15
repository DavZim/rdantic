library(rdantic)

test_that("checked arguments are evaluated once", {
  calls <- 0L
  f <- fn(x = int[1], ~ int[1], { x + x })
  expect_identical(f({ calls <- calls + 1L; 2 }), 4L)
  expect_identical(calls, 1L)
})

test_that("language objects and functions are passed as values", {
  f <- fn(x = anything, ~ anything, { x })
  expr <- quote(stop("must not execute"))
  expect_identical(f(expr), expr)
  callback <- function() 5L
  expect_identical(f(callback), callback)
  expect_null(f(NULL))
})

test_that("defaults and returned closures use the user's lexical scope", {
  f <- local({
    scale <- 7L
    fn(x = int[1] %default% 2L, ~ int[1], { scale * x })
  })
  expect_identical(f(), 14L)
  maker <- fn(x = int[1], ~ anything, { function(y) x + y })
  a <- maker(2)
  b <- maker(3)
  expect_identical(a(4L), 6L)
  expect_identical(b(4L), 7L)
})

test_that("dots preserve names and language values", {
  f <- fn(x = int[1], ... = anything, flag = int[1] %default% 3L,
          ~ anything, { list(x = x, dots = list(...), flag = flag) })
  expr <- quote(stop("must not execute"))
  expect_identical(f(2, code = expr, flag = 4),
                   list(x = 2L, dots = list(code = expr), flag = 4L))
  expect_identical(f(2), list(x = 2L, dots = list(), flag = 3L))
})

test_that("return visibility and cleanup belong to the user's function", {
  f <- fn(~ int[1], { invisible(2) })
  result <- withVisible(f())
  expect_identical(result$value, 2L)
  expect_false(result$visible)
  cleanups <- 0L
  clean <- function() cleanups <<- cleanups + 1L
  g <- fn(~ int[1], { on.exit(clean(), add = TRUE); return(2) })
  expect_identical(g(), 2L)
  expect_identical(cleanups, 1L)
  bad <- fn(~ int[1], { on.exit(clean(), add = TRUE); return("wrong") })
  expect_error(bad(), class = "typed_error")
  expect_identical(cleanups, 2L)
})

test_that("checked omission is normalized and unchecked omission stays missing", {
  f <- fn(x = int[1] | NULL, ~ lgl[1], { missing(x) })
  expect_false(f())
  old <- options(rdantic.check = FALSE)
  on.exit(options(old))
  expect_true(f())
  expect_false(f(1L))
})

test_that("native list selection and recycling preserve field constraints", {
  T <- struct("NativeReplace", a = int[1], b = int[1])
  x <- T(a = 1L, b = 2L)
  x[] <- list(3L, 4L)
  expect_identical(unname(unlist(to_list(x))), c(3L, 4L))
  x[c("a", "b")] <- list(5L)
  expect_identical(unname(unlist(to_list(x))), c(5L, 5L))
  x[c(TRUE, FALSE)] <- list(6L)
  expect_identical(x$a, 6L)
  x[c("a", "a")] <- list("discarded", 7L)
  expect_identical(x$a, 7L)
  before <- x
  expect_error(x[c("a", "b")] <- list(8L, "wrong"), class = "typed_error")
  expect_identical(x, before)
  expect_error(x["extra"] <- list(1L), class = "typed_error")
  expect_identical(x, before)
  expect_error(x["a"] <- NULL, class = "typed_error")
  expect_identical(x, before)
  x[character()] <- list()
  expect_identical(x, before)
})

test_that("nullable replacements retain the field and empty maps retain shape", {
  T <- struct("NullableReplace", a = int[1] | NULL)
  x <- T(a = 1L)
  x["a"] <- list(NULL)
  expect_null(x$a)
  expect_identical(names(to_list(x)), "a")
  M <- struct("NestedMaps", values = list_of(map_of(int[1])))
  expect_identical(as.character(to_json(M(values = list(list())), pretty = FALSE)),
                   '{"values":[{}]}')
  S <- frame(x = int | chr | NULL)
  expect_identical(vapply(schema(S)$items$properties$x$anyOf, function(x) x$type, ""),
                   c("integer", "string", "null"))
})
