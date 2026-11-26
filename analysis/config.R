# Specification of the Andong analysis. Every script reads these values and
# is run from the repository root, e.g. Rscript analysis/run_all.R.

cfg <- list(
  site = c(lon = 128.73, lat = 36.57),
  grid_res = 25000,
  block = -2:1,
  start = "2019-01-01",
  end = "2024-12-31",
  years = 2019:2024,
  sensors = c("sentinel-2-msi", "landsat-8-9-oli"),
  overpass_minutes = 20,
  threshold = 0.2,
  qa_confidence = "medium",
  qa_include_cirrus = TRUE,
  qa_workers = 12L,
  # A cell-observation is usable when at least 1 - threshold of the cell was
  # observed and cloud-free (coverage = TRUE). The alternative definitions
  # below are sensitivity analyses: the cloud fraction of the valid pixels at
  # most `threshold`, with no coverage condition or with a minimum valid
  # share.
  coverage = TRUE,
  sens_min_valid = c(0, 0.5, 0.75, 0.9),
  gap_critical = 21,
  harmonics = 2L,
  window_days = 60,
  winter_months = c(12, 1, 2),
  summer_months = c(6, 7, 8),
  max_interval = 20,
  sens_max_interval = c(10, 20, 30, 40),
  pheno_year = 2024,
  n_sim = 200L,
  seed = 20241,
  noise = 0.03,
  # Decorrelation time of cloud loss in the phenology simulation, in days: the
  # median deseasonalised decorrelation time of the study cells (quality-layer
  # tier), rounded up to whole days, is used as the primary value.
  tau_rule = "ceiling of the median deseasonalised decorrelation time",
  retention = "pixel",
  tolerance = 5,
  curve = list(base = 0.15, amplitude = 0.6, sos = 120, eos = 280,
               slope_up = 0.12, slope_down = 0.10),
  sens_sos = c(90, 120, 150),
  sens_noise = c(0.01, 0.03, 0.05),
  sens_tau = c(0, 4, 16),
  sens_amplitude = c(0.3, 0.6, 0.75),
  sens_slope_factor = c(0.5, 1, 2),
  thin_fraction = c(0.05, 0.1, 0.15, 0.2, 0.3, 0.5, 0.75, 1),
  gap_window = 30,
  gap_centres = seq(30, 330, by = 10),
  gap_reps = 100L,
  tau_true = c(0.5, 1, 2, 4, 8),
  tau_reps = 200L,
  # Grid resolutions for the scale analysis of the phenology year; each nests
  # in the 25 km grid because the global origin is a corner of every grid.
  fine_res = c(6250, 12500, 25000),
  boot = 2000L
)

data_dir <- file.path("analysis", "data")
out_dir <- file.path("analysis", "output")
fig_dir <- file.path("analysis", "figures")
for (d in c(data_dir, out_dir, fig_dir)) dir.create(d, showWarnings = FALSE, recursive = TRUE)

# The study area is a 4 x 4 block of 25 km equal-area cells around the site.
study_area <- function(cfg) {
  grid <- cloudscape::cl_grid(res = cfg$grid_res)
  k <- cloudscape::cl_grid_lookup(grid, cfg$site[["lon"]], cfg$site[["lat"]])
  row <- ((k - 1L) %/% grid$ncol) + 1L
  col <- ((k - 1L) %% grid$ncol) + 1L
  cells <- as.vector(outer((row + cfg$block - 1L) * grid$ncol, col + cfg$block, "+"))
  x0 <- grid$xmin + (min(col + cfg$block) - 1L) * grid$res
  x1 <- grid$xmin + max(col + cfg$block) * grid$res
  y1 <- grid$ymax - (min(row + cfg$block) - 1L) * grid$res
  y0 <- grid$ymax - max(row + cfg$block) * grid$res
  ll <- cloudscape::cl_unproject(c(x0, x1), c(y0, y1))
  list(grid = grid, cells = sort(cells),
       aoi = c(ll[1, "lon"], ll[1, "lat"], ll[2, "lon"], ll[2, "lat"]),
       bounds = c(x0, y0, x1, y1))
}

