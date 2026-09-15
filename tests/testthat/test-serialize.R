mk_json_struct <- function() {
  struct(
    "JDoc",
    id = int[1],
    tags = chr,
    when = date[1],
    roster = frame(id = int, nm = chr)
  )
}

mk_doc <- function() {
  mk_json_struct()(
    id = 1,
    tags = "a",
    when = as.Date("2024-01-01"),
    roster = data.frame(id = 1:2, nm = c("a", "b"))
  )
}

test_that("to_list unwraps nested instances", {
  Pin <- struct("JPin", lat = num[1], lon = num[1])
  Trip <- struct("JTrip", from = Pin, to = Pin)
  out <- to_list(Trip(from = Pin(lat = 1, lon = 2), to = Pin(lat = 3, lon = 4)))
  expect_identical(out, list(from = list(lat = 1, lon = 2), to = list(lat = 3, lon = 4)))
  expect_identical(as.list(Pin(lat = 1, lon = 2)), list(lat = 1, lon = 2))
})

test_that("to_json unboxes exactly what the type calls a scalar", {
  txt <- as.character(to_json(mk_doc(), pretty = FALSE))
  expect_match(txt, '"id":1', fixed = TRUE)
  expect_match(txt, '"tags":["a"]', fixed = TRUE)
  expect_match(txt, '"when":"2024-01-01"', fixed = TRUE)
})

test_that("a keyed list serialises as an object with per-key types", {
  keyed <- list_of(cpu = int[1], memory = int[1] %default% 8L)
  expect_identical(
    as.character(to_json(keyed(list(cpu = 4L)), pretty = FALSE)),
    '{"cpu":4,"memory":8}'
  )
})

test_that("a map_of() field serialises as an object matching its own schema", {
  MapEnvelope <- struct("JMapEnvelope", map = map_of(int[1]))
  txt <- as.character(to_json(MapEnvelope(map = list(cpu = 1L)), pretty = FALSE))
  expect_identical(txt, '{"map":{"cpu":1}}')
  expect_identical(schema(MapEnvelope)$properties$map$type, "object")
})

test_that("JSON round trips through the declared types", {
  M <- mk_json_struct()
  doc <- M(
    id = 1,
    tags = "a",
    when = as.Date("2024-01-01"),
    roster = data.frame(id = 1:2, nm = c("a", "b"))
  )
  back <- from_json(M, to_json(doc))
  expect_identical(back$when, as.Date("2024-01-01"))
  expect_identical(back$roster$nm, c("a", "b"))
  expect_identical(back$roster$id, 1:2)
  expect_identical(back, doc)
})

test_that("a JSON object with arbitrary keys is a named list", {
  expect_identical(
    from_json(map_of(int[1]), '{"cpu":4,"mem":16}'),
    list(cpu = 4L, mem = 16L)
  )
})

test_that("bad JSON is reported with paths", {
  U <- struct("JUser", id = int[1], name = chr[1])
  expect_identical(
    problem_paths(from_json(U, '{"id": 1.5, "name": ["a", "b"]}')),
    c("$id", "$name")
  )
})

test_that("to_json can serialise a schema", {
  txt <- as.character(to_json(schema(mk_json_struct()), pretty = FALSE))
  expect_match(txt, '"title":"JDoc"', fixed = TRUE)
  expect_match(txt, '"required"', fixed = TRUE)
})

test_that("a serialised instance uses its own spec, not the registry", {
  M <- struct("JDrift", a = int[1])
  m <- M(a = 1)
  suppressWarnings(struct("JDrift", a = chr[1]))
  expect_identical(as.character(to_json(m, pretty = FALSE)), '{"a":1}')
})
