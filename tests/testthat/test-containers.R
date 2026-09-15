test_that("list_of(T) validates every element and collects problems", {
  expect_identical(parse_as(list_of(int[1]), list(1, 2)), list(1L, 2L))
  expect_length(problem_paths(parse_as(list_of(int[1]), list(1, "two", 3.5))), 2)
})

test_that("list_of(T) rejects a named list; that is map_of(T)'s shape", {
  expect_error(list_of(int[1])(list(a = 1, b = 2)), class = "typed_error")
})

test_that("map_of(T) keeps names and is reported by key", {
  expect_identical(
    names(parse_as(map_of(int[1]), list(a = 1, b = 2))),
    c("a", "b")
  )
  expect_identical(
    problem_paths(parse_as(map_of(int[1]), list(a = 1, b = "x"))),
    "$b"
  )
})

test_that("map_of(T) rejects an unnamed list; that is list_of(T)'s shape", {
  expect_error(map_of(int[1])(list(1, 2)), class = "typed_error")
})

test_that("map_of(T) produces an object schema with additionalProperties", {
  s <- schema(map_of(int[1]))
  expect_identical(s$type, "object")
  expect_identical(s$additionalProperties, schema(int[1]))
})

test_that("list_of rejects things that are not lists", {
  expect_error(list_of(int)(1:3), class = "typed_error")
  expect_error(list_of(int)(data.frame(a = 1)), class = "typed_error")
})

test_that("keyed list_of returns a plain named list", {
  keyed <- list_of(cpu = int[1][. < 12], memory = int[1][. < 128] %default% 8L)
  expect_identical(keyed(list(cpu = 4)), list(cpu = 4L, memory = 8L))
  expect_false(inherits(keyed(list(cpu = 4)), "typed_instance"))
})

test_that("keyed list_of checks each key and reports missing ones", {
  keyed <- list_of(cpu = int[1][. < 12], memory = int[1][. < 128] %default% 8L)
  expect_identical(
    problem_paths(keyed(list(cpu = 16, memory = 512))),
    c("$cpu", "$memory")
  )
  expect_identical(problem_paths(keyed(list(memory = 1))), "$cpu")
})

test_that("keyed list_of handles unknown keys per .extra", {
  keyed <- list_of(cpu = int[1], memory = int[1] %default% 8L)
  expect_identical(keyed(list(cpu = 1, z = 2)), list(cpu = 1L, memory = 8L))
  strict <- list_of(cpu = int[1], .extra = "forbid")
  expect_identical(problem_paths(strict(list(cpu = 1, z = 2))), "$z")
})

test_that("keyed list_of produces an object schema", {
  keyed <- list_of(cpu = int[1], memory = int[1] %default% 8L)
  s <- schema(keyed)
  expect_identical(s$type, "object")
  expect_identical(s$required, list("cpu"))
  expect_true(s$additionalProperties)
})

test_that("list_of refuses mixed arguments", {
  expect_error(list_of(int, a = chr))
  expect_error(list_of(int, chr))
  expect_error(list_of())
})

test_that("frame validates columns", {
  roster <- frame(id = int, name = chr)
  out <- roster(data.frame(id = c(1, 2), name = c("a", "b")))
  expect_identical(out$id, 1:2)
  expect_identical(problem_paths(roster(data.frame(id = 1))), "$name")
  expect_error(roster(list(id = 1)), class = "typed_error")
})

test_that("frame can forbid undeclared columns", {
  strict <- frame(id = int, .extra = "forbid")
  expect_identical(problem_paths(strict(data.frame(id = 1L, x = 2))), "$x")
})

test_that("frame forbids undeclared keys parsed from JSON rows too", {
  strict <- frame(id = int, .extra = "forbid")
  expect_identical(
    problem_paths(from_json(strict, '[{"id":1,"extra":2}]')),
    "$extra"
  )
})

test_that("frame checks that a column fits the number of rows", {
  one <- frame(id = int[1])
  expect_match(
    problem_paths(one(data.frame(id = c(1, 2)))),
    "\\$id"
  )
})

test_that("frame parses an array of JSON objects", {
  roster <- frame(id = int, nm = chr)
  out <- from_json(roster, '[{"id": 1, "nm": "a"}, {"id": 2, "nm": "b"}]')
  expect_s3_class(out, "data.frame")
  expect_identical(out$nm, c("a", "b"))
})

test_that("a row missing a key is reported, not turned into a list column", {
  roster <- frame(id = int, nm = chr)
  expect_identical(
    problem_paths(from_json(roster, '[{"id":1},{"id":2,"nm":"b"}]')),
    "$nm"
  )
})

test_that("an empty JSON array becomes a zero-row frame", {
  out <- from_json(frame(id = int, nm = chr), "[]")
  expect_identical(nrow(out), 0L)
  expect_identical(names(out), c("id", "nm"))
})

test_that("frame's schema describes a per-row scalar cell, not a whole-column vector", {
  roster <- frame(id = int, name = chr)
  s <- schema(roster)
  expect_identical(s$items$properties$id$type, "integer")
  expect_identical(s$items$properties$name$type, "string")
})
