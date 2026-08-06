#!/usr/bin/env Rscript
# =============================================================================
#  cloudscape — REAL-DATA ANALYSIS FOR THE MANUSCRIPT
#
#  Run this on your own machine. It queries live satellite catalogues, which
#  the development environment could not reach, and produces the archive-based
#  results the paper needs.
#
#  ---------------------------------------------------------------------------
#  HOW TO RUN
#  ---------------------------------------------------------------------------
#
#    1. Install once:
#         install.packages(c("remotes","httr2","jsonlite"))
#         remotes::install_github("ehsanrahimi666/cloudscape")
#
#    2. Locate this script (it installs with the package):
#         Rscript -e 'cat(system.file("scripts","run-real-analysis.R",package="cloudscape"))'
#
#    3. Test the connection first (30 seconds):
#         Rscript <that path> --mode test
#
#    4. If that works, run the pilot (about 15-30 minutes):
#         Rscript <that path> --mode pilot
#
#    5. If the pilot works, run the full analysis (about 2-5 hours):
#         Rscript <that path> --mode full
#
#    6. Send me the file it prints at the end:
#         cloudscape-results-<date>.zip
#
#    Output goes to ./cloudscape-results/ in the CURRENT directory by default,
#    so run it from somewhere you can write. Override with --out <dir>.
#
#  The run is RESUMABLE. If it stops for any reason - network drop, laptop
#  sleep, closed terminal - just run the same command again and it continues
#  from where it stopped. Nothing is lost and nothing is re-downloaded.
#
#  NO ACCOUNT, KEY OR LOGIN IS NEEDED. The default catalogue is Element84
#  Earth Search, which is open. Nothing is written outside paper/real-results/.
#  Total download is a few hundred megabytes of metadata; no imagery is
#  downloaded at any point.
#
#  ---------------------------------------------------------------------------
#  WHAT IT PRODUCES, AND WHICH PART OF THE PAPER EACH ONE FEEDS
#  ---------------------------------------------------------------------------
#
#    R1  Clear-observation counts per equal-area cell, by latitude    Section 4
#    R2  Cloud-gap distributions and maximum gaps                     Section 4
#    R3  Measured cloud autocorrelation (rho)  <-- THE KEY RESULT     Section 4
#    R4  Landsat vs Sentinel-2 on identical cells                     Section 5
#    R5  Seasonal acquisition windows                                 Section 4
#    R6  Phenological feasibility from real acquisition dates         Section 4
#    R7  Constellation synergy, measured against nominal              Section 4
#
#  R3 is the one that matters most. The manuscript currently shows, by
#  simulation, that cloud clustering degrades phenological retrieval almost
#  independently of cloud amount. It cannot yet say what the real clustering
#  is. R3 measures it, which converts a sensitivity analysis into a finding.
# =============================================================================

options(warn = 1)
suppressPackageStartupMessages(library(cloudscape))

# --- command line ------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
getarg <- function(name, default) {
  i <- match(paste0("--", name), args)
  if (is.na(i) || i == length(args)) default else args[i + 1L]
}
MODE    <- getarg("mode", "pilot")
OUT     <- getarg("out", "cloudscape-results")
BACKEND <- getarg("backend", "element84")
if (!MODE %in% c("test", "pilot", "full")) {
  stop("--mode must be one of: test, pilot, full", call. = FALSE)
}

cfg <- switch(MODE,
  test  = list(n_sites = 3,   years = 2023:2023, label = "connection test"),
  pilot = list(n_sites = 24,  years = 2021:2024, label = "pilot"),
  # The whole point of "deep" is temporal depth rather than more sites: dating
  # when a location became observable enough for phenology requires the years
  # in which the constellation actually grew, not more places in one epoch.
  deep  = list(n_sites = 24,  years = 2013:2025, label = "deep, full mission record"),
  full  = list(n_sites = 120, years = 2016:2024, label = "full analysis"))
if (is.null(cfg)) stop("--mode must be test, pilot, deep or full", call. = FALSE)

# Each mission is only queried over its own operational period. Asking for
# Sentinel-2 in 2013 wastes a request and returns nothing; asking for Landsat 8
# in 2012 does the same.
SENSOR_START <- c("landsat-8-9-oli" = 2013L, "sentinel-2-msi" = 2015L)

dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(OUT, "raw"), recursive = TRUE, showWarnings = FALSE)

msg <- function(...) cat(sprintf(...), "\n", sep = "")
rule <- function() cat(strrep("-", 74), "\n")

rule()
msg("cloudscape real-data analysis  |  mode: %s (%s)", MODE, cfg$label)
msg("catalogue : %s", cl_catalog(BACKEND)$url)
msg("years     : %d-%d", min(cfg$years), max(cfg$years))
msg("sites     : %d", cfg$n_sites)
msg("output    : %s", normalizePath(OUT, mustWork = FALSE))
msg("windows   : %s per year (shorter windows = smaller, more reliable requests)",
    getarg("windows", "4"))
rule()

# =============================================================================
# STUDY DESIGN
#
# A stratified sample of terrestrial sites, not a global harvest. A global
# tier-A harvest is tens of millions of paged requests over days; a stratified
# sample of a few hundred cells answers every question the manuscript asks and
# runs in an afternoon.
#
# Sites are chosen to span latitude from the sub-Antarctic to the high Arctic
# and to cover the major climate regimes, because the manuscript's claims are
# about how availability and cloud persistence vary with those. Each site is a
# 0.5 degree box, which is comfortably inside a single Landsat scene and a
# handful of Sentinel-2 tiles.
# =============================================================================

