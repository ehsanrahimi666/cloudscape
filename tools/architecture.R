# ---------------------------------------------------------------------------
# Architecture contract.
#
# The design divides the package into layers, and a lower layer must never call
# into a higher one. Stated in prose this is an aspiration; checked mechanically
# it is a contract. This file provides the analyser; test-architecture.R turns
# it into an assertion.
#
# The check is deliberately blunt: it works from the parse tree, so it counts
# any mention of a symbol, and it will occasionally flag something harmless.
# That is the right trade-off. A false positive costs a minute; an unnoticed
# upward dependency costs the ability to reason about the package at all.
# ---------------------------------------------------------------------------

cs_layers <- function() {
  c(
    # Layer 0: foundation. Depends on nothing in the package.
    "aaa-config.R"   = 0L,
    "sensors.R"      = 0L,
    "grid.R"         = 0L,
    # Layer 1: data representation and access.
    "classes.R"      = 1L,
    "catalog.R"      = 1L,
    # Layer 2: pixel-level processing.
    "preprocess.R"   = 2L,
    "shadow.R"       = 2L,
    "probability.R"  = 2L,
    "uncertainty.R"  = 2L,
    # Layer 3: analysis built on the layers below.
    "availability.R" = 3L,
    "simulate.R"     = 3L,
    "evaluate.R"     = 3L,
    "phenology.R"    = 3L,
    # Layer 4: orchestration and output.
    "engine.R"       = 4L,
    "viz.R"          = 4L,
    # Registration only; exempt.
    "zzz.R"          = 99L
  )
}

# Map every function defined at top level to the file that defines it.
cs_definitions <- function(dir = "R") {
  out <- list()
  for (f in list.files(dir, pattern = "\\.R$", full.names = TRUE)) {
    exprs <- parse(f, keep.source = FALSE)
    for (e in exprs) {
      if (is.call(e) && as.character(e[[1L]]) %in% c("<-", "=", "<<-") &&
          length(e) == 3L && is.name(e[[2L]]) && is.call(e[[3L]]) &&
          identical(as.character(e[[3L]][[1L]]), "function")) {
        out[[as.character(e[[2L]])]] <- basename(f)
      }
    }
  }
  out
}

# Every symbol mentioned in a file.
cs_symbols <- function(path) {
  unique(all.names(parse(path, keep.source = FALSE)))
}

#' Report upward dependencies between layers
#'
#' @param dir Source directory.
#' @return A data frame of violations; zero rows means the contract holds.
cs_check_layers <- function(dir = "R") {
  defs <- cs_definitions(dir)
  lay <- cs_layers()
  viol <- list()
  for (f in list.files(dir, pattern = "\\.R$", full.names = TRUE)) {
    bn <- basename(f)
    if (is.na(lay[bn])) {
      viol[[length(viol) + 1L]] <- data.frame(
        file = bn, calls = NA_character_, defined_in = NA_character_,
        from_layer = NA_integer_, to_layer = NA_integer_,
        problem = "file not assigned to a layer", stringsAsFactors = FALSE)
      next
    }
    if (lay[[bn]] == 99L) next
    for (s in cs_symbols(f)) {
      home <- defs[[s]]
      if (is.null(home) || identical(home, bn)) next
      if (is.na(lay[home]) || lay[[home]] == 99L) next
      if (lay[[home]] > lay[[bn]]) {
        viol[[length(viol) + 1L]] <- data.frame(
          file = bn, calls = s, defined_in = home,
          from_layer = lay[[bn]], to_layer = lay[[home]],
          problem = "lower layer depends on higher layer",
          stringsAsFactors = FALSE)
      }
    }
  }
  if (!length(viol)) {
    return(data.frame(file = character(), calls = character(),
                      defined_in = character(), from_layer = integer(),
                      to_layer = integer(), problem = character(),
                      stringsAsFactors = FALSE))
  }
  do.call(rbind, viol)
}

#' Report exported functions whose documentation is incomplete
#'
#' Catches the failures `R CMD check` reports as "undocumented arguments" and
#' "missing \\value", which are the two most common reasons a first CRAN
#' submission is rejected.
#'
#' @param dir Source directory.
#' @return A data frame of documentation problems.
cs_check_docs <- function(dir = "R") {
  probs <- list()
  add <- function(fn, file, what) {
    probs[[length(probs) + 1L]] <<- data.frame(
      fn = fn, file = basename(file), problem = what, stringsAsFactors = FALSE)
  }
  for (f in list.files(dir, pattern = "\\.R$", full.names = TRUE)) {
    lines <- readLines(f, warn = FALSE)
    # Collect roxygen blocks with their following definition
    i <- 1L
    while (i <= length(lines)) {
      if (grepl("^\\s*#'", lines[i])) {
        j <- i
        while (j <= length(lines) && grepl("^\\s*#'", lines[j])) j <- j + 1L
        block <- lines[i:(j - 1L)]
        # find the definition that follows
        k <- j
        while (k <= length(lines) && !grepl("<-\\s*function", lines[k]) &&
               trimws(lines[k]) == "") k <- k + 1L
        if (k <= length(lines) && grepl("<-\\s*function", lines[k])) {
          fn <- sub("\\s*<-.*$", "", trimws(lines[k]))
          exported <- any(grepl("^\\s*#'\\s*@export", block))
          internal <- any(grepl("@keywords\\s+internal|@noRd", block))
          # A block containing only directives generates no .Rd file, so R CMD
          # check never asks it for documentation. This is the standard way to
          # register an S3 method, and flagging it would be a false positive.
          body_txt <- grep("^\\s*#'\\s*(@|$)", block, invert = TRUE, value = TRUE)
          directive_only <- length(body_txt) == 0L
          # @rdname and @describeIn merge into another topic, which supplies
          # the @return; check the group, not the individual block.
          rd <- regmatches(block, regexpr("(?<=@rdname\\s)[^\\s]+", block, perl = TRUE))
          shares_topic <- length(unlist(rd)) > 0L ||
            any(grepl("@describeIn|@inherit", block))
          if (exported && !internal && !directive_only && !shares_topic &&
              !grepl("^\\.", fn)) {
            if (!any(grepl("^\\s*#'\\s*@return", block))) add(fn, f, "missing @return")
            # Documented parameters
            docd <- unlist(lapply(
              regmatches(block, regexpr("(?<=@param\\s)[^\\s]+", block, perl = TRUE)),
              function(x) strsplit(x, ",")[[1L]]))
            inherits_p <- any(grepl("@inheritParams|@rdname|@describeIn", block))
            # Formal arguments: read them from the definition
            src <- paste(lines[k:min(length(lines), k + 40L)], collapse = "\n")
            fun <- tryCatch(eval(parse(text = sub("^.*?<-", "", src))[[1L]]),
                            error = function(e) NULL)
            if (!is.null(fun) && is.function(fun) && !inherits_p) {
              formals_n <- setdiff(names(formals(fun)), "...")
              missing <- setdiff(formals_n, docd)
              if (length(missing)) {
                add(fn, f, paste("undocumented argument(s):",
                                 paste(missing, collapse = ", ")))
              }
            }
          }
        }
        i <- j
      } else i <- i + 1L
    }
  }
  if (!length(probs)) {
    return(data.frame(fn = character(), file = character(),
                      problem = character(), stringsAsFactors = FALSE))
  }
  do.call(rbind, probs)
}
