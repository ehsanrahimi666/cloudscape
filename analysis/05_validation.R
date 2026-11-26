# Software verification: every entry is computed here against an analytical
# identity, a known simulated truth, the automated tests or a static check of
# the source tree.
source("analysis/config.R")
suppressPackageStartupMessages({library(cloudscape); library(testthat)})
set.seed(cfg$seed)
# Agreement with a target, with enough digits to show a non-zero difference.
within <- function(x) {
  sprintf(if (x > 0 && x < 5e-4) "within %.1e of target" else "within %.3f of target", x)
}
# Each check is labelled by the kind of evidence it gives (an analytical
# identity, recovery of a known simulated value, an automated test or a static
# check of the source) and by whether it concerns the availability workflow or
# the experimental pixel-level detection.
row <- function(component, type, reference, result, scope = "availability") data.frame(
  component = component, type = type, scope = scope, verified_against = reference,
  result = result, stringsAsFactors = FALSE)

# Equal-area projection.
lon <- c(-179, -120, -60, 0, 45, 120, 179); lat <- c(-85, -60, -30, 0, 30, 60, 82)
p <- cl_project(lon, lat); b <- cl_unproject(p[, "x"], p[, "y"])
xr <- diff(range(cl_project(c(-180, 180), c(0, 0))[, "x"]))
yr <- diff(range(cl_project(c(0, 0), c(-90, 90))[, "y"]))
area_err <- abs(xr * yr - 5.100656217e14) / 5.100656217e14
rt_err <- max(abs(b[, "lon"] - lon), abs(b[, "lat"] - lat))

# Shadow displacement and height recovery.
zen <- c(0, 15, 30, 45, 60, 75)
disp_err <- max(abs(1000 * tan(zen * pi / 180) - vapply(zen, function(z)
  sqrt(sum(cl_shadow_offset(1000, z, 180)^2)), numeric(1))))
rec <- expand.grid(true_height = c(600, 1200, 2400, 4800), sun_zenith = c(25, 45, 65),
                   sun_azimuth = c(45, 145, 250))
run_case <- function(h, z, az, npx, seed) {
  sm <- cl_simulate(npx, npx, coverage = 0.15, opacity = 1, height = h, res = 30,
                    sun_zenith = z, sun_azimuth = az, seed = seed)
  r <- suppressWarnings(cl_shadow_project(sm$cloud, sm$shadow, res = 30, sun_zenith = z,
                                          sun_azimuth = az, heights = seq(200, 6000, by = 50)))
  r$height
}
rec$displacement_m <- rec$true_height * tan(rec$sun_zenith * pi / 180)
rec$sized_window_px <- vapply(rec$displacement_m / 30, function(d)
  max(96L, min(512L, as.integer(ceiling(3 * d)))), integer(1))
rec$sized_recovered_m <- vapply(seq_len(nrow(rec)), function(i) run_case(
  rec$true_height[i], rec$sun_zenith[i], rec$sun_azimuth[i], rec$sized_window_px[i], 100 + i), numeric(1))
rec$fixed_recovered_m <- vapply(seq_len(nrow(rec)), function(i) run_case(
  rec$true_height[i], rec$sun_zenith[i], rec$sun_azimuth[i], 96L, 100 + i), numeric(1))
rec$sized_success <- abs(rec$sized_recovered_m - rec$true_height) <= 50
rec$fixed_success <- abs(rec$fixed_recovered_m - rec$true_height) <= 50
rec$within_limit <- rec$displacement_m <= 0.5 * 96 * 30
save_csv(rec, "validation_height_recovery")
lim <- expand.grid(window_km = c(3, 10, 30, 100), sun_zenith = c(25, 40, 55, 70))
lim$max_resolvable_height_m <- round(0.5 * lim$window_km * 1000 / tan(lim$sun_zenith * pi / 180))
save_csv(lim, "identifiability_limit")

# Terrain shadow, thermal height, simulator, Markov chain, metrics.
dem <- matrix(0, 40, 40); dem[, 30:40] <- 600
east <- cl_terrain_shadow(dem, 75, 90, res = 30)
west <- cl_terrain_shadow(dem, 75, 270, res = 30)
bt <- matrix(300, 50, 50); cl <- matrix(FALSE, 50, 50); cl[20:30, 20:30] <- TRUE; bt[cl] <- 280
th_err <- abs(cl_cloud_height(bt, cl)$height - 20 / 0.0065)
cov_err <- max(vapply(c(0.1, 0.3, 0.6), function(cv) max(vapply(1:20, function(s)
  abs(mean(cl_simulate(128, 128, coverage = cv, opacity = 1, seed = s)$cloud) - cv), numeric(1))), numeric(1)))
