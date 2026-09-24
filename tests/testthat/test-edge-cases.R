Struct0 <- function() struct("XEmpty")

test_that("a struct with no fields is still a struct", {
  E <- Struct0()
  expect_identical(fields(E), character())
  expect_s3_class(E(), "typed_instance")
  expect_identical(to_list(E()), stats::setNames(list(), character()))
  expect_identical(as.character(to_json(E(), pretty = FALSE)), "{}")
  expect_identical(class(from_list(E, list()))[1], "XEmpty")
  expect_identical(schema(E)$properties, stats::setNames(list(), character()))
  expect_identical(
    as.character(to_json(schema(E), pretty = FALSE)),
    '{"type":"object","title":"XEmpty","properties":{},"required":[],"additionalProperties":false}'
  )
})

test_that("printing an empty struct does not warn", {
  E <- Struct0()
  expect_silent(utils::capture.output(print(E)))
  expect_silent(utils::capture.output(print(E())))
})

test_that("a path reaches through four levels of nesting", {
  A <- struct("XA", v = int[1])
  B <- struct("XB", a = A)
  C <- struct("XC", b = B)
  D <- struct("XD", c = C)
  expect_identical(
    problem_paths(from_list(D, list(c = list(b = list(a = list(v = "x")))))),
    "$c$b$a$v"
  )
  expect_identical(
    problem_paths(from_list(D, list(c = list(b = list())))),
    "$c$b$a"
  )
})

test_that("two structs may refer to each other", {
  P <- struct("XP", name = chr[1], kid = opt("XQ"))
  struct("XQ", tag = chr[1], up = opt("XP"))
  x <- from_list(P, list(name = "a", kid = list(tag = "b", up = list(name = "c"))))
  expect_s3_class(x$kid$up, "XP")
  expect_identical(x$kid$up$name, "c")
  expect_identical(problem_paths(from_list(P, list(name = "a", kid = list(up = 1)))),
                   c("$kid$tag", "$kid$up"))
})

test_that("a recursive struct's schema refers to itself by name", {
  Node <- struct("XNode", v = int[1], nxt = opt("XNode"))
  expect_identical(schema(Node)$properties$nxt$anyOf[[1]][["$ref"]], "#/$defs/XNode")
})

test_that("a union of two structs picks the member that fits", {
  A <- struct("XU1", a = int[1])
  struct("XU2", b = chr[1])
  B <- ref("XU2")
  expect_s3_class(parse_as(A | B, list(b = "x")), "XU2")
  expect_s3_class(parse_as(A | B, list(a = 1)), "XU1")
  expect_identical(problem_paths(parse_as(A | B, list(z = 1))), "$a")
})

test_that("a struct can be unioned with a scalar", {
  A <- struct("XU3", a = int[1])
  expect_identical(parse_as(A | int[1], 3L), 3L)
  expect_s3_class(parse_as(A | int[1], list(a = 1)), "XU3")
  expect_false(is_valid(A | int[1], "x"))
})

test_that("field names may be anything a name can hold", {
  nms <- c("first name", "\u00e9l\u00e8ve", ".dot", "if")
  types <- stats::setNames(
    list(chr[1], int[1], chr[1] %default% "d", lgl[1]),
    nms
  )
  W <- do.call(struct, c(list("XWeird"), types))
  expect_identical(fields(W), nms)

  w <- do.call(W, stats::setNames(list("a", 1, "z", TRUE), nms))
  expect_identical(w[["first name"]], "a")
  expect_identical(w[[nms[2]]], 1L)
  expect_true(w[["if"]])

  expect_identical(
    problem_paths(do.call(W, stats::setNames(list(1, "x", "z", TRUE), nms))),
    paste0("$", nms[1:2])
  )

  w[["first name"]] <- "b"
  expect_identical(w[["first name"]], "b")
  expect_identical(problem_paths(w[["first name"]] <- 1), "$first name")
})

