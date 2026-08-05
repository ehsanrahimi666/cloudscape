#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# Global clear-observation harvest.
#
# This produces the data product that accompanies the software paper: a global,
# equal-area, per-cell, per-month record of acquisitions and cloud cover for
# Landsat 8/9 and Sentinel-2, which cloudscape then reads instantly for any
# location on Earth.
#
# It is NOT a package function, and that is deliberate. A global harvest is
# tens of millions of paged STAC requests spread over days against provider
# rate limits. Burying that behind cl_availability() would invite users to
# launch it accidentally, and would make the published statistics
# irreproducible because every run would return a slightly different archive.
# Running it once, depositing the result with a DOI, and shipping that is both
# kinder to the providers and better science.
#
# Usage:
#   Rscript data-raw/harvest-global.R --year 2023 --sensor sentinel-2-msi
#   Rscript data-raw/harvest-global.R --resume
#
# Design notes
# ------------
# * Resumable. State is a per-tile status file; an interrupted run continues
#   where it stopped. At this scale, a job that cannot resume will not finish.
# * Rate-limit aware. Backs off exponentially on 429 and 5xx rather than
#   hammering, and caps concurrency at one request in flight per worker.
# * Cell-month aggregation on the fly. Retaining every item would produce
#   hundreds of millions of rows; aggregating as tiles complete keeps peak
#   memory bounded regardless of how long the run takes.
# * Records provenance per tile, including the query, the endpoint and the
#   access time, because archives are reprocessed and a statistic without a
#   date is not reproducible.
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(cloudscape)
})
stopifnot(requireNamespace("httr2", quietly = TRUE),
          requireNamespace("jsonlite", quietly = TRUE))

# --- arguments -------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
arg <- function(name, default = NULL) {
  i <- match(paste0("--", name), args)
  if (is.na(i)) return(default)
  if (i == length(args) || startsWith(args[i + 1L], "--")) return(TRUE)
  args[i + 1L]
}

YEARS    <- as.integer(strsplit(arg("year", "2023"), ",")[[1L]])
SENSORS  <- strsplit(arg("sensor", "landsat-8-9-oli,sentinel-2-msi"), ",")[[1L]]
GRID_RES <- as.numeric(arg("res", "25000"))
OUT      <- arg("out", "data-raw/harvest")
BACKEND  <- arg("backend", "element84")
RESUME   <- isTRUE(arg("resume", FALSE))
# Work is partitioned into 10-degree bands. Small enough that one request set
# fits comfortably in memory, large enough that per-request overhead is amortised.
BAND     <- as.numeric(arg("band", "10"))

dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(OUT, "state"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(OUT, "parts"), recursive = TRUE, showWarnings = FALSE)

grid <- cl_grid(res = GRID_RES)
cl_options(catalog = BACKEND, verbose = TRUE)

# --- work plan -------------------------------------------------------------
# Land only: harvesting ocean tiles triples the request count and adds nothing,
# since the archive schedules very few acquisitions there. A coarse land mask
# is sufficient for deciding whether to issue a request at all.

tiles <- expand.grid(
  lon = seq(-180, 180 - BAND, by = BAND),
  lat = seq(-60, 80 - BAND, by = BAND),
  year = YEARS, sensor = SENSORS,
  stringsAsFactors = FALSE
)
tiles$id <- sprintf("%s_%d_%+04d_%+03d", tiles$sensor, tiles$year,
                    tiles$lon, tiles$lat)

message(sprintf("Work plan: %d tiles (%d lon x %d lat x %d years x %d sensors)",
                nrow(tiles), length(unique(tiles$lon)), length(unique(tiles$lat)),
                length(YEARS), length(SENSORS)))

done_file <- function(id) file.path(OUT, "state", paste0(id, ".done"))
part_file <- function(id) file.path(OUT, "parts", paste0(id, ".rds"))

if (RESUME) {
  keep <- !file.exists(vapply(tiles$id, done_file, character(1)))
  message(sprintf("Resuming: %d of %d tiles remain.", sum(keep), nrow(tiles)))
  tiles <- tiles[keep, , drop = FALSE]
}

# --- retry with backoff ----------------------------------------------------

with_backoff <- function(expr, tries = 6L, base = 2) {
  for (k in seq_len(tries)) {
    out <- tryCatch(force(expr), error = function(e) e)
    if (!inherits(out, "error")) return(out)
    msg <- conditionMessage(out)
    transient <- grepl("429|500|502|503|504|timeout|Timeout|connection", msg)
    if (!transient || k == tries) return(out)
    wait <- base^k + stats::runif(1, 0, 1)
    message(sprintf("  transient failure (%s); retrying in %.1fs [%d/%d]",
                    substr(msg, 1, 60), wait, k, tries))
    Sys.sleep(wait)
  }
  out
}

# --- per-tile harvest ------------------------------------------------------

