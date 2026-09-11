test_that("parse_as validates and coerces", {
  expect_identical(parse_as(int, c(1, 2)), c(1L, 2L))
  expect_error(parse_as(int[1], "3"), class = "typed_error")
})

test_that("try_parse reports instead of throwing", {
  r <- try_parse(int[1], "x")
  expect_false(r$ok)
  expect_null(r$value)
  expect_length(r$problems, 1)
  expect_identical(r$problems[[1]]$expected, "int[1]")

  ok <- try_parse(int[1], 1)
  expect_true(ok$ok)
  expect_identical(ok$value, 1L)
  expect_length(ok$problems, 0)
})

test_that("try_parse also catches type-level errors", {
  r <- try_parse(ref("NeverDefinedModel"), list())
  expect_false(r$ok)
})

test_that("is_valid is the predicate form", {
  expect_true(is_valid(int[1], 1))
  expect_false(is_valid(int[1], "a"))
  expect_true(is_valid(chr, letters))
})

test_that("as_type accepts types, NULL and model names", {
  expect_identical(as_type(int), int)
  expect_identical(rdantic:::.spec(as_type(NULL))$name, "NULL")
  expect_identical(rdantic:::.spec(as_type("Whatever"))$name, "Whatever")
  expect_error(as_type(42))
})

test_that("new_type builds a working type", {
  even <- new_type(
    "even",
    validate = function(x, path) {
      if (is.numeric(x) && all(x %% 2 == 0)) x else
        rdantic:::.bad(path, "even", type_of(x))
    },
    schema = function() list(type = "integer", multipleOf = 2)
  )
  expect_identical(even(c(2, 4)), c(2, 4))
  expect_error(even(3), class = "typed_error")
  expect_identical(schema(even)$multipleOf, 2)
})

test_that("type_from wraps a predicate", {
  hex <- type_from("hex", function(x) is.character(x) && all(grepl("^#", x)))
  expect_identical(hex("#fff"), "#fff")
  expect_error(hex("green"), class = "typed_error")
})

test_that("type_from can coerce", {
  port <- type_from(
    "port",
    function(x) is.integer(x) && length(x) == 1,
    coerce = function(x) as.integer(x),
    json = "integer"
  )
  expect_identical(port(8080), 8080L)
})

test_that("schema follows the declared shape", {
  expect_identical(schema(int)$type, "array")
  expect_identical(schema(int[1])$type, "integer")
  expect_identical(schema(one_of("a", "b"))$enum, list("a", "b"))
})

test_that("printing a type shows its name and default", {
  expect_output(print(int[1]), "<type> int[1]", fixed = TRUE)
  expect_output(print(one_of("a") %default% "a"), "default: \"a\"", fixed = TRUE)
})
