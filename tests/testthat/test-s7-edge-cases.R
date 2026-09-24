skip_if_no_s7 <- function() skip_if_not_installed("S7")

# S7's `@` shim for R < 4.3 is attached to the search path, which a test's
# namespace-parented environment does not see; prop() works everywhere.
get_prop <- function(x, name) S7::prop(x, name)

test_that("S7 classes nest inside each other", {
  skip_if_no_s7()
  Inner <- S7::new_class("EInner", package = NULL,
                         properties = list(n = S7::class_double))
  Outer <- S7::new_class("EOuter", package = NULL,
                         properties = list(i = Inner, tag = S7::class_character))

  o <- parse_as(Outer, list(i = list(n = 1), tag = "t"))
  expect_true(S7::S7_inherits(o, Outer))
  expect_true(S7::S7_inherits(get_prop(o, "i"), Inner))
  expect_identical(problem_paths(parse_as(Outer, list(i = list(n = "x"), tag = "t"))), "$i$n")
  expect_identical(schema(Outer)$properties$i$title, "EInner")
  expect_identical(
    as.character(to_json(o, pretty = FALSE)),
    '{"i":{"n":[1]},"tag":["t"]}'
  )
})

test_that("S7 property classes translate to the types they mean", {
  skip_if_no_s7()
  Mix <- S7::new_class("EMix", package = NULL, properties = list(
    i = S7::class_integer,
    b = S7::class_logical,
    u = S7::new_union(S7::class_double, S7::class_character),
    nullable = S7::new_union(S7::class_double, NULL),
    d = S7::class_Date,
    dt = S7::class_POSIXct,
    df = S7::class_data.frame,
    l = S7::class_list,
    a = S7::class_any
  ))
  nm <- function(f) .spec(.s7_fields(Mix)[[f]])$name
  expect_identical(nm("i"), "int")
  expect_identical(nm("b"), "lgl")
  expect_identical(nm("u"), "num | chr")
  expect_identical(nm("nullable"), "num | NULL")
  expect_identical(nm("d"), "date")
  expect_identical(nm("dt"), "datetime")
  expect_identical(nm("df"), "data.frame")
  expect_identical(nm("l"), "list_of(anything)")
  expect_identical(nm("a"), "anything")

  m <- parse_as(Mix, list(
    i = 1, b = TRUE, u = 1, nullable = NULL,
    d = "2024-01-01", dt = "2024-01-01T12:00:00Z",
    df = data.frame(x = 1), l = list(1), a = NULL
  ))
  expect_identical(get_prop(m, "i"), 1L)
  expect_s3_class(get_prop(m, "d"), "Date")
  expect_s3_class(get_prop(m, "dt"), "POSIXct")
  expect_s3_class(get_prop(m, "df"), "data.frame")
  FrameHolder <- S7::new_class(
    "EFrameHolder", package = NULL,
    properties = list(df = S7::class_data.frame)
  )
  parsed_df <- get_prop(from_json(FrameHolder, '{"df":[{"x":1},{"x":2}]}'), "df")
  expect_s3_class(parsed_df, "data.frame")
  expect_identical(parsed_df$x, c(1L, 2L))
  expect_identical(
    problem_paths(parse_as(Mix, list(
      i = 1, b = TRUE, u = TRUE, nullable = NULL,
      d = "2024-01-01", dt = "2024-01-01T12:00:00Z",
      df = data.frame(), l = list(), a = NULL
    ))),
    "$u"
  )
})

test_that("an S7 union is a type", {
  skip_if_no_s7()
  Pt <- s7_struct("EPtU", x = num[1])
  t <- as_type(Pt | NULL)
  expect_identical(.spec(t)$name, "EPtU | NULL")
  expect_null(parse_as(t, NULL))
  expect_true(S7::S7_inherits(parse_as(t, list(x = 1)), Pt))
  expect_false(is_valid(t, 42))
  expect_identical(.spec(as_type(S7::new_union(S7::class_double, S7::class_character)))$name,
                   "num | chr")
})

test_that("a computed S7 property is not a field", {
  skip_if_no_s7()
  Comp <- S7::new_class("EComp", package = NULL, properties = list(
    n = S7::class_double,
    double_n = S7::new_property(
      S7::class_double,
      getter = function(self) S7::prop(self, "n") * 2
    )
  ))
  expect_identical(fields(Comp), "n")
  c1 <- parse_as(Comp, list(n = 2))
  expect_identical(get_prop(c1, "double_n"), 4)
  expect_identical(names(to_list(c1)), "n")
  expect_identical(as.character(to_json(c1, pretty = FALSE)), '{"n":[2]}')
})

