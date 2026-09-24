skip_if_no_s7 <- function() skip_if_not_installed("S7")

# S7's `@` shim for R < 4.3 is attached to the search path, which a test's
# namespace-parented environment does not see; prop() works everywhere.
get_prop <- function(x, name) S7::prop(x, name)

mk_pin <- function()
  S7::new_class(
    "TPin",
    package = NULL,
    properties = list(lat = S7::class_double, lon = S7::class_double)
  )

test_that("an S7 class is a type", {
  skip_if_no_s7()
  Pin <- mk_pin()
  expect_s3_class(as_type(Pin), "type")
  expect_identical(fields(Pin), c("lat", "lon"))
  expect_identical(.spec(s7_type(Pin))$name, "TPin")
})

test_that("s7_type accepts instances and rejects everything else", {
  skip_if_no_s7()
  Pin <- mk_pin()
  p <- Pin(lat = 1, lon = 2)
  expect_identical(parse_as(Pin, p), p)
  expect_true(is_valid(Pin, p))
  expect_false(is_valid(Pin, 42))
  expect_false(is_valid(Pin, S7::new_class("TOther", package = NULL)()))
})

test_that("a plain list is parsed into an S7 object", {
  skip_if_no_s7()
  Pin <- mk_pin()
  p <- parse_as(Pin, list(lat = 1, lon = 2))
  expect_true(S7::S7_inherits(p, Pin))
  expect_identical(get_prop(p, "lat"), 1)
})

test_that("problems inside an S7 property keep their path", {
  skip_if_no_s7()
  Trip <- struct("TTrip", label = chr[1], start = mk_pin())
  expect_identical(
    problem_paths(from_list(Trip, list(label = "a", start = list(lat = "x")))),
    c("$start$lat", "$start$lon")
  )
  expect_identical(
    problem_paths(Trip(label = "a", start = 42)),
    "$start"
  )
})

test_that("a struct instance is not parsed as an S7 class", {
  skip_if_no_s7()
  Pin <- mk_pin()
  Other <- struct("TNotPin", lat = num, lon = num)
  expect_false(is_valid(Pin, Other(lat = 1, lon = 2)))
})

test_that("type_of names an S7 object by its class", {
  skip_if_no_s7()
  expect_identical(type_of(mk_pin()(lat = 1, lon = 2)), "<TPin>")
})

test_that("an S7 property default makes the field optional", {
  skip_if_no_s7()
  Cfg <- S7::new_class(
    "TCfg",
    package = NULL,
    properties = list(
      host = S7::class_character,
      port = S7::new_property(S7::class_double, default = 8080)
    )
  )
  expect_identical(unlist(schema(Cfg)$required), "host")
  expect_identical(get_prop(parse_as(Cfg, list(host = "x")), "port"), 8080)
})

test_that("S7 objects serialise like structs", {
  skip_if_no_s7()
  Trip <- struct("TTrip2", label = chr[1], start = mk_pin())
  t <- Trip(label = "home", start = list(lat = 1, lon = 2))
  expect_identical(to_list(t), list(label = "home", start = list(lat = 1, lon = 2)))
  expect_identical(
    as.character(to_json(t, pretty = FALSE)),
    '{"label":"home","start":{"lat":[1],"lon":[2]}}'
  )
})

test_that("as_s7_class validates and coerces on construction", {
  skip_if_no_s7()
  Account <- struct(
    "TAccount",
    id = int[1][. > 0],
    credit = num[1][. >= 0] %default% 0
  )
  S7Account <- as_s7_class(Account)
  a <- S7Account(id = 1)
  expect_true(S7::S7_inherits(a, S7Account))
  expect_identical(get_prop(a, "id"), 1L)
  expect_identical(get_prop(a, "credit"), 0)
  expect_error(S7Account(id = 0), class = "typed_error")
  expect_identical(problem_paths(S7Account(id = 0)), "@id")
})

test_that("a missing required field is reported as missing", {
  skip_if_no_s7()
  S7A <- as_s7_class(struct("TReq", id = int[1]))
  expect_error(S7A(), class = "typed_error")
  expect_identical(problem_paths(S7A()), "@id")
})

test_that("property assignment runs the field's type", {
  skip_if_no_s7()
  S7A <- as_s7_class(struct("TSet", n = num[1][. >= 0]))
  a <- S7A(n = 1)
  a <- S7::`prop<-`(a, "n", value = 2L)
  expect_identical(get_prop(a, "n"), 2)
  expect_error(S7::`prop<-`(a, "n", value = -1), class = "typed_error")
})

test_that("converting the same struct twice yields the same class", {
  skip_if_no_s7()
  S <- struct("TSame", a = int[1])
  expect_identical(as_s7_class(S), as_s7_class(S))
})

