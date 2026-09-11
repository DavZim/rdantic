# Loader for using rdantic without installing it: source("rdantic.R") defines
# everything in the calling environment, exactly as the single-file version did.
# The sources, and their roxygen documentation, live in R/.

local({
  files <- c(
    "problems.R",
    "type.R",
    "primitives.R",
    "temporal.R",
    "combinators.R",
    "containers.R",
    "model.R",
    "fn.R",
    "serialize.R"
  )

  # the directory holding this file, whichever way it was sourced
  here <- "."
  for (i in seq_len(sys.nframe())) {
    of <- sys.frame(i)$ofile
    if (!is.null(of)) here <- dirname(normalizePath(of))
  }
  root <- file.path(here, "R")
  if (!dir.exists(root)) stop("cannot find the R/ directory next to rdantic.R")

  target <- parent.frame(2)
  for (f in files) sys.source(file.path(root, f), envir = target)
})