test_that("a property with both getter and setter stays a field", {
  skip_if_no_s7()
  G <- S7::new_class("EGet", package = NULL, properties = list(
    n = S7::class_double,
    m = S7::new_property(
      S7::class_double,
      getter = function(self) S7::prop(self, "n"),
      setter = function(self, value) {
        S7::prop(self, "n", check = FALSE) <- value
        self
      }
    )
  ))
  expect_identical(fields(G), c("n", "m"))
})

test_that("an S7 class's own validator still runs", {
  skip_if_no_s7()
  Pos <- S7::new_class(
    "EPos", package = NULL,
    properties = list(n = S7::class_double),
    validator = function(self) {
      n <- S7::prop(self, "n")
      if (length(n) && n < 0) "n must be >= 0"
    }
  )
  expect_true(S7::S7_inherits(parse_as(Pos, list(n = 1)), Pos))
  expect_error(parse_as(Pos, list(n = -1)), "n must be >= 0")
})

test_that("an expression-valued S7 default is evaluated by S7", {
  skip_if_no_s7()
  counter <- 0
  Dynamic <- S7::new_class(
    "EDynamic", package = NULL,
    properties = list(n = S7::new_property(
      S7::class_double,
      default = quote({
        counter <<- counter + 1
        as.double(counter)
      })
    ))
  )

  expect_identical(schema(Dynamic)$required, list())
  expect_identical(get_prop(parse_as(Dynamic, list()), "n"), 1)
  expect_identical(get_prop(parse_as(Dynamic, list()), "n"), 2)
  expect_identical(get_prop(parse_as(Dynamic, list(n = 10)), "n"), 10)
  expect_identical(problem_paths(parse_as(Dynamic, list(n = "x"))), "$n")
})

test_that("an abstract S7 class cannot be parsed into", {
  skip_if_no_s7()
  Abs <- S7::new_class("EAbs", package = NULL, abstract = TRUE,
                       properties = list(n = S7::class_double))
  expect_error(parse_as(Abs, list(n = 1)), "abstract")
})

test_that("s7_struct() with no fields still builds", {
  skip_if_no_s7()
  E <- s7_struct("EEmpty")
  expect_identical(fields(E), character())
  expect_true(S7::S7_inherits(E(), E))
  expect_identical(as.character(to_json(E(), pretty = FALSE)), "{}")
  expect_identical(schema(E)$properties, stats::setNames(list(), character()))
})

test_that("s7_struct() inherits three levels deep", {
  skip_if_no_s7()
  L1 <- s7_struct("EL1", a = int[1])
  L2 <- s7_struct("EL2", b = int[1], .parent = L1)
  L3 <- s7_struct("EL3", c = int[1], .parent = L2)
  x <- L3(a = 1, b = 2, c = 3)
  expect_identical(class(x), c("EL3", "EL2", "EL1", "S7_object"))
  expect_identical(fields(L3), c("a", "b", "c"))
  expect_true(S7::S7_inherits(x, L1))
  expect_identical(get_prop(x, "a"), 1L)
  expect_error(L3(a = 1, b = 2), class = "typed_error")
})

test_that("S7 classes nest and round trip through JSON", {
  skip_if_no_s7()
  Pt <- s7_struct("EPt", x = num[1], y = num[1])
  Seg <- s7_struct("ESeg", from = Pt, to = Pt)
  s <- from_list(Seg, list(from = list(x = 1, y = 2), to = list(x = 3, y = 4)))
  expect_true(S7::S7_inherits(get_prop(s, "from"), Pt))
  expect_identical(
    as.character(to_json(s, pretty = FALSE)),
    '{"from":{"x":1,"y":2},"to":{"x":3,"y":4}}'
  )
  expect_identical(
    problem_paths(from_list(Seg, list(from = list(x = "a", y = 2), to = list(x = 3)))),
    c("$from$x", "$to$y")
  )
  expect_identical(to_list(from_json(Seg, to_json(s))), to_list(s))
})