d5 <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
mk <- expand.grid(p = c(0.3, 0.6, 0.85), rho = c(0, 0.35, 0.7))
mk$err <- vapply(seq_len(nrow(mk)), function(i) abs(mean(vapply(1:200, function(s)
  mean(cl_simulate_series(d5, mk$p[i], mk$rho[i], seed = s)$cloudy), numeric(1))) - mk$p[i]), numeric(1))
d10 <- seq(as.Date("2015-01-01"), as.Date("2024-12-31"), by = "5 days")
rho_err <- max(vapply(c(0.3, 0.6), function(r) abs(mean(vapply(1:50, function(s) {
  ts <- cl_simulate_series(d10, 0.5, r, seed = s)
  cl_persistence(cl_obs(1, ts$date, as.numeric(ts$cloudy), sensor = "sentinel-2-msi"),
                 threshold = 0.5, max_interval = 20)$rho
}, numeric(1))) - r), numeric(1)))
truth <- c(rep(1, 70), rep(0, 30)); pred <- c(rep(1, 60), rep(0, 10), rep(1, 5), rep(0, 25))
v <- cl_validate(pred, truth); i1 <- which(v$class == "1")
metric_err <- max(abs(c(v$precision[i1] - 60 / 65, v$recall[i1] - 60 / 70, v$iou[i1] - 60 / 75,
                        attr(v, "overall")[["overall_accuracy"]] - 85 / 100)))
bd <- paste(deparse(body(validate_cl_stats), width.cutoff = 500L), collapse = " ")
den <- eval(parse(text = sub("^ok_denom <- ", "", regmatches(bd, regexpr("ok_denom <- c\\([^)]*\\)", bd)))))
mets <- get(".CS_METRICS", envir = asNamespace("cloudscape"))

# Static checks of the source tree.
source("tools/architecture.R", local = TRUE)
layers <- cs_check_layers("R")
docs <- cs_check_docs("R")

# Test suite, run against the installed package.
tr <- as.data.frame(test_dir("tests/testthat", package = "cloudscape", load_package = "installed",
                             reporter = "silent", stop_on_failure = FALSE))
save_csv(tr[, c("file", "test", "nb", "failed", "skipped", "error", "passed")], "test_suite")
n_files <- length(list.files("tests/testthat", pattern = "^test-.*\\.R$"))

# Gap statistics: with the record closed by virtual observations on the days
# before and after the year, the gaps of a cell-year sum to its length plus one.
gy <- utils::read.csv(file.path(out_dir, "gaps_cell_year.csv"))
gy <- gy[gy$include_edges, ]
ylen <- as.numeric(as.Date(sprintf("%s-12-31", gy$period)) - as.Date(sprintf("%s-01-01", gy$period))) + 2
gap_err <- max(abs(gy$mean_gap_days * (gy$n_clear_dates + 1) - ylen))

# Decorrelation time: recovery of known values under the study acquisition
# schedules (analysis/03b_persistence_simulation.R).
ps <- utils::read.csv(file.path(out_dir, "persistence_simulation.csv"))
ps <- ps[ps$error == "none" & ps$estimator == "tau_deseasonalised_days" & ps$tau_true >= 1, ]