SITES <- data.frame(rbind(
  # name,                     lon,      lat,    band,   regime
  c("Tierra del Fuego",     -68.30,  -54.80,  "-55", "subpolar oceanic"),
  c("Patagonia steppe",     -70.90,  -45.60,  "-45", "cold semi-arid"),
  c("Pampas",               -60.50,  -34.60,  "-35", "humid subtropical"),
  c("Atacama",              -69.30,  -23.60,  "-25", "hyper-arid"),
  c("Pantanal",             -56.60,  -17.80,  "-15", "tropical savanna"),
  c("Amazon central",       -60.00,   -3.10,   "-5", "tropical rainforest"),
  c("Congo basin",           23.60,    0.50,    "5", "tropical rainforest"),
  c("Sahel Niger",            2.10,   13.50,   "15", "hot semi-arid"),
  c("Sahara Libya",          17.60,   25.60,   "25", "hyper-arid"),
  c("Nile delta",            31.00,   30.80,   "30", "hot desert margin"),
  c("Anatolia",              33.10,   38.90,   "40", "cold semi-arid"),
  c("Po valley",              9.90,   45.20,   "45", "humid subtropical"),
  c("East Anglia",            0.90,   52.40,   "50", "temperate oceanic"),
  c("Baltic Poland",         19.40,   53.60,   "55", "humid continental"),
  c("Finland lakes",         27.10,   62.10,   "60", "subarctic"),
  c("Yakutia",              129.70,   66.90,   "65", "subarctic continental"),
  c("Alaska north slope",  -150.50,   70.10,   "70", "arctic tundra"),
  c("Svalbard",              15.60,   78.20,   "75", "high arctic"),
  c("Western Australia",    117.30,  -30.60,  "-30", "mediterranean"),
  c("NT Australia",         132.50,  -14.20,  "-15", "tropical savanna"),
  c("New Zealand South",    170.50,  -44.60,  "-45", "temperate oceanic"),
  c("Java",                 110.40,   -7.40,   "-5", "tropical monsoon"),
  c("Mekong delta",         105.90,   10.10,   "10", "tropical monsoon"),
  c("Deccan plateau",        77.60,   17.40,   "15", "tropical wet-dry"),
  c("Indo-Gangetic plain",   80.90,   26.80,   "25", "humid subtropical"),
  c("Tibetan plateau",       91.10,   30.60,   "30", "alpine"),
  c("North China plain",    116.40,   36.90,   "35", "humid continental"),
  c("Korea Andong",         128.70,   36.60,   "35", "humid continental"),
  c("Hokkaido",             142.40,   43.10,   "45", "humid continental"),
  c("Central Siberia",       92.80,   56.10,   "55", "subarctic"),
  c("Corn belt Iowa",       -93.60,   42.00,   "40", "humid continental"),
  c("Central Valley CA",   -120.60,   36.60,   "35", "mediterranean"),
  c("Great Plains Kansas",  -98.50,   38.50,   "40", "cold semi-arid"),
  c("Sonoran desert",      -112.10,   32.30,   "30", "hot desert"),
  c("Yucatan",              -89.10,   20.10,   "20", "tropical wet-dry"),
  c("Boreal Quebec",       -074.30,   52.80,   "50", "subarctic"),
  c("Ellesmere",            -85.50,   78.60,   "75", "high arctic"),
  c("Ethiopian highlands",   38.70,    9.10,   "10", "tropical highland"),
  c("Kalahari",              23.10,  -22.60,  "-25", "hot semi-arid"),
  c("Cape region",           19.30,  -33.60,  "-35", "mediterranean")
), stringsAsFactors = FALSE)
names(SITES) <- c("name", "lon", "lat", "band", "regime")
SITES$lon <- as.numeric(SITES$lon); SITES$lat <- as.numeric(SITES$lat)

# Expand towards the requested sample size by adding longitudinal replicates
# within the same latitude band, so that a site is never a single realisation
# of its climate regime.
if (cfg$n_sites > nrow(SITES)) {
  reps <- ceiling(cfg$n_sites / nrow(SITES))
  extra <- do.call(rbind, lapply(seq_len(reps - 1L), function(k) {
    s <- SITES
    s$lon <- ((s$lon + k * 37 + 180) %% 360) - 180   # 37 deg: coprime shift
    s$name <- paste0(s$name, " +", k)
    s
  }))
  SITES <- rbind(SITES, extra)
}
SITES <- SITES[seq_len(min(cfg$n_sites, nrow(SITES))), , drop = FALSE]
SITES$site_id <- sprintf("S%03d", seq_len(nrow(SITES)))

# Site extent is defined in GRID CELLS, not in degrees.
#
# A fixed-degree box covers less ground towards the poles, so degree-defined
# sites would contribute 6 cells at the equator and 2 at Svalbard. That is the
# very bias this package exists to remove, and letting it into the sampling
# design would confound latitude with sample size. Every site therefore owns
# exactly SIDE x SIDE equal-area cells: the same ground area everywhere.
SIDE <- 4L                       # 4 x 4 cells = 100 x 100 km at 25 km
SENSORS <- c("landsat-8-9-oli", "sentinel-2-msi")
GRID <- cl_grid(res = 25000)

