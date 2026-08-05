#' @keywords internal
"_PACKAGE"

# ---------------------------------------------------------------------------
# Module 0c: configuration, dependency guards, assertions, provenance
# ---------------------------------------------------------------------------

.cs_env <- new.env(parent = emptyenv())

.cs_defaults <- list(
  catalog        = "element84",
  grid_res       = 25000,
  grid_crs       = 6933,
  chunk_pixels   = 4e6,
  workers        = 1L,
  cache_dir      = NULL,
  timeout        = 60,
  max_page       = 500L,
  verbose        = TRUE
)

#' Get or set package options
#'
#' `cl_options()` is the single configuration entry point for cloudscape.
#' Called with no arguments it returns the full option list. Called with named
#' arguments it sets them and returns the previous values invisibly, so it can
#' be used with [base::on.exit()] to make temporary changes.
#'
#' @param ... Named options to set. Supported names:
#'   \describe{
#'     \item{`catalog`}{Default STAC backend, one of `"element84"`,
#'       `"planetary"`, `"cdse"`.}
#'     \item{`grid_res`}{Default analysis grid resolution in metres.}
#'     \item{`grid_crs`}{EPSG code of the equal-area analysis CRS.
#'       Defaults to 6933 (EASE-Grid 2.0 global).}
#'     \item{`chunk_pixels`}{Target pixels per processing block.}
#'     \item{`workers`}{Number of parallel workers.}
#'     \item{`cache_dir`}{Directory for downloaded assets and harvest state.}
#'     \item{`timeout`}{HTTP timeout in seconds.}
#'     \item{`max_page`}{Maximum STAC items requested per page.}
#'     \item{`verbose`}{Emit progress messages.}
#'   }
#'
#' @return A named list of options. When setting, the previous values are
#'   returned invisibly.
#' @export
#' @examples
#' old <- cl_options(verbose = FALSE)
#' cl_options()$verbose
#' cl_options(old)
cl_options <- function(...) {
  args <- list(...)
  if (length(args) == 1L && is.null(names(args)) && is.list(args[[1L]])) {
    args <- args[[1L]]
  }
  if (!length(args)) {
    return(utils::modifyList(.cs_defaults, as.list(.cs_env)))
  }
  if (is.null(names(args)) || any(!nzchar(names(args)))) {
    stop("All options must be named.", call. = FALSE)
  }
  unknown <- setdiff(names(args), names(.cs_defaults))
  if (length(unknown)) {
    stop("Unknown option(s): ", paste(unknown, collapse = ", "), call. = FALSE)
  }
  old <- cl_options()[names(args)]
  for (nm in names(args)) assign(nm, args[[nm]], envir = .cs_env)
  invisible(old)
}

