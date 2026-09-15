test_that("arguments are validated and coerced", {
  g <- fn(x = int[1], y = chr[1] %default% "a", ~ chr[1], { paste0(y, x) })
  expect_identical(g(1), "a1")
  expect_identical(g(1, "b"), "b1")
  expect_error(g("no"), class = "typed_error")
})

test_that("every bad argument is reported in one error", {
  g <- fn(x = int[1], y = chr[1] %default% "a", ~ chr[1], { paste0(y, x) })
  expect_identical(problem_paths(g(1.5, 2)), c("x", "y"))
})

test_that("the return value is checked", {
  half <- fn(x = int[1], ~ int[1], { x / 2 })
  expect_identical(half(4), 2L)
  expect_identical(problem_paths(half(3)), "<return>")
})

test_that("an explicit return() is checked exactly like an implicit result", {
  bad <- fn(x = int[1], ~ int[1], { return("wrong") })
  expect_error(bad(1L), class = "typed_error")
  ok <- fn(x = int[1], ~ int[1], { return(x) })
  expect_identical(ok(1L), 1L)
})

test_that("a missing argument is reported unless the type accepts NULL", {
  f <- fn(x = int[1], ~ int[1], { x })
  expect_identical(problem_paths(f()), "x")
  g <- fn(x = int[1] | NULL, ~ int[1] | NULL, { x })
  expect_null(g())
})

test_that("the message names the function that was called", {
  greet <- fn(name = chr[1], ~ chr[1], { name })
  expect_error(greet(1), "greet()", fixed = TRUE)
})

test_that("a typed ... is checked element by element", {
  h <- fn(a = int[1], ... = chr[1], ~ int[1], { a })
  expect_identical(h(1L, "x", "y"), 1L)
  expect_identical(problem_paths(h(1L, 2, "y")), "..1")
  expect_identical(problem_paths(h(1L, tag = 2)), "tag")
})

test_that("structs work as argument and return types", {
  Item <- struct("FnItem", qty = int[1][. > 0], price = num[1][. >= 0])
  total <- fn(i = Item, ~ num[1][. >= 0], { i$qty * i$price })
  expect_identical(total(Item(qty = 2, price = 1.5)), 3)
  expect_identical(problem_paths(total(list(qty = 0, price = 1.5))), "i$qty")
})

test_that("checks can be switched off globally", {
  half <- fn(x = int[1], ~ int[1], { x / 2 })
  old <- options(rdantic.check = FALSE)
  on.exit(options(old))
  expect_identical(half(3), 1.5)
})

test_that("a typed function works away from the global environment", {
  make <- function() {
    local_default <- "hi"
    fn(x = chr[1] %default% local_default, ~ chr[1], { toupper(x) })
  }
  f <- make()
  expect_identical(f(), "HI")
  expect_error(f(1), class = "typed_error")
})

test_that("fn rejects malformed declarations", {
  expect_error(fn(x = int[1]), "exactly one body")
  expect_error(fn(x = int[1], ~ int[1], ~ chr[1], { x }), "one return-type")
})

test_that("fn rejects argument names that collide with its own internals", {
  reserved <- c(".probs_", ".types_", ".ret_", ".result_", ".r_", ".missing_")
  for (n in reserved) {
    call <- bquote(fn(int[1], ~ int[1], { 1L }))
    names(call)[2] <- n
    expect_error(eval(call), "reserved")
  }
  # the exact repro from the bug report: a second argument used to silently
  # overwrite the first through the shared internal temp variable
  expect_error(fn(.r_ = int[1], y = int[1], ~ int[1], { .r_ }), "reserved")
})

test_that("printing shows the signature", {
  f <- fn(x = int[1], y = chr[1] %default% "a", ~ chr[1], { paste0(y, x) })
  expect_output(print(f), "<fn> (x: int[1], y: chr[1] = \"a\") -> chr[1]", fixed = TRUE)
})