# Cells owned by a site, and the lon/lat bounding box that covers them.
# In a cylindrical equal-area projection x depends only on longitude and y
# only on latitude, so the corner unprojection is exact.
site_cells <- function(lon, lat) {
  k <- cl_grid_lookup(GRID, lon, lat)
  if (is.na(k)) return(NULL)
  row <- ((k - 1L) %/% GRID$ncol) + 1L
  col <- ((k - 1L) %% GRID$ncol) + 1L
  off <- seq(-(SIDE %/% 2L), by = 1L, length.out = SIDE)
  rows <- row + off; cols <- col + off
  rows <- rows[rows >= 1L & rows <= GRID$nrow]
  cols <- cols[cols >= 1L & cols <= GRID$ncol]
  if (!length(rows) || !length(cols)) return(NULL)
  cells <- as.vector(outer((rows - 1L) * GRID$ncol, cols, "+"))
  x0 <- GRID$xmin + (min(cols) - 1L) * GRID$res
  x1 <- GRID$xmin + max(cols) * GRID$res
  y1 <- GRID$ymax - (min(rows) - 1L) * GRID$res
  y0 <- GRID$ymax - max(rows) * GRID$res
  ll <- cl_unproject(c(x0, x1), c(y0, y1))
  list(cells = as.integer(cells),
       aoi = c(ll[1, "lon"], ll[1, "lat"], ll[2, "lon"], ll[2, "lat"]))
}

SITES$n_cells <- vapply(seq_len(nrow(SITES)), function(i) {
  sc <- site_cells(SITES$lon[i], SITES$lat[i])
  if (is.null(sc)) 0L else length(sc$cells)
}, integer(1))
utils::write.csv(SITES, file.path(OUT, "sites.csv"), row.names = FALSE)
msg("Each site owns %d equal-area cells (%g x %g km), identical at every latitude.",
    SIDE * SIDE, SIDE * GRID$res / 1000, SIDE * GRID$res / 1000)

# =============================================================================
# HARVEST  (resumable)
# =============================================================================

# A signature of the sampling design. Cached parts harvested under a different
# design must not be silently reused: an earlier version defined sites as
# fixed-degree boxes and retained every cell the scene footprints touched,
# which produced hundreds of partially observed cells per site. Mixing those
# with correctly harvested parts would corrupt every statistic while leaving
# no visible trace.
DESIGN <- sprintf("grid%g_side%d_%s_v2overpass", GRID$res, SIDE, BACKEND)

state_file <- function(id) file.path(OUT, "raw", paste0(id, ".rds"))

# A year-long query over a 100 x 100 km box returns several hundred items and
# spans many pages. Public catalogues time out at the gateway on requests that
# size and report it as HTTP 502, so the year is split into shorter windows:
# each request is small, and a failure costs one window rather than a year.
# cl_search() additionally retries each page in place.
WINDOWS <- as.integer(getarg("windows", "4"))

PAUSE <- as.numeric(getarg("pause", "0.25"))   # polite spacing between requests

fetch_one <- function(site, sensor, year, aoi, tries = 2L) {
  edges <- seq(as.Date(sprintf("%d-01-01", year)),
               as.Date(sprintf("%d-12-31", year)) + 1, length.out = WINDOWS + 1L)
  out <- list(); n_fail <- 0L
  for (w in seq_len(WINDOWS)) {
    a <- edges[w]; b <- edges[w + 1L] - 1
    got <- NULL
    for (k in seq_len(tries)) {
      res <- tryCatch(
        suppressWarnings(
          cl_search(aoi = aoi, sensor = sensor, start = a, end = b,
                    max_cloud = 100, limit = Inf, backend = BACKEND,
                    retries = 5L)),
        error = function(e) e)
      if (!inherits(res, "error")) { got <- res; break }
      m <- conditionMessage(res)
      transient <- grepl("429|5[0-9][0-9]|timeout|Timeout|connect|resolve|SSL|HTTP",
                         m)
      if (!transient || k == tries) {
        msg("      ! %s %s..%s failed: %s", sensor, format(a, "%Y-%m"),
            format(b, "%m-%d"), substr(m, 1, 55))
        n_fail <- n_fail + 1L
        break
      }
      wait <- 3 * k + stats::runif(1, 0, 2)
      msg("      . %s %s: transient, retrying in %.0fs [%d/%d]", sensor,
          format(a, "%Y-%m"), wait, k, tries)
      Sys.sleep(wait)
    }
    # A window returning zero scenes is DATA, not a failure: polar sites in
    # winter genuinely have no acquisitions. Only a failed request counts.
    if (!is.null(got)) out[[length(out) + 1L]] <- got
    Sys.sleep(PAUSE)
  }
  # A year with any failed window is incomplete; recording it would understate
  # acquisitions for those cells and inflate their apparent cloud gaps. Return
  # a marker so the caller can retry it later rather than treating it as empty.
  if (n_fail > 0L) return(structure(list(), class = "cs_failed"))
  if (!length(out)) return(NULL)
  out <- Filter(function(x) nrow(x) > 0, out)
  if (!length(out)) return(NULL)
  geoms <- unlist(lapply(out, function(x) attr(x, "geometry")), recursive = FALSE)
  df <- do.call(rbind, lapply(out, as.data.frame))
  structure(df, class = c("cl_items", "data.frame"), geometry = geoms,
            assets = list(), manifest = attr(out[[1]], "manifest"))
}

todo <- expand.grid(site = SITES$site_id, sensor = SENSORS, year = cfg$years,
                    stringsAsFactors = FALSE)
