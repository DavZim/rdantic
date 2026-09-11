test_that("lossless coercion is applied", {
  expect_identical(int(c(1, 2)), c(1L, 2L))
  expect_identical(num(2L), 2)
  expect_identical(chr(factor("a")), "a")
  expect_identical(lgl(c(TRUE, NA)), c(TRUE, NA))
})

test_that("lossy coercion is refused", {
  expect_error(int(1.5), class = "typed_error")
  expect_error(int("3"), class = "typed_error")
  expect_error(lgl(1), class = "typed_error")
  expect_identical(problem_hint(int(1.5)), "not a whole number")
  expect_identical(problem_hint(int("3")), "strings are never parsed implicitly")
})

test_that("integer coercion respects the integer range", {
  expect_error(int(1e10), class = "typed_error")
  expect_identical(problem_hint(int(1e10)), "outside integer range; use num")
  expect_identical(int(.Machine$integer.max + 0), .Machine$integer.max)
})

test_that("a classed atomic is never silently unclassed", {
  expect_error(num(Sys.Date()), class = "typed_error")
  expect_error(int(factor("a")), class = "typed_error")
  expect_match(problem_hint(num(Sys.Date())), "never silently unclassed")
})

test_that("lists are only reshaped while parsing", {
  expect_error(chr(list("a", "b")), class = "typed_error")
  expect_identical(from_json(chr, '["a", "b"]'), c("a", "b"))
})

test_that("strict mode switches coercion off", {
  old <- options(rdantic.strict = TRUE)
  on.exit(options(old))
  expect_error(int(1), class = "typed_error")
  expect_match(problem_hint(int(1)), "rdantic.strict")
  expect_identical(int(1L), 1L)
})

test_that("anything and the null type", {
  expect_identical(anything(list(1, "a")), list(1, "a"))
  expect_null(null_t(NULL))
  expect_error(null_t(1), class = "typed_error")
})

test_that("type_of names length as part of the type", {
  expect_identical(type_of(1:3), "int[3]")
  expect_identical(type_of(1.5), "num[1]")
  expect_identical(type_of(NULL), "NULL")
  expect_identical(type_of(Sys.Date()), "date[1]")
  expect_identical(type_of(data.frame(a = 1:2)), "data.frame[2 x 1]")
})