test_that("S7 classes work inside containers", {
  skip_if_no_s7()
  Pt <- s7_struct("EPtC", x = num[1], y = num[1])
  l <- parse_as(list_of(Pt), list(list(x = 1, y = 2), list(x = 3, y = 4)))
  expect_length(l, 2L)
  expect_true(S7::S7_inherits(l[[1]], Pt))
  expect_identical(problem_paths(parse_as(list_of(Pt), list(list(x = 1, y = 2), list(x = "z", y = 4)))),
                   "[[2]]$x")
  expect_identical(names(parse_as(map_of(Pt), list(a = list(x = 1, y = 2)))), "a")
  expect_null(parse_as(opt(Pt), NULL))
})

test_that("an S7 class is usable as an fn() argument and return type", {
  skip_if_no_s7()
  Pt <- s7_struct("EPtF", x = num[1], y = num[1])
  f <- fn(p = Pt, ~ num[1], { S7::prop(p, "x") + S7::prop(p, "y") })
  expect_identical(f(list(x = 1, y = 2)), 3)
  expect_identical(problem_paths(f(list(x = "a", y = 2))), "p$x")

  g <- fn(x = num[1], ~ Pt, { list(x = x, y = x) })
  expect_true(S7::S7_inherits(g(1), Pt))
})

test_that("strict mode switches off coercion into S7 properties too", {
  skip_if_no_s7()
  Pt <- s7_struct("EPtS", x = num[1])
  expect_identical(get_prop(parse_as(Pt, list(x = 1L)), "x"), 1)
  old <- options(rdantic.strict = TRUE)
  on.exit(options(old))
  expect_error(parse_as(Pt, list(x = 1L)), class = "typed_error")
})

test_that("a self-referential struct converts to a working S7 class", {
  skip_if_no_s7()
  Node <- struct("ENode", v = int[1], nxt = opt("ENode"))
  S7Node <- as_s7_class(Node)
  n <- S7Node(v = 1, nxt = list(v = 2))
  expect_s3_class(get_prop(n, "nxt"), "ENode")
  expect_identical(get_prop(n, "nxt")$v, 2L)
  expect_error(S7Node(v = 1, nxt = list(v = "x")), class = "typed_error")
})

test_that("as_s7_class() caches and s7_struct() does not", {
  skip_if_no_s7()
  expect_identical(
    as_s7_class(struct("ERT1", a = int[1])),
    as_s7_class(struct("ERT1", a = int[1]))
  )
  expect_false(identical(s7_struct("ERT2", a = int[1]), s7_struct("ERT2", a = int[1])))
})

test_that("field types survive the trip out to S7 and back", {
  skip_if_no_s7()
  S <- struct("ERound", a = int[1][. > 0], b = one_of("x", "y") %default% "x")
  cls <- as_s7_class(S)
  expect_identical(.spec(.s7_fields(cls)$a)$name, "int[1][. > 0]")
  expect_identical(.spec(.s7_fields(cls)$b)$name, 'one_of("x", "y")')
  expect_identical(unlist(schema(cls)$required), "a")
})

test_that("weird field names survive s7_struct()", {
  skip_if_no_s7()
  nms <- c("first name", "\u00e9l\u00e8ve")
  cls <- do.call(
    s7_struct,
    c(list("EWeird"), stats::setNames(list(chr[1], int[1]), nms))
  )
  expect_identical(fields(cls), nms)
  x <- do.call(cls, stats::setNames(list("a", 1), nms))
  expect_identical(get_prop(x, "first name"), "a")
  expect_identical(
    problem_paths(do.call(cls, stats::setNames(list(1, "x"), nms))),
    "@first name"
  )
  expect_identical(
    problem_paths(from_list(cls, stats::setNames(list(1, "x"), nms))),
    paste0("$", nms)
  )
})

test_that("many properties are validated and reported together", {
  skip_if_no_s7()
  nms <- paste0("p", 1:40)
  cls <- do.call(
    s7_struct,
    c(list("EBig"), stats::setNames(rep(list(int[1]), 40), nms))
  )
  x <- do.call(cls, stats::setNames(as.list(1:40), nms))
  expect_identical(get_prop(x, "p40"), 40L)
  # a setter validates one property at a time, so the first failure stops it
  expect_identical(
    problem_paths(do.call(cls, stats::setNames(as.list(rep("x", 40)), nms))),
    "@p1"
  )
  # parsing a list goes through .check_fields and reports every problem
  expect_length(
    problem_paths(from_list(cls, stats::setNames(as.list(rep("x", 40)), nms))),
    40L
  )
})