todo <- todo[todo$year >= SENSOR_START[todo$sensor], , drop = FALSE]
todo$id <- sprintf("%s_%s_%d", todo$site, sub("-.*", "", todo$sensor), todo$year)
# Invalidate any cached part harvested under a different design
stale <- 0L
for (f in list.files(file.path(OUT, "raw"), pattern = "\\.rds$", full.names = TRUE)) {
  d <- tryCatch(readRDS(f)$design, error = function(e) NULL)
  if (is.null(d) || !identical(d, DESIGN)) { unlink(f); stale <- stale + 1L }
}
if (stale) {
  msg("Discarded %d cached part(s) from a previous sampling design.", stale)
  msg("They will be re-fetched. This is expected after an update.")
}

done <- file.exists(vapply(todo$id, state_file, character(1)))
msg("Harvest plan: %d site-sensor-years (%d already done, %d to fetch)",
    nrow(todo), sum(done), sum(!done))
todo <- todo[!done, , drop = FALSE]

# Smaller pages mean shorter, lighter requests. Public catalogues report
# gateway timeouts on heavy requests as HTTP 502, and a 500-item page over a
# 100 km box is heavy.
cl_options(max_page = 100L)

# ---------------------------------------------------------------------------
# Harvest one site-sensor-year. Returns a status string; never throws.
#
# Everything here is wrapped, because a single unanticipated error must not be
# able to halt a multi-hour run. An earlier version crashed on the 30th item
# of 163 and lost the remaining 133, which is precisely the failure mode this
# guards against.
# ---------------------------------------------------------------------------
harvest_item <- function(r) {
  tryCatch({
    site <- SITES[SITES$site_id == r$site, ]
    sc <- site_cells(site$lon, site$lat)
    if (is.null(sc)) return("failed")

    items <- fetch_one(site, r$sensor, r$year, sc$aoi)
    if (inherits(items, "cs_failed")) return("failed")

    rec <- NULL
    if (!is.null(items) && is.data.frame(items) && nrow(items) > 0L) {
      obs <- tryCatch(suppressWarnings(cl_items_to_obs(items, GRID)),
                      error = function(e) NULL)
      # Keep only cells this site OWNS. cl_items_to_obs() maps the whole scene
      # footprint onto the grid, and a Landsat scene is 185 km across, so
      # without this filter cells hundreds of kilometres away are retained.
      # Those are covered only by whichever scenes clipped the query box, so
      # they look sparsely observed because of the geometry rather than
      # because of cloud.
      if (!is.null(obs) && nrow(obs) > 0L) {
        obs <- obs[obs$cell %in% sc$cells, , drop = FALSE]
        if (!nrow(obs)) obs <- NULL
      } else obs <- NULL

      keep <- intersect(c("id", "datetime", "platform", "cloud_cover",
                          "sun_zenith", "path", "row", "tile"), names(items))
      rec <- list(design = DESIGN, site_id = r$site, sensor = r$sensor,
                  year = r$year, n_items = nrow(items), obs = obs,
                  scenes = as.data.frame(items)[, keep, drop = FALSE],
                  manifest = attr(items, "manifest"))
    }
    # A year with no acquisitions is a real, recordable result. Writing the
    # state file marks it complete so it is never re-fetched.
    saveRDS(rec, state_file(r$id), compress = "xz")
    if (is.null(rec)) "empty" else "ok"
  }, error = function(e) {
    msg("      ! %s: unexpected error, recorded as failed: %s",
        r$id, substr(conditionMessage(e), 1, 60))
    "failed"
  })
}

# ---------------------------------------------------------------------------
# Harvest in passes.
#
# A catalogue returning 502 under load usually recovers within minutes.
# Retrying immediately is the worst option: it adds load at exactly the moment
# the service is struggling. Later passes wait longer and normally clear the
# remainder without the operator relaunching anything.
# ---------------------------------------------------------------------------
MAX_PASS  <- as.integer(getarg("passes", "4"))
PASS_WAIT <- c(0, 60, 300, 900)

pending <- todo
failed  <- character()
n_ok <- 0L; n_empty <- 0L

for (pass in seq_len(MAX_PASS)) {
  if (!nrow(pending)) break
  if (pass > 1L) {
    w <- PASS_WAIT[min(pass, length(PASS_WAIT))]
    msg("")
    msg("Pass %d of %d: %d item(s) still to fetch. Waiting %d s for the catalogue",
        pass, MAX_PASS, nrow(pending), w)
    msg("to recover. Nothing already fetched is lost or re-downloaded.")
    Sys.sleep(w)
  }
  still <- character(); t0 <- Sys.time()
  for (i in seq_len(nrow(pending))) {
    st <- harvest_item(pending[i, ])
    if (st == "failed") still <- c(still, pending$id[i])
    else if (st == "empty") n_empty <- n_empty + 1L
    else n_ok <- n_ok + 1L
    if (i %% 10 == 0 || i == nrow(pending)) {
      el <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
      msg("  [pass %d] %d/%d  %.1f min elapsed, ~%.0f min left  (%d ok, %d empty, %d failed)",
          pass, i, nrow(pending), el, el / i * (nrow(pending) - i),
          n_ok, n_empty, length(still))
    }
  }
  pending <- pending[pending$id %in% still, , drop = FALSE]
  failed <- still
}

