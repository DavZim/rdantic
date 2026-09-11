mk_user <- function() {
  model("TUser", id = int[1], name = chr[1], tags = chr %default% character())
}

test_that("a constructor validates and coerces", {
  U <- mk_user()
  a <- U(id = 1, name = "Ada")
  expect_identical(a$id, 1L)
  expect_identical(a$tags, character())
  expect_s3_class(a, "typed_instance")
})

test_that("every problem is reported at once", {
  U <- mk_user()
  expect_identical(problem_paths(U(name = 42)), c("$id", "$name"))
})

test_that("instances are values, not references", {
  U <- mk_user()
  a <- U(id = 1, name = "Ada")
  b <- a
  b$name <- "Grace"
  expect_identical(a$name, "Ada")
  expect_identical(b$name, "Grace")
  expect_identical(U(id = 1, name = "z"), U(id = 1, name = "z"))
})

test_that("instances survive a saveRDS round trip", {
  U <- mk_user()
  a <- U(id = 1, name = "Ada")
  f <- tempfile()
  on.exit(unlink(f))
  saveRDS(a, f)
  expect_identical(readRDS(f), a)
})

test_that("assignment runs the field's type", {
  U <- mk_user()
  a <- U(id = 1, name = "Ada")
  a$name <- "Grace"
  expect_identical(a$name, "Grace")
  expect_error(a$name <- 42, class = "typed_error")
})

test_that("a field that was never declared cannot be invented", {
  U <- mk_user()
  a <- U(id = 1, name = "Ada")
  expect_identical(problem_paths(a$nickname <- "x"), "$nickname")
  expect_match(problem_hint(a$nam <- "x"), "did you mean")
})

test_that("reading a field does not partially match", {
  U <- mk_user()
  a <- U(id = 1, name = "Ada")
  expect_error(a$nam, class = "typed_error")
  expect_identical(a[["name"]], "Ada")
})

test_that("a different model is not parsed as this one", {
  U <- mk_user()
  a <- U(id = 1, name = "Ada")
  V <- model("TOther", id = int[1], name = chr[1])
  expect_length(problem_paths(parse_as(V, a)), 1)
})

test_that("a plain list is parsed where a model is expected", {
  U <- mk_user()
  expect_identical(from_list(U, list(id = 2, name = "Bob"))$id, 2L)
  expect_identical(from_list(U, list(id = 2, name = "Bob", z = 1))$id, 2L)
})

test_that("a model can forbid unknown keys", {
  S <- model("TShut", x = int[1], .extra = "forbid")
  expect_identical(problem_paths(from_list(S, list(x = 1, y = 2))), "$y")
})

test_that("models nest and report the full path", {
  U <- mk_user()
  Team <- model("TTeam", lead = U, roster = frame(id = int, name = chr))
  bad <- problem_paths(Team(
    lead = list(id = 1, name = 42),
    roster = data.frame(id = c(1, 2.5), name = c("a", "b"))
  ))
  expect_identical(bad, c("$lead$name", "$roster$id"))
})

test_that("fields() lists the declaration order", {
  expect_identical(fields(mk_user()), c("id", "name", "tags"))
  expect_identical(fields(mk_user()(id = 1, name = "a")), c("id", "name", "tags"))
})

test_that("extend inherits the parent's class and fields", {
  U <- mk_user()
  Ad <- extend(U, "TAdmin", perms = list_of(chr[1]))
  root <- Ad(id = 1, name = "root", perms = list("all"))
  expect_s3_class(root, "TUser")
  expect_true(is_valid(U, root))
})

test_that("a subclass may retype a parent field", {
  U <- mk_user()
  Ov <- extend(U, "TOverride", id = chr[1])
  expect_identical(Ov(id = "x", name = "n")$id, "x")
  expect_identical(fields(Ov), c("id", "name", "tags"))
})

test_that("partial makes every field optional and drops defaults", {
  U <- mk_user()
  P <- partial(U)
  p <- P(name = "Grace")
  expect_null(p$id)
  expect_null(p$tags)
  expect_identical(p$name, "Grace")
})

test_that("a self-reference resolves through the registry", {
  Node <- model("TNode", value = int[1], nxt = opt("TNode"))
  n <- Node(value = 1, nxt = list(value = 2))
  expect_identical(n$nxt$value, 2L)
})

test_that("an unresolvable reference is a typed error", {
  expect_error(parse_as(ref("TNeverDefined"), list()), class = "typed_error")
})

test_that("redefining a model warns", {
  model("TDrift", a = int[1])
  expect_warning(model("TDrift", a = chr[1]), "redefined")
})

test_that("printing shows the fields", {
  expect_output(print(mk_user()), "<model> TUser", fixed = TRUE)
  expect_output(print(mk_user()(id = 1, name = "Ada")), "<TUser>", fixed = TRUE)
})
