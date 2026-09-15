mk_user <- function() {
  struct("TUser", id = int[1], name = chr[1], tags = chr %default% character())
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
  b <- readRDS(f)
  # the spec attribute is an environment: same content, but not the same
  # object once deserialised, so compare structurally rather than raw identity
  expect_identical(class(b), class(a))
  expect_identical(as.list(b), as.list(a))
})

test_that("assignment runs the field's type", {
  U <- mk_user()
  a <- U(id = 1, name = "Ada")
  a$name <- "Grace"
  expect_identical(a$name, "Grace")
  expect_error(a$name <- 42, class = "typed_error")
})

test_that("[<- runs the field's type just like $<- and [[<-", {
  U <- mk_user()
  a <- U(id = 1, name = "Ada")
  a["name"] <- "Grace"
  expect_identical(a$name, "Grace")
  expect_error(a["name"] <- list(42), class = "typed_error")
  expect_true(is_valid(U, a))
})

test_that("[<- can set several fields at once, each validated", {
  U <- mk_user()
  a <- U(id = 1, name = "Ada")
  a[c("id", "name")] <- list(2L, "Grace")
  expect_identical(a$id, 2L)
  expect_identical(a$name, "Grace")
  expect_error(a[c("id", "name")] <- list("nope", "Grace"), class = "typed_error")
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

test_that("a different struct is not parsed as this one", {
  U <- mk_user()
  a <- U(id = 1, name = "Ada")
  V <- struct("TOther", id = int[1], name = chr[1])
  expect_length(problem_paths(parse_as(V, a)), 1)
})

test_that("a plain list is parsed where a struct is expected", {
  U <- mk_user()
  expect_identical(from_list(U, list(id = 2, name = "Bob"))$id, 2L)
  expect_identical(from_list(U, list(id = 2, name = "Bob", z = 1))$id, 2L)
})

test_that("a struct can forbid unknown keys", {
  S <- struct("TShut", x = int[1], .extra = "forbid")
  expect_identical(problem_paths(from_list(S, list(x = 1, y = 2))), "$y")
})

test_that("structs nest and report the full path", {
  U <- mk_user()
  Team <- struct("TTeam", lead = U, roster = frame(id = int, name = chr))
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
  Node <- struct("TNode", value = int[1], nxt = opt("TNode"))
  n <- Node(value = 1, nxt = list(value = 2))
  expect_identical(n$nxt$value, 2L)
})

test_that("an unresolvable reference is a typed error", {
  expect_error(parse_as(ref("TNeverDefined"), list()), class = "typed_error")
})

test_that("redefining a struct warns", {
  struct("TDrift", a = int[1])
  expect_warning(struct("TDrift", a = chr[1]), "redefined")
})

test_that("struct rejects field names that collide with its own internals", {
  expect_error(struct("TArgsField", .args = int[1]), "reserved")
  expect_error(struct("TSpecField", .spec_ = int[1]), "reserved")
  expect_error(struct("TSpecEnvField", .spec_env_ = int[1]), "reserved")
})

test_that("printing shows the fields", {
  expect_output(print(mk_user()), "<struct> TUser", fixed = TRUE)
  expect_output(print(mk_user()(id = 1, name = "Ada")), "<TUser>", fixed = TRUE)
})

test_that("struct(.description = ) sets the schema's top-level description", {
  U <- struct("TDescribed", .description = "A described struct.", a = int[1])
  expect_identical(schema(U)$description, "A described struct.")
  expect_error(struct("TBadDesc", .description = c("a", "b"), a = int[1]))
})

test_that("field descriptions and .description reproduce the target schema shape", {
  Person <- struct(
    "TPerson",
    .description = "A person record.",
    name = chr[1] %doc% "Full name of the person.",
    age = int[1] %doc% "Age in years.",
    occupation = opt(chr[1]) %doc% "Current job title, or null if unknown.",
    is_active = lgl[1] %doc% "Whether the account is currently active."
  )
  s <- schema(Person)
  expect_identical(s$description, "A person record.")
  expect_identical(s$properties$name, list(type = "string", description = "Full name of the person."))
  expect_identical(s$properties$age, list(type = "integer", description = "Age in years."))
  expect_identical(
    s$properties$occupation,
    list(type = c("string", "null"), description = "Current job title, or null if unknown.")
  )
  expect_identical(s$properties$is_active, list(type = "boolean", description = "Whether the account is currently active."))
  expect_identical(s$required, as.list(c("name", "age", "is_active")))
  expect_false(s$additionalProperties)
})