test_that("a generated class round trips through s7_type", {
  skip_if_no_s7()
  S <- struct("TRound", a = int[1], b = chr %default% "x")
  cls <- as_s7_class(S)
  expect_identical(fields(cls), c("a", "b"))
  expect_identical(schema(cls)$properties$a$type, "integer")
  expect_identical(unlist(schema(cls)$required), "a")
  expect_identical(get_prop(from_list(cls, list(a = 1)), "a"), 1L)
})

test_that("extend() becomes S7 inheritance", {
  skip_if_no_s7()
  Animal <- struct("TAnimal", name = chr[1], legs = int[1])
  Dog <- extend(Animal, "TDog", good = lgl[1] %default% TRUE)
  d <- as_s7_class(Dog)(name = "rex", legs = 4L)
  expect_identical(class(d), c("TDog", "TAnimal", "S7_object"))
  expect_true(S7::S7_inherits(d, as_s7_class(Animal)))
  expect_true(get_prop(d, "good"))
})

test_that("a retyped parent field flattens the hierarchy, with a warning", {
  skip_if_no_s7()
  Animal <- struct("TAnimal2", name = chr[1], legs = int[1])
  Cent <- extend(Animal, "TCentipede", legs = int[1][. > 50])
  expect_warning(cls <- as_s7_class(Cent), "retypes")
  expect_identical(class(cls(name = "c", legs = 100L)), c("TCentipede", "S7_object"))
  expect_error(cls(name = "c", legs = 1L), class = "typed_error")
})

test_that("as_s7_class refuses a non-struct", {
  skip_if_no_s7()
  expect_error(as_s7_class(int[1]), "needs a struct")
})

test_that("extend() and partial() see through an S7 class", {
  skip_if_no_s7()
  S <- struct("TThrough", a = int[1], n = num[1] %default% 0)
  cls <- as_s7_class(S)
  expect_identical(fields(extend(cls, "TThroughSub", b = chr[1])), c("a", "n", "b"))
  expect_identical(fields(partial(cls)), c("a", "n"))
  expect_identical(fields(extend(mk_pin(), "TGeo", label = chr[1])), c("lat", "lon", "label"))
})

test_that("extend() and partial() refuse a type with no fields", {
  expect_error(extend(int[1], "TNope", a = chr), "needs a struct")
  expect_error(partial(list_of(int)), "needs a struct")
})

test_that("s7_struct() builds an S7 class directly", {
  skip_if_no_s7()
  Acc <- s7_struct(
    "TDirect",
    id = int[1][. > 0],
    credit = num[1][. >= 0] %default% 0,
    .description = "An account."
  )
  expect_true(.is_s7_class(Acc))
  a <- Acc(id = 1)
  expect_identical(get_prop(a, "id"), 1L)
  expect_identical(get_prop(a, "credit"), 0)
  expect_error(Acc(id = 0), class = "typed_error")
  expect_identical(problem_paths(Acc(id = 0)), "@id")
  expect_identical(schema(Acc)$description, "An account.")
  expect_identical(unlist(schema(Acc)$required), "id")
  expect_identical(get_prop(from_list(Acc, list(id = 2)), "id"), 2L)
})

test_that("s7_struct() does not register the name", {
  skip_if_no_s7()
  s7_struct("TUnregistered", a = int[1])
  expect_null(get0("TUnregistered", envir = .registry, inherits = FALSE))
  expect_silent(s7_struct("TUnregistered", a = chr[1]))
})

test_that("s7_struct(.parent = ) inherits properties as typed fields", {
  skip_if_no_s7()
  Base <- s7_struct("TBase", id = int[1])
  Sub <- s7_struct("TSub", tier = one_of("gold", "silver"), .parent = Base)
  s <- Sub(id = 1, tier = "gold")
  expect_identical(class(s), c("TSub", "TBase", "S7_object"))
  expect_true(S7::S7_inherits(s, Base))
  expect_identical(fields(Sub), c("id", "tier"))
  expect_error(Sub(id = 1, tier = "bronze"), class = "typed_error")
})

test_that("s7_struct() retyping a parent property flattens, with a warning", {
  skip_if_no_s7()
  Base <- s7_struct("TBase2", id = int[1])
  expect_warning(Tiny <- s7_struct("TTiny", id = int[1][. > 100], .parent = Base), "retypes")
  expect_identical(class(Tiny(id = 101L)), c("TTiny", "S7_object"))
  expect_error(Tiny(id = 1L), class = "typed_error")
})

test_that("s7_struct(.extra = 'forbid') rejects unknown keys", {
  skip_if_no_s7()
  Shut <- s7_struct("TShut", x = int[1], .extra = "forbid")
  expect_identical(problem_paths(from_list(Shut, list(x = 1, y = 2))), "$y")
})

test_that("s7_struct() checks its own arguments", {
  skip_if_no_s7()
  expect_error(s7_struct(int[1]), "exactly one unnamed name")
  expect_error(s7_struct("TBad", int[1]), "must be named")
  expect_error(s7_struct("TBad", a = int[1], .parent = "TBase"), "an S7 class")
})