msg("")
if (length(failed)) {
  writeLines(failed, file.path(OUT, "failed-fetches.txt"))
  msg("%d of %d fetches did not succeed after %d passes.", length(failed),
      nrow(todo), MAX_PASS)
  msg("Ids are in failed-fetches.txt. Nothing else was lost: re-run the same")
  msg("command later and only these will be attempted.")
  if (length(failed) > 0.25 * max(1L, nrow(todo))) {
    msg("")
    msg("More than a quarter failed, which suggests the catalogue is degraded")
    msg("rather than busy. Options:")
    msg("  --windows 12          smaller requests")
    msg("  --backend planetary   Microsoft Planetary Computer instead")
    msg("  or simply wait an hour and re-run; progress is preserved.")
  }
} else if (nrow(todo)) {
  msg("All %d fetches succeeded (%d with data, %d with no acquisitions).",
      nrow(todo), n_ok, n_empty)
}

# =============================================================================
# ASSEMBLE
# =============================================================================

parts <- list.files(file.path(OUT, "raw"), pattern = "\\.rds$", full.names = TRUE)
recs <- Filter(function(x) !is.null(x) && identical(x$design, DESIGN),
               lapply(parts, readRDS))
if (!length(recs)) stop("No data harvested. Check the connection test first.", call. = FALSE)

OBS <- do.call(rbind, lapply(recs, function(r) {
  if (is.null(r$obs) || !nrow(r$obs)) return(NULL)
  d <- as.data.frame(r$obs); d$site_id <- r$site_id; d
}))
SCENES <- do.call(rbind, lapply(recs, function(r) {
  if (is.null(r$scenes) || !nrow(r$scenes)) return(NULL)
  d <- r$scenes; d$site_id <- r$site_id; d$sensor <- r$sensor; d
}))

obs <- cl_obs(OBS$cell, OBS$date, OBS$cloud_fraction, OBS$sensor,
              OBS$platform, tier = "metadata")

# Join site identity on CELL, never positionally.
#
# cl_obs() sorts its rows by cell and date, so assigning OBS$site_id to the
# returned object attached the identifiers in the original, unsorted order and
# silently scrambled them. The symptom was a cell at 80 degrees north labelled
# "subpolar oceanic", which is Tierra del Fuego's regime. Latitude was
# unaffected because it was already joined on cell, which is why the error
# survived review: only the regime column was wrong, and only a
# latitude-versus-regime cross-check exposes it.
cell_site <- do.call(rbind, lapply(seq_len(nrow(SITES)), function(i) {
  sc <- site_cells(SITES$lon[i], SITES$lat[i])
  if (is.null(sc)) return(NULL)
  data.frame(cell = sc$cells, site_id = SITES$site_id[i],
             regime = SITES$regime[i], stringsAsFactors = FALSE)
}))
dupes <- cell_site$cell[duplicated(cell_site$cell)]
if (length(dupes)) {
  cl_warn(length(unique(dupes)), " cell(s) are claimed by more than one site; ",
          "the first claim is used. Sites are too close together.")
  cell_site <- cell_site[!duplicated(cell_site$cell), , drop = FALSE]
}
k <- match(obs$cell, cell_site$cell)
obs$site_id <- cell_site$site_id[k]
obs$regime  <- cell_site$regime[k]

# Attach latitude to every cell so results can be reported against it
cells <- cl_grid_cells(GRID, cells = unique(obs$cell))
obs$lat <- cells$lat[match(obs$cell, cells$cell)]
obs$lon <- cells$lon[match(obs$cell, cells$cell)]

# Cross-check that would have caught the scrambling: a climate regime occupies
# a narrow band of ABSOLUTE latitude, even though it may occur in both
# hemispheres. Temperate oceanic spans -44.8 to +53.1 degrees legitimately, so
# the test must use |lat|.
if (any(is.na(obs$site_id))) {
  cl_warn(sum(is.na(obs$site_id)), " observations could not be matched to a ",
          "site. Regime-stratified results will be incomplete.")
}
chk <- do.call(rbind, lapply(split(obs, obs$regime), function(d)
  data.frame(regime = d$regime[1], abs_min = min(abs(d$lat)),
             abs_max = max(abs(d$lat)), span = diff(range(abs(d$lat))),
             stringsAsFactors = FALSE)))
bad <- chk[chk$span > 25, , drop = FALSE]
if (nrow(bad)) {
  cl_warn("Regime labels span implausible |latitude| ranges; the site join is ",
          "probably wrong:\n",
          paste(sprintf("  %s: %.1f to %.1f", bad$regime, bad$abs_min,
                        bad$abs_max), collapse = "\n"))
} else {
  msg("Regime/latitude consistency check passed (max |lat| span %.1f deg).",
      max(chk$span))
}

rule()
msg("Harvested %s acquisitions over %d cells at %d sites",
    format(nrow(obs), big.mark = ","), length(unique(obs$cell)),
    length(unique(obs$site_id)))
msg("Period %s to %s", min(obs$date), max(obs$date))
rule()

if (MODE == "test") {
  msg("Connection test passed. Now re-run the same command with --mode pilot")
  saveRDS(obs, file.path(OUT, "test-obs.rds"))
  quit(status = 0)
}

W <- function(x, name) {
  utils::write.csv(x, file.path(OUT, paste0(name, ".csv")), row.names = FALSE)
  msg("  wrote %s.csv  (%d rows)", name, nrow(x)); invisible(x)
}

# ---- R1: clear observations per equal-area cell -----------------------------
msg("R1  clear-observation counts")
r1 <- suppressMessages(cl_clear_obs(obs, by = "year", threshold = 0.2,
                                    model = "independent", grid = GRID))
