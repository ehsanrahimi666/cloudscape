# Minimal base-R harness that runs the testthat suite without testthat.
# Used for validation in environments where CRAN is unreachable. The real
# suite runs under testthat on CI; this exists so the same test files can be
# executed anywhere.
setwd(Sys.getenv("CS_ROOT", "/home/claude/cloudscape"))
for (f in list.files("R", full.names = TRUE)) source(f)
.cs_register_builtin(); .cs_register_methods()

.pass <- 0L; .fail <- 0L; .msgs <- character()
.chk <- function(ok, what, extra = "") {
  if (isTRUE(ok)) .pass <<- .pass + 1L else {
    .fail <<- .fail + 1L
    .msgs <<- c(.msgs, paste0("  FAIL [", .ctx, "] ", what, " ", extra))
  }
}
.ctx <- "<none>"
# An error inside a block must count as a failure. Swallowing it with try()
# made two broken tests report as "16 passed" with the errors printed above
# the tally, which is exactly the kind of green-but-wrong result a test
# harness exists to prevent.
test_that <- function(desc, code) {
  .ctx <<- desc
  e <- tryCatch({ force(code); NULL }, error = function(e) e)
  if (!is.null(e)) {
    .fail <<- .fail + 1L
    .msgs <<- c(.msgs, paste0("  ERROR [", desc, "] ", conditionMessage(e)))
  }
  invisible()
}

expect_true  <- function(x, ...) .chk(isTRUE(all(x)), "expect_true")
expect_false <- function(x, ...) .chk(isTRUE(all(!x)), "expect_false")
expect_gte   <- function(a, b, ...) .chk(all(a >= b), "expect_gte")
expect_null  <- function(x, ...) .chk(is.null(x), "expect_null")
expect_type  <- function(x, ty, ...) .chk(typeof(x) == ty, "expect_type")
expect_named <- function(x, nm = NULL, ...)
  .chk(!is.null(names(x)) && (is.null(nm) || setequal(names(x), nm)), "expect_named")
expect_length <- function(x, n, ...) .chk(length(x) == n, "expect_length")
skip_on_cran <- function(...) invisible(TRUE)
skip_if_not <- function(cond, msg = "") if (!isTRUE(cond)) stop("SKIP: ", msg)
expect_no_error <- function(expr, ...)
  .chk(is.null(tryCatch({ force(expr); NULL }, error = function(e) e)), "expect_no_error")
expect_lt    <- function(a, b, ...) .chk(all(a < b), "expect_lt", sprintf("(%.6g !< %.6g)", a[1], b[1]))
expect_gt    <- function(a, b, ...) .chk(all(a > b), "expect_gt", sprintf("(%.6g !> %.6g)", a[1], b[1]))
expect_lte   <- function(a, b, ...) .chk(all(a <= b), "expect_lte")
expect_equal <- function(a, b, tolerance = 1e-8, label = "", ...)
  .chk(length(a) == length(b) && all(abs(as.numeric(a) - as.numeric(b)) <= tolerance +
       tolerance * abs(as.numeric(b)), na.rm = TRUE),
       paste("expect_equal", label), sprintf("(%.6g vs %.6g)", as.numeric(a)[1], as.numeric(b)[1]))
expect_setequal <- function(a, b, ...) .chk(setequal(a, b), "expect_setequal")
expect_s3_class <- function(x, cl, ...) .chk(inherits(x, cl), "expect_s3_class")
expect_error <- function(expr, regexp = NULL, ...) {
  e <- tryCatch({ force(expr); NULL }, error = function(e) e)
  .chk(!is.null(e) && (is.null(regexp) || grepl(regexp, conditionMessage(e))),
       "expect_error", if (is.null(e)) "(no error raised)" else "")
}
expect_warning <- function(expr, regexp = NULL, ...) {
  w <- NULL
  val <- withCallingHandlers(tryCatch(expr, error = function(e) NULL),
    warning = function(x) { w <<- x; invokeRestart("muffleWarning") })
  .chk(!is.null(w) && (is.null(regexp) || grepl(regexp, conditionMessage(w))), "expect_warning")
  invisible(val)
}
expect_message <- function(expr, regexp = NULL, ...) {
  m <- NULL
  withCallingHandlers(tryCatch(expr, error = function(e) NULL),
    message = function(x) { m <<- x; invokeRestart("muffleMessage") })
  .chk(!is.null(m) && (is.null(regexp) || grepl(regexp, conditionMessage(m))), "expect_message")
}

# testthat sources helper-*.R automatically; do the same.
for (h in list.files("tests/testthat", pattern = "^helper-.*\\.R$", full.names = TRUE)) {
  source(h)
}
files <- list.files("tests/testthat", pattern = "^test-.*\\.R$", full.names = TRUE)
for (f in files) {
  cat("\n==", basename(f), "==\n")
  p0 <- .pass; f0 <- .fail
  # `cloudscape:::x` cannot resolve when the package is sourced rather than
  # installed. Redefining `:::` breaks R's own byte-compiler, so strip the
  # qualifier from the source text instead; under testthat the real namespace
  # is present and the tests run unmodified.
  txt <- gsub("cloudscape:::", "", readLines(f, warn = FALSE), fixed = TRUE)
  # Tests locate package sources relative to tests/testthat/ under testthat;
  # the harness runs from the package root.
  txt <- gsub('"../../R"', '"R"', txt, fixed = TRUE)
  txt <- gsub('"../../tools/architecture.R"', '"tools/architecture.R"', txt, fixed = TRUE)
  env <- new.env(parent = globalenv())
  suppressMessages(suppressWarnings(eval(parse(text = txt), envir = env)))
  cat(sprintf("   %d passed, %d failed\n", .pass - p0, .fail - f0))
}
cat("\n---------------------------------------------\n")
cat(sprintf("TOTAL: %d passed, %d failed\n", .pass, .fail))
if (length(.msgs)) cat(paste(.msgs, collapse = "\n"), "\n")
quit(status = if (.fail > 0) 1 else 0)
