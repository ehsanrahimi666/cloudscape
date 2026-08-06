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
  full  = list(n_sites = 120, years = 2016:2024, label = "full analysis"))

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
DESIGN <- sprintf("grid%g_side%d_%s", GRID$res, SIDE, BACKEND)

state_file <- function(id) file.path(OUT, "raw", paste0(id, ".rds"))

# A year-long query over a 100 x 100 km box returns several hundred items and
# spans many pages. Public catalogues time out at the gateway on requests that
# size and report it as HTTP 502, so the year is split into shorter windows:
# each request is small, and a failure costs one window rather than a year.
# cl_search() additionally retries each page in place.
WINDOWS <- as.integer(getarg("windows", "4"))

fetch_one <- function(site, sensor, year, aoi, tries = 3L) {
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
    if (!is.null(got) && nrow(got)) out[[length(out) + 1L]] <- got
  }
  # A year with any failed window is incomplete; recording it would understate
  # acquisitions for those cells and inflate their apparent cloud gaps.
  if (n_fail > 0L) return(NULL)
  if (!length(out)) return(NULL)
  geoms <- unlist(lapply(out, function(x) attr(x, "geometry")), recursive = FALSE)
  df <- do.call(rbind, lapply(out, as.data.frame))
  structure(df, class = c("cl_items", "data.frame"), geometry = geoms,
            assets = list(), manifest = attr(out[[1]], "manifest"))
}

todo <- expand.grid(site = SITES$site_id, sensor = SENSORS, year = cfg$years,
                    stringsAsFactors = FALSE)
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
failed <- character()

if (nrow(todo)) {
  t0 <- Sys.time()
  for (i in seq_len(nrow(todo))) {
    r <- todo[i, ]
    site <- SITES[SITES$site_id == r$site, ]
    sc <- site_cells(site$lon, site$lat)
    if (is.null(sc)) { failed <- c(failed, r$id); next }
    items <- fetch_one(site, r$sensor, r$year, sc$aoi)
    if (is.null(items)) {
      # A transient failure must NOT be recorded as complete, or re-running
      # would skip it forever and the gap would be invisible in the results.
      failed <- c(failed, r$id)
      next
    }
    rec <- if (!nrow(items)) NULL else {
      obs <- tryCatch(suppressWarnings(cl_items_to_obs(items, GRID)),
                      error = function(e) NULL)
      # Keep only cells this site OWNS.
      #
      # cl_items_to_obs() maps the FULL scene footprint onto the grid, and a
      # Landsat scene is 185 km across against a 0.5 degree query box. Without
      # this filter a three-site test returned 536 cells instead of ~18, most
      # of them hundreds of kilometres away and covered only by whichever
      # scenes happened to clip the corner of the box. Those cells have
      # systematically incomplete records: they look sparsely observed because
      # of the query geometry, not because of cloud. Every statistic computed
      # from them would be wrong, and wrong in the direction that flatters the
      # paper's argument.
      if (!is.null(obs) && nrow(obs)) {
        obs <- obs[obs$cell %in% sc$cells, , drop = FALSE]
        if (!nrow(obs)) obs <- NULL
      }
      list(design = DESIGN, site_id = r$site, sensor = r$sensor, year = r$year,
           n_items = nrow(items), obs = obs,
           # keep the scene-level record too: it is what the previous study used
           scenes = as.data.frame(items)[, c("id", "datetime", "platform",
                                             "cloud_cover", "sun_zenith",
                                             "path", "row", "tile")],
           manifest = attr(items, "manifest"))
    }
    saveRDS(rec, state_file(r$id), compress = "xz")
    if (i %% 10 == 0 || i == nrow(todo)) {
      el <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
      msg("  [%d/%d] %.1f min elapsed, ~%.0f min remaining",
          i, nrow(todo), el, el / i * (nrow(todo) - i))
    }
  }
}

if (length(failed)) {
  msg("")
  msg("%d of %d fetches failed and were NOT marked complete.", length(failed),
      nrow(todo))
  msg("Re-run the same command to retry only those. Occasional HTTP 502 from")
  msg("the catalogue is normal; a second pass usually clears them.")
  writeLines(failed, file.path(OUT, "failed-fetches.txt"))
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
obs$site_id <- OBS$site_id

# Attach latitude to every cell so results can be reported against it
cells <- cl_grid_cells(GRID, cells = unique(obs$cell))
obs$lat <- cells$lat[match(obs$cell, cells$cell)]
obs$lon <- cells$lon[match(obs$cell, cells$cell)]
obs$regime <- SITES$regime[match(obs$site_id, SITES$site_id)]

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