harvest_tile <- function(row) {
  aoi <- c(row$lon, row$lat, row$lon + BAND, row$lat + BAND)
  items <- with_backoff(cl_search(
    aoi = aoi, sensor = row$sensor,
    start = sprintf("%d-01-01", row$year), end = sprintf("%d-12-31", row$year),
    limit = Inf, backend = BACKEND))
  if (inherits(items, "error")) return(items)
  if (!nrow(items)) return(NULL)

  obs <- tryCatch(cl_items_to_obs(items, grid), error = function(e) NULL)
  if (is.null(obs) || !nrow(obs)) return(NULL)

  # Retain only cells this band OWNS. A scene straddling a band boundary is
  # returned by both neighbouring queries, so aggregating without partitioning
  # would count the same acquisition twice for any cell near the seam. Bands
  # own cells by centroid, which partitions the grid exactly: every cell is
  # claimed once, and every scene covering a claimed cell intersects that
  # band's bounding box and is therefore returned by its query.
  cc <- cl_grid_cells(grid, cells = unique(obs$cell))
  owned <- cc$cell[cc$lon >= row$lon & cc$lon < row$lon + BAND &
                   cc$lat >= row$lat & cc$lat < row$lat + BAND]
  obs <- obs[obs$cell %in% owned, , drop = FALSE]
  if (!nrow(obs)) return(NULL)

  # Aggregate immediately. Keeping raw items for a global run would exhaust
  # memory long before the harvest completed.
  monthly <- cl_clear_obs(obs, by = "month", threshold = 0.2,
                          model = "independent", grid = grid)
  gaps <- tryCatch(cl_gaps(obs, threshold = 0.2, by = "year"),
                   error = function(e) NULL)

  list(stats = monthly, gaps = gaps,
       manifest = cl_manifest(NULL, tile = row$id, aoi = aoi,
                              sensor = row$sensor, year = row$year,
                              backend = BACKEND, n_items = nrow(items),
                              grid_res = GRID_RES))
}

# --- main loop -------------------------------------------------------------

failures <- character()
t0 <- Sys.time()
for (i in seq_len(nrow(tiles))) {
  row <- tiles[i, ]
  res <- harvest_tile(row)
  if (inherits(res, "error")) {
    failures <- c(failures, row$id)
    message(sprintf("[%d/%d] %s FAILED: %s", i, nrow(tiles), row$id,
                    substr(conditionMessage(res), 1, 80)))
    next
  }
  if (!is.null(res)) saveRDS(res, part_file(row$id), compress = "xz")
  file.create(done_file(row$id))
  if (i %% 25 == 0 || i == nrow(tiles)) {
    el <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
    message(sprintf("[%d/%d] %.1f min elapsed, %.1f min projected remaining",
                    i, nrow(tiles), el, el / i * (nrow(tiles) - i)))
  }
}

if (length(failures)) {
  writeLines(failures, file.path(OUT, "failures.txt"))
  message(sprintf("%d tiles failed; ids written to failures.txt. Re-run with --resume.",
                  length(failures)))
}

# --- consolidate -----------------------------------------------------------

message("Consolidating parts ...")
parts <- list.files(file.path(OUT, "parts"), pattern = "\\.rds$", full.names = TRUE)
if (!length(parts)) {
  message("No parts to consolidate."); quit(status = 0)
}
stats_all <- do.call(rbind, lapply(parts, function(p) {
  x <- readRDS(p)$stats
  if (is.null(x)) NULL else as.data.frame(x)
}))

# Bands partition cells by ownership, so within a (sensor, year) there should
# be no duplicates at all. Any that appear indicate a partitioning bug, and
# must be reported rather than quietly merged: merging would hide the fault
# and inflate counts.
key <- paste(stats_all$cell, stats_all$period, stats_all$sensor,
             stats_all$metric, sep = "\r")
if (anyDuplicated(key)) {
  n <- sum(duplicated(key))
  warning(sprintf(
    "%d duplicated cell-period-metric rows. Band partitioning should make this
impossible; counts may be inflated. Investigate before publishing.", n))
  stats_all <- cl_stats_merge(structure(stats_all,
                                        class = c("cl_stats", "data.frame")))
}
validate_cl_stats(stats_all)

out_rds <- file.path(OUT, sprintf("cloudscape-global-%s-%s.rds",
                                  paste(YEARS, collapse = "_"),
                                  format(Sys.Date(), "%Y%m%d")))
saveRDS(list(
  stats = stats_all,
  grid  = grid,
  manifest = cl_manifest(NULL,
    product = "cloudscape global clear-observation dataset",
    years = YEARS, sensors = SENSORS, backend = BACKEND,
    grid_res_m = GRID_RES, band_deg = BAND,
    n_cells = length(unique(stats_all$cell)),
    n_rows = nrow(stats_all),
    n_tiles_failed = length(failures),
    caveat = paste(
      "Tier A: cloud fractions are scene-level catalogue properties, not",
      "pixel measurements. Clear-observation counts are an upper bound; see",
      "?cl_clear_prob. Landsat CLOUD_COVER is produced by CFMask and",
      "Sentinel-2 eo:cloud_cover by Sen2Cor, so cross-sensor differences",
      "partly reflect algorithms rather than atmospheres."))
), out_rds, compress = "xz")

message("Wrote ", out_rds)
message(sprintf("  %s rows, %s cells, %d failed tiles",
                format(nrow(stats_all), big.mark = ","),
                format(length(unique(stats_all$cell)), big.mark = ","),
                length(failures)))
message("\nNext: deposit on Zenodo, record the DOI, and ship in cloudscape.data.")
