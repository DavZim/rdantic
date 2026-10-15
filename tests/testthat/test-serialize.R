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

test_that("to_ellmer_type makes nullable schema fields required", {
  skip_if_not_installed("ellmer")
  AgeName <- struct(
    "JAgeName",
    age = (int[1][. > 0] | NULL),
    name = (chr[1] | NULL)
  )

  expect_true(inherits(to_ellmer_type(AgeName), "ellmer::Type"))
})

test_that("to_ellmer_type sets required fields in nested objects", {
  Address <- struct(
    "JAddress",
    street = chr[1] | NULL,
    postcode = chr[1] | NULL
  )
  Person <- struct(
    "JPerson",
    name = chr[1] | NULL,
    address = Address | NULL,
    addresses = list_of(Address)
  )

  normalized <- rdantic:::.ellmer_schema(schema(Person))
  expect_identical(normalized$required, as.list(c("name", "address", "addresses")))
  expect_identical(
    normalized$properties$address$anyOf[[1]]$required,
    as.list(c("street", "postcode"))
  )
  expect_identical(
    normalized$properties$addresses$items$required,
    as.list(c("street", "postcode"))
  )
})

test_that("to_ellmer_type normalizes object map values", {
  Item <- struct("JItem", id = int[1] | NULL)
  schema_map <- schema(map_of(Item))

  normalized <- rdantic:::.ellmer_schema(schema_map)
  expect_identical(normalized$additionalProperties$required, list("id"))
})

test_that("to_ellmer_type accepts schemas and preserves the input", {
  skip_if_not_installed("ellmer")
  Person <- struct("JSchemaPerson", name = chr[1] | NULL)
  input <- schema(Person)
  original <- input

  result <- to_ellmer_type(input)

  expect_true(inherits(result, "ellmer::Type"))
  expect_identical(input, original)
  expect_identical(input$required, list())
})

test_that("to_ellmer_type leaves non-object schemas without required", {
  expect_identical(rdantic:::.ellmer_schema(schema(int[1])), schema(int[1]))
  expect_identical(
    rdantic:::.ellmer_schema(list(type = "array", items = list(type = "string"))),
    list(type = "array", items = list(type = "string"))
  )
})

test_that("to_ellmer_type maps scalar schemas to ellmer basic types", {
  skip_if_not_installed("ellmer")
  types <- list(
    boolean = lgl[1],
    integer = int[1],
    number = num[1],
    string = chr[1]
  )

  for (type_name in names(types)) {
    result <- to_ellmer_type(types[[type_name]])
    expect_s3_class(result, "ellmer::TypeJsonSchema")
    expect_identical(S7::prop(result, "json")$type, type_name)
    expect_true(S7::prop(result, "required"))
  }
})

test_that("to_ellmer_type maps vectors to ellmer arrays", {
  skip_if_not_installed("ellmer")
  result <- to_ellmer_type(chr)
  json <- S7::prop(result, "json")

  expect_s3_class(result, "ellmer::TypeJsonSchema")
  expect_true(S7::prop(result, "required"))
  expect_identical(json$type, "array")
  expect_identical(json$items$type, "string")
})

test_that("to_ellmer_type maps objects to typed ellmer properties", {
  skip_if_not_installed("ellmer")
  Person <- struct(
    "JEllmerPerson",
    name = chr[1] %doc% "The person's name.",
    age = int[1] | NULL
  )
  result <- to_ellmer_type(Person)
  json <- S7::prop(result, "json")

  expect_s3_class(result, "ellmer::TypeJsonSchema")
  expect_true(S7::prop(result, "required"))
  expect_false(json$additionalProperties)
  expect_identical(names(json$properties), c("name", "age"))
  expect_identical(json$properties$name$type, "string")
  expect_identical(json$properties$name$description, "The person's name.")
  expect_identical(json$properties$age$type, as.list(c("integer", "null")))
  expect_identical(json$required, as.list(c("name", "age")))
})

test_that("a serialised instance uses its own spec, not the registry", {
  M <- struct("JDrift", a = int[1])
  m <- M(a = 1)
  suppressWarnings(struct("JDrift", a = chr[1]))
  expect_identical(as.character(to_json(m, pretty = FALSE)), '{"a":1}')
})