# Row subset of a cl_items table that keeps footprints and assets aligned.
subset_items <- function(items, i) {
  structure(as.data.frame(items)[i, , drop = FALSE], class = class(items),
            geometry = attr(items, "geometry")[i], assets = attr(items, "assets")[i],
            manifest = attr(items, "manifest"))
}

# Row-binds cl_items tables, keeping footprints and assets aligned.
bind_items <- function(x) {
  x <- Filter(function(i) nrow(i) > 0L, x)
  out <- structure(do.call(rbind, lapply(x, as.data.frame)), class = class(x[[1]]),
                   geometry = do.call(c, lapply(x, attr, "geometry")),
                   assets = do.call(c, lapply(x, attr, "assets")),
                   manifest = attr(x[[1]], "manifest"))
  subset_items(out, !duplicated(out$id))
}

# Row-binds observation tables of one tier, keeping the class and tier.
bind_obs <- function(x) {
  tier <- unique(vapply(x, function(o) attr(o, "tier"), character(1)))
  stopifnot(length(tier) == 1L)
  out <- do.call(rbind, lapply(x, as.data.frame))
  rownames(out) <- NULL
  structure(out, class = class(x[[1]]), tier = tier)
}

# Row subset of an observation table that keeps its class and tier.
obs_subset <- function(o, i) {
  structure(as.data.frame(o)[i, , drop = FALSE], class = class(o), tier = attr(o, "tier"))
}

# Cluster bootstrap over overpasses: resamples whole overpasses, because the
# cells seen in one overpass share its atmosphere. It does not represent
# dependence between successive overpasses.
cluster_ci <- function(d, cluster, stat, B = cfg$boot, seed = cfg$seed) {
  set.seed(seed)
  ids <- unique(cluster)
  idx <- split(seq_len(nrow(d)), match(cluster, ids))
  est <- stat(d)
  bt <- replicate(B, stat(d[unlist(idx[sample(length(idx), replace = TRUE)]), , drop = FALSE]))
  c(estimate = est, lower = unname(stats::quantile(bt, 0.025, na.rm = TRUE)),
    upper = unname(stats::quantile(bt, 0.975, na.rm = TRUE)))
}

# Block bootstrap over calendar months: all overpasses of one month of one
# year form a block, and blocks are resampled with replacement within each
# calendar month. Dependence between overpasses within a month is retained and
# the seasonal composition of the sample is fixed. `d` needs columns `year`
# and `month`.
block_ci <- function(d, stat, B = cfg$boot, seed = cfg$seed) {
  set.seed(seed)
  blk <- paste(d$year, d$month)
  idx <- split(seq_len(nrow(d)), blk)
  by_month <- split(names(idx), vapply(strsplit(names(idx), " "), `[`, "", 2L))
  est <- stat(d)
  bt <- replicate(B, {
    pick <- unlist(lapply(by_month, function(b) sample(b, length(b), replace = TRUE)),
                   use.names = FALSE)
    stat(d[unlist(idx[pick], use.names = FALSE), , drop = FALSE])
  })
  c(estimate = est, lower = unname(stats::quantile(bt, 0.025, na.rm = TRUE)),
    upper = unname(stats::quantile(bt, 0.975, na.rm = TRUE)))
}

save_csv <- function(x, name) {
  utils::write.csv(x, file.path(out_dir, paste0(name, ".csv")), row.names = FALSE)
  invisible(x)
}

# Rounding half away from zero at the given number of decimals, after the value
# is fixed at nine decimals to remove floating-point noise. Every number printed
# in a table, figure or the text of the article is rounded by this rule.
round_half_up <- function(x, digits = 0) {
  z <- round(x * 1e9)
  q <- 10^(9 - digits)
  sign(z) * floor((abs(z) + q / 2) / q) / 10^digits
}
