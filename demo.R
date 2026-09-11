source("rdantic.R")

show_error <- function(expr)
  tryCatch(expr, typed_error = function(e) cat(conditionMessage(e), "\n\n"))
hr <- function(title) cat("\n==", title, "==\n")

# ---- 1. types are values -------------------------------------------------------
hr("types")
int[1]
num[. >= 0 & . <= 1]
int[1] | NULL
one_of("admin", "user") %default% "user"

int[1](3) # 3L   -- safe coercion
parse_as(list_of(int), list(1, 2, 3)) # list(1L, 2L, 3L)
show_error(int[1](3.5))
show_error(int(1e10)) # coercion must be lossless, so no silent NA
show_error(num[0 <= . & . <= 1](1.2))
show_error(parse_as(list_of(int[1]), list(1, "two", 3.5))) # collects all failures

show_error(no_na(int)(c(1L, NA))) # NA is not a value
show_error(one_of("1", "2")(1)) # the literals are strings, 1 is not
date("2024-05-17") # ISO-8601 text is parsed
show_error(date("17/05/2024"))
fct("low", "high")("high")
show_error(num(Sys.Date())) # a Date is not a number

str(try_parse(int[1], "x")) # errors as data, for input you expect to be wrong
is_valid(int[1], 3)

limits <- list_of(int[1][. > 0]) # a named list is the map type
str(limits(list(cpu = 4, memory = 16)))
show_error(limits(list(cpu = 4, memory = 0))) # reported by key, not by position
print(to_json(limits(list(cpu = 4L, memory = 16L))))

limits <- list_of( # named args instead -> a fixed key set
  cpu = int[1][0 < . & . < 12],
  memory = int[1][0 < . & . < 128]
)
limits
str(limits(list(cpu = 4, memory = 16)))
show_error(limits(list(cpu = 16, memory = 512)))
show_error(limits(list(cpu = 4)))

# ---- 2. models -----------------------------------------------------------------
hr("models")
User <- model(
  "User",
  id = int[1],
  name = chr[1],
  email = chr[1][grepl("@", ., fixed = TRUE)],
  age = int[1] | NULL,
  role = one_of("admin", "user") %default% "user",
  tags = chr %default% character(),
  friend = ref("User") | NULL # self-reference by name
)
User

ada <- User(id = 1, name = "Ada", email = "ada@lovelace.org")
ada
str(ada$id) # int 1 -- coerced from double
ada$age <- 36L
ada$age
copy <- ada
copy$name <- "Grace"
c(ada$name, copy$name) # "Ada" "Grace" -- instances are values, not references
show_error(ada$age <- "thirty-six") # validated on assignment
show_error(ada$nickname <- "Countess") # no such field -> typed_error
show_error(ada$nam) # and reads never partially match
show_error(User(name = 42, email = "nope", role = "god"))

# ---- 3. nesting, aggregated errors ----------------------------------------------
hr("nesting")
Team <- model(
  "Team",
  lead = User,
  members = list_of(User),
  roster = frame(id = int, name = chr)
)

bob <- User(id = 2, name = "Bob", email = "bob@example.org", friend = ada)
team <- Team(
  lead = ada,
  members = list(bob),
  roster = data.frame(id = c(1, 2), name = c("Ada", "Bob"))
)
team
team$members[[1]]$friend$name # "Ada"

show_error(Team(
  lead = list(id = 1, name = "Ada", email = "ada.lovelace"), # plain lists are parsed
  members = list(list(id = 2, name = "Bob", email = "b@b", age = 34.5)),
  roster = data.frame(id = c(1, 2.5), name = c("a", "b"))
))

# ---- 4. inheritance, partials, parsing ------------------------------------------
hr("extend / partial / from_list")
Admin <- extend(User, "Admin", permissions = list_of(chr[1]))
root <- Admin(
  id = 0,
  name = "root",
  email = "root@example.org",
  permissions = list("all")
)
inherits(root, "User") # TRUE
ada$friend <- root # an Admin is a User
ada$friend

UserPatch <- partial(User)
UserPatch(name = "Grace") # defaults are dropped: unset stays unset

from_list(User, list(id = 3, name = "Grace", email = "grace@navy.mil"))

# ---- 5. typed functions --------------------------------------------------------
hr("fn")
bmi <- fn(weight_kg = num[. > 0], height_m = num[. > 0], ~ num[1], {
  weight_kg / height_m^2
})
bmi
bmi(70, 1.75)
bmi(70L, 1.75) # int -> num coercion
show_error(bmi(70, "1.75"))
show_error(bmi(-1, 1.75))
show_error(bmi(70))

greet <- fn(name = chr[1], greeting = chr[1] %default% "Hello", ~ chr[1], {
  paste0(greeting, ", ", name, "!")
})
greet
greet("Ada")
greet("Ada", "Bonjour")

broken <- fn(x = num[1], ~ chr[1], {
  x * 2
})
show_error(broken(1)) # return type is checked too

log_all <- fn(level = one_of("info", "warn"), ... = chr[1], ~ chr[1], {
  paste0("[", level, "] ", paste(..., collapse = " "))
})
log_all("info", "disk", "full")
show_error(log_all("info", "disk", 3)) # `...` is checked element by element

options(rdantic.check = FALSE) # production: checks off, zero cost
broken(1)
options(rdantic.check = TRUE)

# ---- 6. json round-trip & schema (jsonlite) ------------------------------------
hr("json / schema")
print(to_json(ada))
print(to_json(team))
print(to_json(schema(User)))

team2 <- from_json(Team, to_json(team)) # arrays -> vectors, row records -> data.frame
team2
str(team2$roster)
team2$lead$friend # parsed as User: JSON carries no class, so
# Admin's extra `permissions` key is ignored
show_error(from_json(User, '{"id": 1.5, "name": ["a", "b"], "email": "x@y"}'))

Strict <- model("Strict", x = int[1], .extra = "forbid")
show_error(from_list(Strict, list(x = 1, y = 2)))

# ---- 7. chained refinements ------------------------------------------------------
hr("chained refinements")
big_id <- int[1][. > 5]
big_id
big_id(9)
show_error(big_id(3))
show_error(big_id(c(6, 7)))