r1w <- cl_stats_wide(r1)
r1w$lat <- cells$lat[match(r1w$cell, cells$cell)]
r1w$lat_band <- cut(r1w$lat, breaks = seq(-60, 90, by = 10))
W(r1w, "R1_clear_observations")

r1s <- do.call(rbind, lapply(split(r1w, list(r1w$lat_band, r1w$sensor), drop = TRUE),
  function(d) data.frame(
    lat_band = as.character(d$lat_band[1]), sensor = d$sensor[1],
    n_cell_years = nrow(d),
    mean_n_scenes = mean(d$n_scenes, na.rm = TRUE),
    mean_n_clear = mean(d$n_clear_obs, na.rm = TRUE),
    mean_cloud_fraction = mean(d$cloud_fraction, na.rm = TRUE),
    stringsAsFactors = FALSE)))
W(r1s, "R1_summary_by_latitude")

# ---- R2: gaps ---------------------------------------------------------------
msg("R2  cloud-gap distributions")
r2 <- cl_gaps(obs, threshold = 0.2, by = "year", critical = 30)
r2w <- cl_stats_wide(r2)
r2w$lat <- cells$lat[match(r2w$cell, cells$cell)]
r2w$regime <- obs$regime[match(r2w$cell, obs$cell)]
W(r2w, "R2_gaps")
W(attr(r2, "exceedance"), "R2_gap_exceedance")

# ---- R3: MEASURED CLOUD PERSISTENCE  (the key result) -----------------------
msg("R3  measured cloud autocorrelation  <-- key result")
r3 <- cl_persistence(obs, threshold = 0.2, max_interval = 20,
                     min_pairs = 10, by = "all")
if (nrow(r3)) {
  r3$lat <- cells$lat[match(r3$cell, cells$cell)]
  r3$regime <- obs$regime[match(r3$cell, obs$cell)]
  r3$lat_band <- cut(r3$lat, breaks = seq(-60, 90, by = 10))
  W(r3, "R3_persistence")

  r3s <- do.call(rbind, lapply(split(r3, r3$regime), function(d) data.frame(
    regime = d$regime[1], n_cells = nrow(d),
    mean_p_cloud = mean(d$p_cloud), mean_rho = mean(d$rho),
    sd_rho = stats::sd(d$rho),
    mean_cloudy_run = mean(d$mean_cloudy_run),
    median_interval = stats::median(d$median_interval_days),
    stringsAsFactors = FALSE)))
  W(r3s[order(-r3s$mean_rho), ], "R3_persistence_by_regime")

  msg("      overall rho = %.3f (sd %.3f) across %d cells",
      mean(r3$rho), stats::sd(r3$rho), nrow(r3))
  msg("      NOTE: this is a LOWER BOUND. See ?cl_persistence, Attenuation.")
} else {
  msg("      not enough transitions; increase --mode or the year range")
}

# ---- R4: Landsat vs Sentinel-2 on identical cells ---------------------------
msg("R4  cross-sensor comparison on identical cells")
common_years <- intersect(cfg$years, 2016:2100)
ov <- obs[obs$date >= as.Date(sprintf("%d-01-01", max(2016, min(common_years)))), ]
lw <- cl_stats_wide(suppressMessages(
  cl_clear_obs(ov, by = "year", threshold = 0.2, grid = GRID)))
r4 <- do.call(rbind, lapply(split(lw, list(lw$cell, lw$period), drop = TRUE),
  function(d) {
    if (length(unique(d$sensor)) < 2L) return(NULL)
    l <- d[grepl("landsat", d$sensor), ]; s <- d[grepl("sentinel", d$sensor), ]
    if (!nrow(l) || !nrow(s)) return(NULL)
    data.frame(cell = d$cell[1], period = d$period[1],
               landsat_cloud = l$cloud_fraction[1],
               sentinel_cloud = s$cloud_fraction[1],
               difference = s$cloud_fraction[1] - l$cloud_fraction[1],
               landsat_n = l$n_scenes[1], sentinel_n = s$n_scenes[1],
               stringsAsFactors = FALSE)
  }))
if (!is.null(r4) && nrow(r4)) {
  r4$lat <- cells$lat[match(r4$cell, cells$cell)]
  W(r4, "R4_cross_sensor")
  ct <- stats::cor.test(r4$landsat_cloud, r4$sentinel_cloud)
  tt <- stats::t.test(r4$difference)
  msg("      Sentinel-2 minus Landsat mean cloud: %+.3f (95%% CI %+.3f to %+.3f)",
      mean(r4$difference), tt$conf.int[1], tt$conf.int[2])
  msg("      correlation r = %.3f, n = %d cell-years", ct$estimate, nrow(r4))
  utils::write.csv(data.frame(
    mean_difference = mean(r4$difference), ci_low = tt$conf.int[1],
    ci_high = tt$conf.int[2], t = tt$statistic, p = tt$p.value,
    correlation = ct$estimate, n = nrow(r4)),
    file.path(OUT, "R4_cross_sensor_test.csv"), row.names = FALSE)
}

# ---- R5: seasonality --------------------------------------------------------
msg("R5  seasonal acquisition windows")
r5 <- cl_seasonality(obs, threshold = 0.2, harmonics = 2L,
                     window_days = 60, min_obs = 20)
if (!is.null(r5) && nrow(r5)) {
  r5$lat <- cells$lat[match(r5$cell, cells$cell)]
  r5$regime <- obs$regime[match(r5$cell, obs$cell)]
  W(r5, "R5_seasonality")
}

