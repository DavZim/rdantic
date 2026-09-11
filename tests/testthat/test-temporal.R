test_that("date accepts Date and ISO-8601 text", {
  expect_identical(date("2024-01-02"), as.Date("2024-01-02"))
  expect_identical(date(as.Date("2024-01-02")), as.Date("2024-01-02"))
  expect_identical(parse_as(date, c("2024-01-01", "2024-06-30")),
                   as.Date(c("2024-01-01", "2024-06-30")))
})

test_that("date never parses silently to NA", {
  expect_error(date("02/01/2024"), class = "typed_error")
  expect_identical(problem_hint(date("02/01/2024")), "expected YYYY-MM-DD")
  expect_error(date(19860), class = "typed_error")
})

test_that("datetime parses both ISO layouts", {
  expect_s3_class(datetime("2024-01-02T03:04:05"), "POSIXct")
  expect_s3_class(datetime("2024-01-02 03:04:05"), "POSIXct")
  expect_error(datetime("nope"), class = "typed_error")
})

test_that("fct coerces character into the declared levels", {
  size <- fct("a", "b")
  expect_identical(size("b"), factor("b", levels = c("a", "b")))
  expect_identical(levels(size(c("b", "a"))), c("a", "b"))
  expect_error(size("z"), class = "typed_error")
  expect_match(problem_hint(size("z")), "levels are a, b")
})

test_that("fct() with no levels accepts any factor", {
  expect_identical(fct()(factor("x")), factor("x"))
  expect_error(fct()("x"), class = "typed_error")
})

test_that("temporal types carry a JSON Schema format", {
  expect_identical(schema(date)$items$format, "date")
  expect_identical(schema(datetime)$items$format, "date-time")
  expect_identical(schema(fct("a", "b"))$items$enum, list("a", "b"))
})
