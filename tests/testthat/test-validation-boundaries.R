library(rdantic)

# Validation boundaries for functions, records and JSON containers.
test_that("return types and reserved names are enforced", {
  f <- fn(x = int[1], ~ int[1], { return("wrong") })
  expect_error(f(1L), class = "typed_error")
  expect_error(fn(.r_ = int[1], y = int[1], ~ int[1], { .r_ }), "reserved")
  expect_error(struct("PassArgs", .args = int[1]), "reserved")
})
test_that("invalid replacement and JSON keys are rejected", {
  Box <- struct("PassBox", value = int[1])
  x <- Box(value = 1L)
  expect_error(x["value"] <- list("wrong"), class = "typed_error")
  expect_identical(x$value, 1L)
  expect_error(from_json(frame(id = int, .extra = "forbid"),
                        '[{"id":1,"extra":2}]'), class = "typed_error")
})
test_that("nonempty maps and plain frame cells have matching schema types", {
  expect_error(list_of(int[1])(list(cpu = 1L)), class = "typed_error")
  T <- struct("PassMap", value = map_of(int[1]))
  expect_identical(as.character(to_json(T(value = list(cpu = 1L)), pretty = FALSE)),
                   '{"value":{"cpu":1}}')
  expect_identical(schema(T)$properties$value$type, "object")
  expect_identical(schema(frame(id = int))$items$properties$id$type, "integer")
})

test_that("nested functions return to their own callers", {
  f <- fn(~ int[1], {
    inner <- function() return(2L)
    inner()
    3L
  })
  expect_identical(f(), 3L)
})
test_that("returned functions remain callable", {
  maker <- fn(~ anything, { function() return(1L) })
  f <- maker()
  expect_identical(f(), 1L)
})
test_that("return without a value returns NULL", {
  f <- fn(~ anything, { return() })
  expect_null(f())
})
test_that("function-valued arguments do not control the checking engine", {
  f <- fn(isTRUE = anything, ~ int[1], { "wrong" })
  expect_error(f(function(...) FALSE), class = "typed_error")
  g <- fn(.entry = anything, ~ int[1], { 1L })
  expect_identical(g(function(...) 2L), 1L)
})
test_that("single list replacement stores one field value", {
  T <- struct("SingleReplace", value = int[1])
  x <- T(value = 1L)
  x["value"] <- list(3L)
  expect_identical(x$value, 3L)
})
test_that("unconstrained fields retain the replacement value's shape", {
  T <- struct("AnyReplace", value = anything)
  x <- T(value = 1L)
  x["value"] <- list(3L)
  expect_identical(x$value, 3L)
})
test_that("list-valued fields receive the element rather than its container", {
  T <- struct("ListReplace", value = list_of(int[1]))
  x <- T(value = list(1L))
  x["value"] <- list(list(2L, 3L))
  expect_identical(x$value, list(2L, 3L))
})
test_that("empty map fields encode JSON objects", {
  T <- struct("EmptyMap", value = map_of(int[1]))
  expect_identical(as.character(to_json(T(value = list()), pretty = FALSE)),
                   '{"value":{}}')
})
test_that("scalarizing a nullable column does not leave a vector schema", {
  cell <- schema(frame(id = int | NULL))$items$properties$id
  # The emitted row {"id":1} must be admitted by a scalar branch.
  types <- unlist(lapply(cell$anyOf, function(branch) branch$type))
  expect_true("integer" %in% types)
  expect_false("array" %in% types)
})
