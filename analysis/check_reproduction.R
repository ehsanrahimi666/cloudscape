# Compares the outputs of a new run with a reference copy of analysis/output,
# for example the outputs archived with a release:
#   Rscript analysis/check_reproduction.R REFERENCE_DIR [TOLERANCE]
# Numeric columns are compared with a relative tolerance (default 1e-6) and
# all other columns exactly. Writes the comparison to the console and exits
# with status 1 when any table differs.
args <- commandArgs(trailingOnly = TRUE)
ref_dir <- args[1]
tol <- if (length(args) > 1) as.numeric(args[2]) else 1e-6
new_dir <- file.path("analysis", "output")
files <- sort(list.files(ref_dir, pattern = "\\.csv$", recursive = TRUE))
same <- function(a, b) {
  if (!identical(dim(a), dim(b)) || !identical(names(a), names(b))) return(FALSE)
  all(vapply(names(a), function(k) {
    x <- a[[k]]; y <- b[[k]]
    if (is.numeric(x) && is.numeric(y)) {
      ok <- (is.na(x) & is.na(y)) | abs(x - y) <= tol * pmax(1, abs(x), abs(y))
      all(ok %in% TRUE)
    } else identical(as.character(x), as.character(y))
  }, logical(1)))
}
res <- vapply(files, function(f) {
  n <- file.path(new_dir, f)
  if (!file.exists(n)) return("missing")
  a <- utils::read.csv(file.path(ref_dir, f), stringsAsFactors = FALSE)
  b <- utils::read.csv(n, stringsAsFactors = FALSE)
  # Software versions are properties of the session, not results.
  if (basename(f) == "numbers.csv") {
    a <- a[a$source != "R session", ]; b <- b[b$source != "R session", ]
    rownames(a) <- rownames(b) <- NULL
  }
  if (same(a, b)) "identical" else "different"
}, character(1))
print(data.frame(file = files, result = unname(res)), row.names = FALSE)
message(sum(res == "identical"), " of ", length(res), " tables reproduced within a relative tolerance of ", tol)
if (any(res != "identical")) quit(status = 1)