test_that("extend() chains three deep and composes with partial()", {
  A <- struct("XL1", a = int[1])
  B <- extend(A, "XL2", b = int[1])
  C <- extend(B, "XL3", c = int[1])
  expect_identical(class(C(a = 1, b = 2, c = 3)),
                   c("XL3", "XL2", "XL1", "typed_instance"))
  expect_identical(fields(C), c("a", "b", "c"))
  expect_true(is_valid(A, C(a = 1, b = 2, c = 3)))

  expect_identical(fields(partial(C)), c("a", "b", "c"))
  expect_null(partial(C)()$a)
  expect_identical(fields(extend(partial(A), "XLP", z = chr[1])), c("a", "z"))
})

test_that("map_of() and list_of() nest either way round", {
  M <- map_of(list_of(int[1]))
  expect_identical(to_list(parse_as(M, list(a = list(1L, 2L)))), list(a = list(1L, 2L)))
  expect_identical(problem_paths(parse_as(M, list(a = list(1L, "x")))), "$a[[2]]")

  L <- list_of(map_of(int[1]))
  expect_identical(problem_paths(parse_as(L, list(list(k = "x")))), "[[1]]$k")
})

test_that("a frame() carries factor columns and survives being empty", {
  F1 <- frame(g = fct("a", "b"), n = int)
  r <- parse_as(F1, data.frame(g = c("a", "b"), n = 1:2))
  expect_s3_class(r$g, "factor")
  expect_identical(levels(r$g), c("a", "b"))
  expect_identical(dim(from_json(F1, "[]")), c(0L, 2L))
  expect_identical(
    as.character(to_json(parse_as(F1, data.frame(g = "a", n = 1L)), pretty = FALSE)),
    '[{"g":"a","n":1}]'
  )
  expect_false(is_valid(F1, data.frame(g = "z", n = 1L)))
})

test_that("unicode and NA survive a JSON round trip", {
  U <- struct("XUni", s = chr[1], n = num[1] | NULL, v = int)
  u <- U(s = "caf\u00e9", n = NULL, v = c(1L, NA))
  expect_identical(
    as.character(to_json(u, pretty = FALSE)),
    paste0('{"s":"', "caf\u00e9", '","n":null,"v":[1,null]}')
  )
  back <- from_json(U, to_json(u))
  expect_identical(back$s, u$s)
  expect_null(back$n)
  expect_identical(back$v, c(1L, NA))
})

test_that("many fields and long vectors are handled whole", {
  nms <- paste0("f", 1:60)
  Big <- do.call(struct, c(list("XBig"), stats::setNames(rep(list(int[1]), 60), nms)))
  b <- do.call(Big, stats::setNames(as.list(1:60), nms))
  expect_identical(b$f60, 60L)
  expect_length(int(1:100000), 100000L)
  expect_length(problem_paths(do.call(Big, stats::setNames(as.list(rep("x", 60)), nms))), 60L)
})

test_that("strict mode and switched-off checks combine without fighting", {
  old <- options(rdantic.strict = TRUE, rdantic.check = FALSE)
  on.exit(options(old))
  f <- fn(x = int[1], ~ int[1], { x })
  expect_identical(f(1.0), 1.0) # no check at all, so no coercion either
  # a struct constructor is not the function-call path and still validates
  S <- struct("XStrict", a = int[1])
  expect_error(S(a = 1.0), class = "typed_error")
})

test_that("type_of() names values that are not vectors", {
  expect_identical(type_of(sum), "function[1]")
  expect_identical(type_of(as.raw(1:2)), "raw[2]")
  expect_identical(type_of(complex(real = 1, imaginary = 1)), "complex[1]")
  expect_identical(type_of(quote(x + 1)), "call[3]")
  expect_identical(type_of(matrix(1:4, 2)), "int[4]")
  expect_match(type_of(globalenv()), "^environment\\[")
})

test_that("a typed function can build and return another one", {
  mk <- fn(n = int[1], ~ anything[is.function(.)], {
    fn(x = int[1], ~ int[1], { x + n })
  })
  add2 <- mk(2L)
  expect_identical(add2(3L), 5L)
  expect_error(add2("x"), class = "typed_error")
})