tab <- rbind(
  row("Equal-area projection", "Analytical identity", "WGS84 ellipsoid surface area",
      sprintf("%.1e relative error", area_err)),
  row("Projection round trip", "Analytical identity", "Inverse transformation",
      sprintf("%.1e degrees maximum", rt_err)),
  row("Gap statistics", "Analytical identity", "Gaps of a year sum to its length plus one day",
      sprintf("%.1e days maximum, %d cell-years", gap_err, nrow(gy))),
  row("Accuracy metrics", "Analytical identity", "Hand-computed confusion matrix",
      sprintf("%.1e maximum difference", metric_err)),
  row("Two-state Markov chain", "Synthetic recovery", "Stationary probability (200 series, nine settings)",
      within(max(mk$err))),
  row("Lag-one autocorrelation", "Synthetic recovery", "Known simulated rho (50 series, two values)",
      within(rho_err)),
  row("Deseasonalised decorrelation time", "Synthetic recovery",
      "Known simulated tau of 1-8 days, study acquisition schedules (200 series each)",
      sprintf("median relative error %.0f%% to %.0f%%", 100 * min(ps$rel_bias), 100 * max(ps$rel_bias))),
  row("Test suite", "Automated tests", "testthat, installed package",
      sprintf("%d expectations in %d files: %d failed, %d skipped",
              sum(tr$nb), n_files, sum(tr$failed), sum(tr$skipped))),
  row("Unit validation", "Source check", "Controlled vocabulary",
      sprintf("%d metrics, %d denominators", nrow(mets), length(den))),
  row("Layer contract", "Source check", "Static call graph", sprintf("%d violations", nrow(layers))),
  row("Documentation", "Source check", "Documentation block of every exported function",
      sprintf("%d gaps", if (is.data.frame(docs)) nrow(docs) else length(docs))),
  row("Shadow displacement", "Analytical identity", "h tan(zenith) identity",
      sprintf("%.1e m maximum, six zenith angles", disp_err), "detection"),
  row("Thermal height estimate", "Analytical identity", "Lapse-rate identity",
      sprintf("%.1e m error", th_err), "detection"),
  row("Terrain shadow", "Analytical identity", "Reversal of sun direction",
      sprintf("%d shadowed pixels when reversed (%d before)", sum(west), sum(east)), "detection"),
  row("Simulator coverage", "Synthetic recovery", "Requested coverage (20 seeds, three levels)",
      within(cov_err), "detection"),
  row("Cloud-top height, window sized to geometry", "Synthetic recovery",
      "Known simulated height (error at most 50 m)",
      sprintf("%d of %d configurations", sum(rec$sized_success), nrow(rec)), "detection"),
  row("Cloud-top height, fixed 2.9 km window", "Synthetic recovery",
      "Known simulated height (error at most 50 m)",
      sprintf("%d of %d configurations (%d of %d within the identifiability limit, %d of %d beyond it)",
              sum(rec$fixed_success), nrow(rec), sum(rec$fixed_success & rec$within_limit),
              sum(rec$within_limit), sum(rec$fixed_success & !rec$within_limit), sum(!rec$within_limit)),
      "detection"))
save_csv(tab, "validation_summary")

# Detection consistency test: synthetic scenes at Andong's mid-June geometry.
solar <- cl_solar_position(as.POSIXct("2024-06-15 02:30:00", tz = "UTC"), cfg$site[["lon"]], cfg$site[["lat"]])
bg <- list(blue = matrix(0.06, 160, 160), green = matrix(0.08, 160, 160), red = matrix(0.05, 160, 160),
           nir = matrix(0.32, 160, 160), swir16 = matrix(0.20, 160, 160), swir22 = matrix(0.12, 160, 160))
det <- do.call(rbind, lapply(1:20, function(seed) {
  sim <- cl_simulate(background = bg, coverage = 0.30, opacity = c(0.3, 1), height = 2500, res = 30,
                     sun_zenith = solar$zenith, sun_azimuth = solar$azimuth, seed = seed)
  sh <- cl_shadow(sim$cloud, nir = sim$bands$nir, swir = sim$bands$swir16, res = 30,
                  sun_zenith = solar$zenith, sun_azimuth = solar$azimuth, heights = seq(500, 6000, by = 100))
  vs <- cl_validate(sh$shadow, sim$shadow)
  do.call(rbind, lapply(c("threshold", "fmask"), function(m) {
    pr <- cl_probability(sim$bands, m, sensor = "sentinel-2-msi")
    vv <- cl_validate(pr$class, sim$cloud); k <- which(vv$class == "1")
    data.frame(seed = seed, method = m, iou = vv$iou[k], recall = vv$recall[k],
               precision = vv$precision[k], accuracy = attr(vv, "overall")[["overall_accuracy"]],
               ece = attr(cl_calibration(pr$probability, sim$cloud), "ece"),
               height_m = sh$params$height, shadow_iou = vs$iou[vs$class == "1"])
  }))
}))
save_csv(det, "detection_synthetic")
save_csv(data.frame(zenith = solar$zenith, azimuth = solar$azimuth), "detection_geometry")
print(tab, right = FALSE)