#' Locate the cloudscape cache directory
#'
#' Downloaded assets, resumable harvest state and companion datasets are stored
#' here. The location follows, in order of precedence: the `cache_dir` option,
#' the `CLOUDSCAPE_CACHE` environment variable, then a user-level cache path.
#'
#' @param create Create the directory if it does not exist.
#' @return Absolute path to the cache directory.
#' @export
cl_cache_dir <- function(create = TRUE) {
  d <- cl_options()$cache_dir
  if (is.null(d)) d <- Sys.getenv("CLOUDSCAPE_CACHE", unset = "")
  if (!nzchar(d)) {
    d <- file.path(
      if (nzchar(Sys.getenv("XDG_CACHE_HOME"))) Sys.getenv("XDG_CACHE_HOME")
      else file.path(path.expand("~"), ".cache"),
      "cloudscape"
    )
  }
  if (create && !dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  normalizePath(d, mustWork = FALSE)
}

# --- dependency guards -----------------------------------------------------

#' Require a suggested package
#'
#' cloudscape keeps its hard dependency surface small: the statistical core
#' (availability, gaps, seasonality, phenology, evaluation, simulation) runs on
#' base R alone, while raster and network functionality is gated behind
#' suggested packages. This helper produces a single actionable error rather
#' than an opaque failure deep in a call stack.
#'
#' @param pkg Package name(s).
#' @param reason Short description of what the package is needed for.
#' @return `TRUE` invisibly if all packages are available; otherwise an error.
#' @export
cl_require <- function(pkg, reason = NULL) {
  missing <- pkg[!vapply(pkg, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) {
    stop(
      sprintf(
        "%s requires the %s package%s.%s\n  install.packages(c(%s))",
        if (is.null(reason)) "This operation" else reason,
        paste(sQuote(missing), collapse = ", "),
        if (length(missing) > 1L) "s" else "",
        "",
        paste(sprintf('"%s"', missing), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

cl_has <- function(pkg) all(vapply(pkg, requireNamespace, logical(1), quietly = TRUE))

# --- messaging -------------------------------------------------------------

cl_msg <- function(...) {
  if (isTRUE(cl_options()$verbose)) message(...)
  invisible(NULL)
}

cl_abort <- function(...) stop(paste0(...), call. = FALSE)

cl_warn <- function(...) warning(paste0(...), call. = FALSE, immediate. = TRUE)

# --- assertions ------------------------------------------------------------

cl_assert <- function(cond, ...) {
  if (!isTRUE(all(cond))) cl_abort(...)
  invisible(TRUE)
}

cl_assert_number <- function(x, name, lower = -Inf, upper = Inf, len = NULL) {
  if (!is.numeric(x)) cl_abort("`", name, "` must be numeric, not ", class(x)[1L], ".")
  if (!is.null(len) && length(x) != len) {
    cl_abort("`", name, "` must have length ", len, ", not ", length(x), ".")
  }
  if (any(!is.finite(x))) cl_abort("`", name, "` must be finite.")
  if (any(x < lower | x > upper)) {
    cl_abort("`", name, "` must lie in [", lower, ", ", upper, "].")
  }
  invisible(TRUE)
}

cl_assert_fraction <- function(x, name) {
  cl_assert_number(x, name, lower = 0, upper = 1)
}

cl_assert_choice <- function(x, name, choices) {
  if (length(x) != 1L || !x %in% choices) {
    cl_abort("`", name, "` must be one of: ", paste(choices, collapse = ", "), ".")
  }
  invisible(TRUE)
}

# --- provenance ------------------------------------------------------------

#' Create or extract a provenance manifest
#'
#' Satellite archives are reprocessed. Collection 2 changed Landsat cloud
#' masking relative to Collection 1, and successive Sen2Cor baselines changed
#' the Sentinel-2 scene classification layer. A statistic computed today may
#' therefore differ from the same statistic computed on the same nominal data
#' next year. Every cloudscape object carries a manifest recording exactly what
#' was queried, when, and with which algorithm, so results remain auditable.
#'
#' @param x An object with a manifest, or `NULL` to build a fresh one.
#' @param ... Named fields to record.
#' @return An object of class `cl_manifest`: a named list.
#' @export
#' @examples
#' m <- cl_manifest(NULL, source = "element84", collection = "sentinel-2-l2a")
#' m$collection
cl_manifest <- function(x = NULL, ...) {
  if (!is.null(x) && !inherits(x, "cl_manifest")) {
    m <- attr(x, "manifest")
    if (!is.null(m)) return(m)
  }
  if (inherits(x, "cl_manifest")) {
    base <- unclass(x)
  } else {
    base <- list(
      cloudscape_version = tryCatch(
        as.character(utils::packageVersion("cloudscape")),
        error = function(e) "unknown"
      ),
      r_version = R.version.string,
      created   = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
    )
  }
  extra <- list(...)
  if (length(extra)) base <- utils::modifyList(base, extra)
  structure(base, class = "cl_manifest")
}

#' @export
print.cl_manifest <- function(x, ...) {
  cat("<cl_manifest>\n")
  for (nm in names(x)) {
    v <- x[[nm]]
    if (is.list(v)) v <- paste0("<", length(v), " element list>")
    if (length(v) > 3L) v <- paste0(paste(utils::head(v, 3L), collapse = ", "), ", ...")
    cat(sprintf("  %-20s %s\n", nm, paste(v, collapse = ", ")))
  }
  invisible(x)
}

# --- small numeric helpers -------------------------------------------------

# Dimension-safe clamp.
#
# pmax(0, m) silently returns a plain vector when m is a matrix, because pmin
# and pmax take attributes from their *first* argument. Writing the bound first
# is natural and reads correctly, so the mistake is easy to make and produces a
# failure far from its cause. Every clamp in the package goes through this.
.cs_clamp <- function(x, lo = 0, hi = 1) {
  out <- pmin(pmax(x, lo), hi)
  if (!is.null(dim(x))) dim(out) <- dim(x)
  out
}

deg2rad <- function(d) d * pi / 180
rad2deg <- function(r) r * 180 / pi

`%||%` <- function(a, b) if (is.null(a)) b else a
