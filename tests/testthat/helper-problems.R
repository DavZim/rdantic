#' Paths of the problems a typed_error carries, or an empty vector if none.
problem_paths <- function(expr) {
  tryCatch(
    {
      force(expr)
      character()
    },
    typed_error = function(e) vapply(e$problems, function(p) p$path, "")
  )
}

#' Hint of the first problem a typed_error carries, or NA.
problem_hint <- function(expr) {
  tryCatch(
    {
      force(expr)
      NA_character_
    },
    typed_error = function(e) {
      h <- e$problems[[1]]$hint
      if (is.null(h)) NA_character_ else h
    }
  )
}
