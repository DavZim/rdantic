test_that("T[n] fixes the length", {
  expect_identical(int[3](c(1, 2, 3)), 1:3)
  expect_error(int[3](c(1, 2)), class = "typed_error")
  expect_identical(problem_hint(int[1](c(1, 2))), "length is 2, not 1")
})

test_that("T[pred] restricts elementwise", {
  expect_identical(num[. > 0](c(1, 2)), c(1, 2))
  expect_error(num[. > 0](c(1, -2)), class = "typed_error")
  expect_match(problem_hint(num[. > 0](c(1, -2, -3))), "fails at elements 2, 3")
})

test_that("length and constraints chain, and name the rule", {
  small <- int[1][0 < . & . < 10]
  expect_identical(small(7), 7L)
  expect_error(small(70), class = "typed_error")
  expect_identical(rdantic:::.spec(small)$name, "int[1][0 < . & . < 10]")
})

test_that("a failing inner type is relabelled with the outer name", {
  expect_identical(
    tryCatch(int[1](1.5), typed_error = function(e) e$problems[[1]]$expected),
    "int[1]"
  )
})

test_that("unions accept any member", {
  either <- int[1] | chr[1]
  expect_identical(either(7), 7L)
  expect_identical(either("seven"), "seven")
  expect_error(either(TRUE), class = "typed_error")
})

test_that("unions flatten and keep a single member's hint", {
  expect_length(rdantic:::.members(int | chr | NULL), 3)
  expect_match(problem_hint((int[1] | NULL)(1.5)), "whole")
})

test_that("only | is defined for types", {
  expect_error(int[1] + chr[1], "not defined for types")
})

test_that("opt makes a type optional", {
  expect_null(opt(int[1])(NULL))
  expect_identical(opt(int[1])(3), 3L)
})

test_that("no_na rejects missing values", {
  expect_identical(no_na(int)(1L), 1L)
  expect_error(no_na(int)(c(1L, NA)), class = "typed_error")
  expect_identical(problem_hint(no_na(int)(c(1L, NA))), "contains NA")
})

test_that("one_of compares with types in mind", {
  expect_identical(one_of("a", "b")("b"), "b")
  expect_error(one_of("a", "b")("z"), class = "typed_error")
  expect_error(one_of("1", "2")(1), class = "typed_error")
  expect_identical(one_of(1L, 2L)(1), 1L)
})

test_that("%default% validates the default where it is written", {
  role <- one_of("admin", "user") %default% "user"
  expect_true(isTRUE(rdantic:::.spec(role)$has_default))
  expect_identical(rdantic:::.spec(role)$default, "user")
  expect_error(int[1] %default% "three", class = "typed_error")
})

test_that("a default on either side belongs to the whole union", {
  t <- int[1] | NULL %default% NULL
  expect_true(isTRUE(rdantic:::.spec(t)$has_default))
  expect_null(rdantic:::.spec(t)$default)
})

test_that("desc()/%doc% attach a schema description", {
  expect_identical(schema(desc(chr[1], "a name"))$description, "a name")
  expect_identical(schema(chr[1] %doc% "a name")$description, "a name")
  expect_error(chr[1] %doc% c("a", "b"))
})

test_that("descriptions trim blank edge lines and common indentation", {
  description <- "\n    First line.\n      Indented detail.\n    Last line.\n"
  expect_identical(
    schema(chr[1] %doc% description)$description,
    "First line.\n  Indented detail.\nLast line."
  )
})

test_that("desc() replaces, rather than duplicates, .refined()'s description", {
  s <- schema(num[. > 0] %doc% "must be positive")
  expect_identical(s$description, "must be positive")
  expect_length(s$description, 1)
})

test_that("union schema compacts to a type array when every member is a bare scalar", {
  expect_identical(schema(opt(chr[1]))$type, c("string", "null"))
  expect_null(schema(opt(chr[1]))$anyOf)
})

test_that("union schema falls back to anyOf for structured members", {
  s <- schema(chr | NULL)
  expect_identical(s$anyOf, list(list(type = "array", items = list(type = "string")), list(type = "null")))
})