# ---- R6: phenological feasibility from REAL acquisition dates ---------------
msg("R6  phenological feasibility from real dates")
yr <- as.integer(names(sort(table(format(obs$date, "%Y")), decreasing = TRUE))[1])
r6 <- tryCatch(cl_pheno_map(obs, year = yr, n_sim = 200), error = function(e) NULL)
if (!is.null(r6)) {
  det <- attr(r6, "details")
  det$lat <- cells$lat[match(det$cell, cells$cell)]
  det$regime <- obs$regime[match(det$cell, obs$cell)]
  W(det, "R6_phenology_feasibility")
  msg("      year %d: median SOS error %.1f d, median failure rate %.2f",
      yr, stats::median(det$sos_mae, na.rm = TRUE),
      stats::median(det$failure_rate, na.rm = TRUE))
}

# ---- R7: measured vs nominal revisit ---------------------------------------
msg("R7  measured vs nominal acquisition density")
nominal <- cl_synergy(SENSORS, sprintf("%d-01-01", min(cfg$years)),
                      sprintf("%d-12-31", max(cfg$years)), by = "year")
measured <- do.call(rbind, lapply(split(r1w, r1w$period), function(d) data.frame(
  period = d$period[1],
  measured_obs_per_cell = mean(tapply(d$n_scenes, d$cell, sum), na.rm = TRUE),
  measured_clear_per_cell = mean(tapply(d$n_clear_obs, d$cell, sum), na.rm = TRUE),
  stringsAsFactors = FALSE)))
r7 <- merge(measured, nominal[nominal$sensor == "COMBINED",
                              c("period", "combined_obs", "effective_revisit_days")],
            by = "period", all.x = TRUE)
W(r7, "R7_measured_vs_nominal")

# =============================================================================
# DISCOVERY ANALYSES
#
# R1-R7 describe the archive. D1-D4 ask questions of it. These are the parts
# intended to carry the paper, and each is designed so that a null result is
# still informative.
# =============================================================================

# ---- D1: when did each place become observable enough for phenology? --------
#
# Phenological retrieval is not limited by cloud alone but by cloud relative to
# how often the sky is looked at, and the constellation grew from one satellite
# in 2013 to four by 2022. For every cell and year the actual acquisition dates
# are used to simulate retrieval, and the first year that crosses a usable
# standard is recorded. That year is a property of the place, and it is
# datable, mappable, and has not to our knowledge been reported.
msg("D1  feasibility crossover year  <-- discovery")
FEAS_ERR  <- as.numeric(getarg("feas_err", "5"))    # days of SOS error
FEAS_FAIL <- as.numeric(getarg("feas_fail", "0.1")) # fraction of fits failing
NSIM_D1   <- as.integer(getarg("nsim", "40"))

yrs <- sort(unique(as.integer(format(obs$date, "%Y"))))
d1_rows <- list()
for (y in yrs) {
  sub <- obs[format(obs$date, "%Y") == as.character(y), , drop = FALSE]
  if (nrow(sub) < 50) next
  r <- tryCatch(cl_pheno_map(sub, year = y, n_sim = NSIM_D1),
                error = function(e) NULL)
  if (is.null(r)) next
  det <- attr(r, "details")
  det$year <- y
  d1_rows[[length(d1_rows) + 1L]] <- det
  msg("      %d: %d cells, median SOS error %.1f d, median failure %.2f",
      y, nrow(det), stats::median(det$sos_mae, na.rm = TRUE),
      stats::median(det$failure_rate, na.rm = TRUE))
}
if (length(d1_rows)) {
  d1 <- do.call(rbind, d1_rows)
  d1$feasible <- !is.na(d1$sos_mae) & d1$sos_mae <= FEAS_ERR &
    d1$failure_rate <= FEAS_FAIL
  W(d1, "D1_feasibility_by_year")

  cross <- do.call(rbind, lapply(split(d1, d1$cell), function(d) {
    d <- d[order(d$year), , drop = FALSE]
    # The crossover is the first year from which the cell stays feasible, not
    # merely the first feasible year: a single good year followed by bad ones
    # is not a threshold being crossed.
    ok <- d$feasible
    sustained <- rev(cumprod(rev(as.integer(ok)))) > 0
    data.frame(cell = d$cell[1],
               first_year = if (any(ok)) d$year[which(ok)[1]] else NA_integer_,
               crossover_year = if (any(sustained)) d$year[which(sustained)[1]] else NA_integer_,
               n_years = nrow(d), n_feasible = sum(ok), stringsAsFactors = FALSE)
  }))
  W(cross, "D1_crossover_year")
  msg("      crossover: median %s, range %s",
      stats::median(cross$crossover_year, na.rm = TRUE),
      paste(range(cross$crossover_year, na.rm = TRUE), collapse = "-"))
}

