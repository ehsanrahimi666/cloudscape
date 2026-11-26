# Compares the outputs of a new run with a reference copy of analysis/output,
# for example the outputs archived with a release:
#   Rscript analysis/check_reproduction.R REFERENCE_DIR [TOLERANCE]
# Numbers, including numbers stored as text, are compared with a relative
# tolerance (default 1e-6) and all other values exactly. Writes the comparison
# to the console, with the columns that differ, and exits with status 1 when
# any table differs.
args <- commandArgs(trailingOnly = TRUE)
ref_dir <- args[1]
tol <- if (length(args) > 1) as.numeric(args[2]) else 1e-6
new_dir <- file.path("analysis", "output")
files <- sort(list.files(ref_dir, pattern = "\\.csv$", recursive = TRUE))

as_num <- function(v) suppressWarnings(as.numeric(as.character(v)))

# Per column: TRUE when every value agrees.
agree <- function(x, y) {
  nx <- as_num(x); ny <- as_num(y)
  both <- !is.na(nx) & !is.na(ny)
  num_ok <- abs(nx - ny) <= tol * pmax(1, abs(nx), abs(ny))
  txt_ok <- (is.na(x) & is.na(y)) | (as.character(x) == as.character(y))
  ok <- ifelse(both, num_ok, txt_ok)
  all(ok %in% TRUE)
}

# Largest relative difference over the numeric values of a column.
max_rel <- function(x, y) {
  nx <- as_num(x); ny <- as_num(y)
  d <- abs(nx - ny) / pmax(1, abs(nx), abs(ny))
  if (all(is.na(d))) NA_real_ else max(d, na.rm = TRUE)
}

compare <- function(f) {
  n <- file.path(new_dir, f)
  if (!file.exists(n)) return(list(result = "missing", detail = ""))
  a <- utils::read.csv(file.path(ref_dir, f), stringsAsFactors = FALSE, check.names = FALSE)
  b <- utils::read.csv(n, stringsAsFactors = FALSE, check.names = FALSE)
  # Software versions are properties of the session, not results.
  if (basename(f) == "numbers.csv") {
    a <- a[a$source != "R session", ]; b <- b[b$source != "R session", ]
    rownames(a) <- rownames(b) <- NULL
  }
  if (!identical(dim(a), dim(b)) || !identical(names(a), names(b)))
    return(list(result = "different", detail = "dimensions or columns differ"))
  bad <- names(a)[!vapply(names(a), function(k) agree(a[[k]], b[[k]]), logical(1))]
  if (!length(bad)) return(list(result = "identical", detail = ""))
  detail <- vapply(bad, function(k) {
    r <- max_rel(a[[k]], b[[k]])
    sprintf("%s (%d values%s)", k, sum(as.character(a[[k]]) != as.character(b[[k]]), na.rm = TRUE),
            if (is.na(r)) "" else sprintf(", largest relative difference %.2g", r))
  }, character(1))
  list(result = "different", detail = paste(detail, collapse = "; "))
}

res <- lapply(files, compare)
result <- vapply(res, `[[`, "", "result")
for (i in seq_along(files)) {
  cat(sprintf("%-45s %s\n", files[i], result[i]))
  if (nzchar(res[[i]]$detail)) cat("    ", res[[i]]$detail, "\n", sep = "")
}
message(sum(result == "identical"), " of ", length(result),
        " tables reproduced within a relative tolerance of ", tol)
if (any(result != "identical")) quit(status = 1)