# ---- D2: is the Sentinel-2 / Landsat offset constant? -----------------------
#
# A mean difference between two producers' cloud masks is only interesting if
# its structure is known. An additive offset can be corrected; one that grows
# with cloud amount or with latitude cannot be, and would distort any
# harmonised multi-sensor record differently in different places.
msg("D2  structure of the cross-sensor offset  <-- discovery")
if (!is.null(r4) && nrow(r4) > 30) {
  r4$mean_cloud <- (r4$landsat_cloud + r4$sentinel_cloud) / 2
  r4$abs_lat <- abs(r4$lat)
  r4$year <- as.integer(r4$period)
  fit <- stats::lm(difference ~ mean_cloud + abs_lat + year, data = r4)
  co <- summary(fit)$coefficients
  d2 <- data.frame(term = rownames(co), estimate = co[, 1], se = co[, 2],
                   t = co[, 3], p = co[, 4], stringsAsFactors = FALSE)
  d2$interpretation <- c(
    "offset at zero cloud, equator, year 0",
    "change in offset per unit cloud fraction",
    "change in offset per degree of |latitude|",
    "change in offset per year")[seq_len(nrow(d2))]
  W(d2, "D2_offset_structure")
  msg("      offset vs cloud amount: %+.3f per unit (p = %.3g)",
      co["mean_cloud", 1], co["mean_cloud", 4])
  msg("      offset vs |latitude|  : %+.5f per degree (p = %.3g)",
      co["abs_lat", 1], co["abs_lat", 4])
  msg("      R-squared %.3f -- a constant offset would give ~0",
      summary(fit)$r.squared)

  # Binned view, which is what the figure shows
  br <- seq(0, 1, by = 0.1)
  r4$bin <- cut(r4$mean_cloud, br, include.lowest = TRUE)
  d2b <- do.call(rbind, lapply(split(r4, r4$bin), function(d) {
    if (nrow(d) < 5) return(NULL)
    tt <- stats::t.test(d$difference)
    data.frame(bin = as.character(d$bin[1]),
               mid = mean(c(min(d$mean_cloud), max(d$mean_cloud))),
               n = nrow(d), mean_difference = mean(d$difference),
               lo = tt$conf.int[1], hi = tt$conf.int[2], stringsAsFactors = FALSE)
  }))
  W(d2b, "D2_offset_by_cloud_amount")
}

# ---- D3: does reported cloud drift, and is the drift real? ------------------
#
# Sen2Cor's scene classification changed across processing baselines, so a
# trend in Sentinel-2 reported cloud may be an artefact of reprocessing rather
# than weather. Landsat, processed by a different chain on the same cells and
# the same years, is the control: a step present in one and absent in the other
# is not atmospheric.
msg("D3  reported-cloud drift, with Landsat as control  <-- discovery")
obs$year <- as.integer(format(obs$date, "%Y"))
d3 <- do.call(rbind, lapply(split(obs, list(obs$sensor, obs$year), drop = TRUE),
  function(d) data.frame(sensor = d$sensor[1], year = d$year[1], n = nrow(d),
                         mean_cloud = mean(d$cloud_fraction, na.rm = TRUE),
                         se = stats::sd(d$cloud_fraction, na.rm = TRUE) /
                           sqrt(nrow(d)), stringsAsFactors = FALSE)))
W(d3[order(d3$sensor, d3$year), ], "D3_reported_cloud_by_year")
for (sn in unique(d3$sensor)) {
  dd <- d3[d3$sensor == sn & d3$n > 500, ]
  if (nrow(dd) < 4) next
  ft <- stats::lm(mean_cloud ~ year, dd)
  msg("      %s: %+.4f cloud fraction per year (p = %.3g, n = %d years)",
      sn, stats::coef(ft)[2], summary(ft)$coefficients[2, 4], nrow(dd))
}

# ---- D4: measured constellation growth --------------------------------------
msg("D4  measured acquisition density through time")
d4 <- do.call(rbind, lapply(split(r1w, list(r1w$sensor, r1w$period), drop = TRUE),
  function(d) data.frame(sensor = d$sensor[1], year = as.integer(d$period[1]),
                         n_cells = length(unique(d$cell)),
                         acquisitions = mean(d$n_scenes),
                         clear = mean(d$n_clear_obs),
                         cloud_fraction = mean(d$cloud_fraction),
                         stringsAsFactors = FALSE)))
W(d4[order(d4$sensor, d4$year), ], "D4_constellation_growth")

# ---- scene-level record, for comparison with the previous study -------------
W(SCENES, "S1_scene_records")

# =============================================================================
# PACKAGE THE RESULTS
# =============================================================================

sess <- utils::capture.output(utils::sessionInfo())
writeLines(c(
  sprintf("cloudscape real-data analysis"),
  sprintf("mode          : %s", MODE),
  sprintf("run at        : %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")),
  sprintf("backend       : %s", cl_catalog(BACKEND)$url),
  sprintf("years         : %d-%d", min(cfg$years), max(cfg$years)),
  sprintf("sites         : %d", nrow(SITES)),
  sprintf("grid          : EPSG:%s at %g m", GRID$crs, GRID$res),
  sprintf("acquisitions  : %d", nrow(obs)),
  sprintf("cells         : %d", length(unique(obs$cell))),
  "", "sessionInfo():", sess),
  file.path(OUT, "RUN_MANIFEST.txt"))

zipfile <- file.path(OUT, sprintf("cloudscape-results-%s.zip",
                                  format(Sys.Date(), "%Y%m%d")))
csvs <- list.files(OUT, pattern = "\\.(csv|txt)$", full.names = TRUE)
utils::zip(zipfile, csvs, flags = "-qj")

rule()
msg("DONE.")
msg("")
msg("Send me this one file:")
msg("   %s", normalizePath(zipfile, mustWork = FALSE))
msg("")
msg("It contains only CSV summaries and a run manifest - no imagery, no")
msg("personal data, a few megabytes at most. I will use it to replace the")
msg("simulation-based results in Section 4 with measured ones.")
rule()
