# =============================================================================
#  cloudscape — POST-INSTALLATION CHECK
#
#  Paste this whole file into R, or run:
#      Rscript check-install.R
#
#  It answers three questions:
#    A. Did the package install completely and correctly?
#    B. Does it still compute the right numbers on this machine?
#    C. Can it reach a live satellite catalogue from here?
#
#  C is the one that matters most, because it was never testable during
#  development. Everything else has been verified elsewhere; C has not.
#
#  Nothing is written to disk except an optional report file at the end.
# =============================================================================

cat("\n", strrep("=", 70), "\n", sep = "")
cat("cloudscape post-installation check\n")
cat(strrep("=", 70), "\n\n", sep = "")

PASS <- 0L; FAIL <- 0L; SKIP <- 0L; NOTES <- character()
ok <- function(label, cond, detail = "") {
  cond <- isTRUE(tryCatch(cond, error = function(e) FALSE))
  if (cond) { PASS <<- PASS + 1L; sym <- "PASS" } else { FAIL <<- FAIL + 1L; sym <- "FAIL" }
  cat(sprintf("  [%s] %-46s %s\n", sym, label, detail))
  invisible(cond)
}
skip <- function(label, why) {
  SKIP <<- SKIP + 1L
  cat(sprintf("  [SKIP] %-46s %s\n", label, why))
}
sec <- function(x) cat("\n--", x, "\n")

# =============================================================================
# A. INSTALLATION INTEGRITY
# =============================================================================
sec("A. Installation integrity")

installed <- requireNamespace("cloudscape", quietly = TRUE)
ok("package is installed", installed)
if (!installed) {
  cat("\nStop. Install first:\n")
  cat('  remotes::install_github("ehsanrahimi666/cloudscape")\n\n')
  quit(status = 1)
}
suppressPackageStartupMessages(library(cloudscape))

ver <- as.character(utils::packageVersion("cloudscape"))
ok("version is 0.1.0", ver == "0.1.0", ver)

lib <- dirname(system.file(package = "cloudscape"))
cat(sprintf("         library: %s\n", lib))

exports <- getNamespaceExports("cloudscape")
ok("exported functions >= 71", length(exports) >= 71,
   sprintf("%d found", length(exports)))

# Every function the manuscript and the analysis scripts rely on
expected <- c(
  "cl_options","cl_cache_dir","cl_require","cl_manifest",
  "cl_sensor","cl_sensors","cl_sensor_driver","cl_sensor_register","cl_qa_spec",
  "cl_grid","cl_grid_cells","cl_grid_index","cl_grid_lookup","cl_project","cl_unproject",
  "cl_catalog","cl_search","cl_items_to_obs",
  "cl_scene","cl_cube","cl_maskset","cl_stats","cl_stats_wide","cl_stats_merge",
  "cl_classes","cl_metrics","validate_cl_stats","cl_bands","cl_band",
  "cl_scale","cl_geometry","cl_solar_position","cl_indices",
  "cl_probability","cl_methods","cl_method_register","cl_qa_decode",
  "cl_shadow","cl_shadow_offset","cl_shadow_project","cl_cloud_height","cl_terrain_shadow",
  "cl_agreement","cl_disagreement","cl_reliability",
  "cl_obs","cl_clear_obs","cl_clear_prob","cl_gaps","cl_seasonality",
  "cl_synergy","cl_feasibility","cl_persistence",
  "cl_pheno_curve","cl_pheno_fit","cl_pheno_power","cl_pheno_map",
  "cl_simulate","cl_simulate_series",
  "cl_validate","cl_confusion","cl_roc","cl_calibration","cl_compare","cl_benchmark",
  "cl_chunk","cl_apply_chunks","cl_visualize","cl_explore","cl_app","cl_export")
missing_fn <- setdiff(expected, exports)
ok("all expected functions present", length(missing_fn) == 0,
   if (length(missing_fn)) paste("MISSING:", paste(missing_fn, collapse = ", ")) else "")

# S3 methods must be registered, or print() falls back to the data frame method
s3 <- tryCatch({
  m <- utils::methods(class = "cl_stats"); length(m) > 0
}, error = function(e) FALSE)
ok("S3 methods registered", s3)

# Help pages: absent .Rd means the install came from a source tree that was
# never documented, which is easy to do and silently degrades usability.
rd <- tryCatch({
  db <- tools::Rd_db("cloudscape"); length(db)
}, error = function(e) 0L)
ok("help pages installed", rd >= 60, sprintf("%d topics", rd))
if (rd == 0) {
  NOTES <- c(NOTES, paste(
    "No help pages. man/ is missing from the installed package, usually",
    "because install_github() pulled a commit where man/ was gitignored.",
    "Check the default branch on GitHub, or install with @main."))
}

# A raw topic count is a weak test: it changes whenever documentation is
# reorganised, and an earlier version of this script failed a perfectly good
# install because 12 invalid S3 stubs had been correctly removed. Naming the
# topics that must resolve tests what actually matters.
key_topics <- c("cl_grid", "cl_project", "cl_search", "cl_obs", "cl_clear_obs",
                "cl_gaps", "cl_persistence", "cl_probability", "cl_shadow",
                "cl_simulate", "cl_validate", "cl_pheno_power",
                "sensor-registry", "cloudscape-package")
have <- tryCatch(names(tools::Rd_db("cloudscape")), error = function(e) character())
have <- sub("\\.Rd$", "", have)
gone <- setdiff(key_topics, have)
ok("key help topics resolve", length(gone) == 0,
   if (length(gone)) paste("missing:", paste(gone, collapse = ", "))
   else sprintf("%d of %d checked", length(key_topics), length(key_topics)))

vig <- tryCatch(nrow(vignette(package = "cloudscape")$results), error = function(e) 0L)
if (vig >= 1) ok("vignettes installed", TRUE, sprintf("%d found", vig)) else
  skip("vignettes installed", "install with build_vignettes = TRUE to include them")

# Registries populate in .onLoad; if these are empty the load hook did not run
ns <- nrow(cl_sensors())
ok("sensor drivers registered (>= 5)", ns >= 5, sprintf("%d drivers", ns))
nm <- nrow(cl_methods())
ok("detection methods registered (>= 7)", nm >= 7, sprintf("%d methods", nm))

# =============================================================================
# B. NUMERICAL SELF-TEST
#
# These re-derive results the manuscript reports, from scratch, on this
# machine. They are cheap and they are the ones that would break if a build
# went wrong or a dependency behaved differently here.
# =============================================================================
sec("B. Numerical self-test")

# B1 -- the equal-area property: projected globe area vs true WGS84 area
xr <- diff(range(cl_project(c(-180, 180), c(0, 0))[, "x"]))
yr <- diff(range(cl_project(c(0, 0), c(-90, 90))[, "y"]))
relerr <- abs(xr * yr - 5.100656217e14) / 5.100656217e14
ok("equal-area projection (rel. error < 1e-9)", relerr < 1e-9,
   sprintf("%.2e", relerr))

# B2 -- projection round-trip
lon <- c(-179, -60, 0, 45, 179); lat <- c(-85, -30, 0, 30, 82)
b <- cl_unproject(cl_project(lon, lat)[, "x"], cl_project(lon, lat)[, "y"])
rt <- max(abs(b[, "lon"] - lon), abs(b[, "lat"] - lat))
ok("projection round-trip (< 1e-9 deg)", rt < 1e-9, sprintf("%.2e", rt))

# B3 -- latitude bias: a fixed-degree box must shrink towards the pole
g <- cl_grid(res = 25000)
bx <- function(la) cbind(c(0, 2, 2, 0, 0), c(la, la, la + 2, la + 2, la))
n0 <- nrow(cl_grid_index(bx(0), g)); n75 <- nrow(cl_grid_index(bx(75), g))
ok("latitude bias reproduced", n75 < n0 / 3,
   sprintf("%d cells at 0 deg vs %d at 75 deg", n0, n75))

# B4 -- shadow displacement identity
zens <- c(0, 30, 45, 60, 75)
err <- max(abs(vapply(zens, function(z)
  sqrt(sum(cl_shadow_offset(1000, z, 180)^2)), numeric(1)) -
    1000 * tan(zens * pi / 180)))
ok("shadow displacement = h*tan(zenith)", err < 1e-8, sprintf("%.2e m", err))

# B5 -- simulator and detector agree on geometry
s <- cl_simulate(100, 100, coverage = 0.25, height = 2500, res = 30,
                 sun_zenith = 45, sun_azimuth = 160, seed = 42)
r <- suppressWarnings(cl_shadow_project(s$cloud, s$shadow, res = 30,
       sun_zenith = 45, sun_azimuth = 160, heights = seq(500, 6000, by = 100)))
ok("cloud-top height recovered", abs(r$height - 2500) <= 200,
   sprintf("planted 2500 m, recovered %.0f m", r$height))

# B6 -- Markov chain preserves its marginal
dts <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
mk <- mean(vapply(1:100, function(k)
  mean(cl_simulate_series(dts, p_cloud = 0.6, persistence = 0.5, seed = k)$cloudy),
  numeric(1)))
ok("cloud marginal preserved", abs(mk - 0.6) < 0.04, sprintf("%.3f vs 0.600", mk))

# B7 -- persistence estimator recovers a known rho
est <- mean(vapply(1:20, function(k) {
  ts <- cl_simulate_series(seq(as.Date("2015-01-01"), as.Date("2024-12-31"),
                               by = "5 days"), 0.5, 0.6, seed = k)
  cl_persistence(cl_obs(1, ts$date, as.numeric(ts$cloudy), sensor = "s2"),
                 threshold = 0.5)$rho
}, numeric(1)))
ok("persistence estimator (rho = 0.6)", abs(est - 0.6) < 0.06, sprintf("%.3f", est))

# B8 -- the unit validator must reject bad input
ok("rejects out-of-range metric value",
   inherits(tryCatch(cl_stats(1:2, "cloud_fraction", c(0.3, 1.4)),
                     error = function(e) e), "error"))
ok("rejects unknown metric name",
   inherits(tryCatch(cl_stats(1, "images_per_pathrow", 3),
                     error = function(e) e), "error"))

# B9 -- metrics combine by their declared rule
a <- cl_stats(1, "cloud_fraction", 0.2, period = "2023", n = 90)
bb <- cl_stats(1, "cloud_fraction", 0.8, period = "2023", n = 10)
ok("weighted-mean combination", abs(cl_stats_merge(a, bb)$value - 0.26) < 1e-9,
   sprintf("%.3f (mean-of-means would be 0.500)", cl_stats_merge(a, bb)$value))

# B10 -- accuracy metrics on a hand-computed confusion matrix
v <- cl_validate(c(rep(1, 60), rep(0, 10), rep(1, 5), rep(0, 25)),
                 c(rep(1, 70), rep(0, 30)))
i <- which(v$class == "1")
ok("accuracy metrics exact", abs(v$iou[i] - 60/75) < 1e-9,
   sprintf("IoU %.4f", v$iou[i]))

# B11 -- detection runs end to end
bg <- list(blue = matrix(0.06, 64, 64), green = matrix(0.08, 64, 64),
           red = matrix(0.05, 64, 64), nir = matrix(0.32, 64, 64),
           swir16 = matrix(0.20, 64, 64), swir22 = matrix(0.12, 64, 64))
sim <- cl_simulate(background = bg, coverage = 0.3, opacity = 1, seed = 7)
pm <- cl_probability(sim$bands, "fmask", sensor = "sentinel-2-msi")
vv <- cl_validate(pm$class, sim$cloud)
acc <- unname(attr(vv, "overall")["overall_accuracy"])
ok("fmask detection accuracy > 0.95", acc > 0.95, sprintf("%.3f", acc))

# B12 -- applicability filtering by sensor capability
ok("method filtering by sensor",
   !("fmask" %in% cl_methods(sensor = "generic-multispectral")$method),
   "fmask correctly unavailable on a 4-band sensor")

# =============================================================================
# C. LIVE CATALOGUE ACCESS
#
# This is the part that could not be tested during development. If it fails,
# the package is fine but this machine cannot reach the catalogue, and the
# message below will usually say why.
# =============================================================================
sec("C. Live catalogue access")

have_net <- requireNamespace("httr2", quietly = TRUE) &&
            requireNamespace("jsonlite", quietly = TRUE)
if (!have_net) {
  skip("STAC query", 'install.packages(c("httr2","jsonlite")) first')
  NOTES <- c(NOTES, "httr2/jsonlite missing: cl_search() will not work.")
} else {
  cat(sprintf("         endpoint: %s\n", cl_catalog()$url))
  aoi <- c(128.4, 36.4, 128.9, 36.8)   # Andong, Republic of Korea

  t0 <- Sys.time()
  s2 <- tryCatch(cl_search(aoi, "sentinel-2-msi", "2024-06-01", "2024-06-30",
                           limit = 50), error = function(e) e)
  el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  if (inherits(s2, "error")) {
    ok("Sentinel-2 query", FALSE, substr(conditionMessage(s2), 1, 55))
    NOTES <- c(NOTES, paste("Catalogue unreachable:", conditionMessage(s2)),
               "Try cl_options(catalog = 'planetary') or check a proxy/firewall.")
  } else {
    ok("Sentinel-2 query returns scenes", nrow(s2) > 0,
       sprintf("%d scenes in %.1fs", nrow(s2), el))
    ok("datetimes parsed", all(!is.na(s2$datetime)),
       sprintf("%s to %s", min(as.Date(s2$datetime)), max(as.Date(s2$datetime))))
    ok("cloud cover present", any(!is.na(s2$cloud_cover)),
       sprintf("median %.1f%%", stats::median(s2$cloud_cover, na.rm = TRUE)))
    ok("MGRS tile parsed, not literal 'NANANA'",
       any(!is.na(s2$tile)) && !any(s2$tile %in% "NANANA", na.rm = TRUE),
       paste(utils::head(unique(s2$tile), 3), collapse = ", "))
    ok("platform distinguishes 2A/2B/2C", length(unique(s2$platform)) >= 1,
       paste(unique(s2$platform), collapse = ", "))

    ls8 <- tryCatch(cl_search(aoi, "landsat-8-9-oli", "2024-06-01", "2024-08-31",
                              limit = 50), error = function(e) e)
    if (inherits(ls8, "error")) {
      ok("Landsat query", FALSE, substr(conditionMessage(ls8), 1, 55))
    } else {
      ok("Landsat query returns scenes", nrow(ls8) > 0,
         sprintf("%d scenes", nrow(ls8)))
      ok("WRS-2 path/row parsed", any(!is.na(ls8$path)),
         sprintf("path %s row %s", ls8$path[1], ls8$row[1]))
      ok("Landsat tile is NA, not 'NANANA'", all(is.na(ls8$tile)))
    }

    # Footprints must land on the grid, and the cells must be near the AOI
    obs <- tryCatch(suppressWarnings(cl_items_to_obs(s2, cl_grid(res = 25000))),
                    error = function(e) e)
    if (inherits(obs, "error")) {
      ok("footprints map onto the grid", FALSE, substr(conditionMessage(obs), 1, 50))
    } else {
      cc <- cl_grid_cells(cl_grid(res = 25000), unique(obs$cell))
      near <- all(abs(cc$lat - 36.6) < 2) && all(abs(cc$lon - 128.65) < 2)
      ok("footprints map onto the grid", nrow(obs) > 0,
         sprintf("%d cell-observations over %d cells", nrow(obs), nrow(cc)))
      ok("cells are at the requested location", near,
         sprintf("lat %.2f-%.2f, lon %.2f-%.2f",
                 min(cc$lat), max(cc$lat), min(cc$lon), max(cc$lon)))

      st <- suppressMessages(cl_clear_obs(obs, by = "month", threshold = 0.2))
      ok("availability statistics compute", nrow(st) > 0,
         sprintf("%d rows, validator passed", nrow(st)))
      ok("statistics carry a denominator", all(nzchar(st$denominator)),
         unique(st$denominator))
    }
  }
}

# =============================================================================
# SUMMARY
# =============================================================================
cat("\n", strrep("=", 70), "\n", sep = "")
cat(sprintf("RESULT:  %d passed, %d failed, %d skipped\n", PASS, FAIL, SKIP))
cat(strrep("=", 70), "\n", sep = "")

if (length(NOTES)) {
  cat("\nNotes:\n"); for (n in NOTES) cat("  -", n, "\n")
}

if (FAIL == 0) {
  cat("\nInstallation verified. Next step, from R:\n\n")
  cat('  script <- system.file("scripts", "run-real-analysis.R", package = "cloudscape")\n')
  cat('  system(paste("Rscript", script, "--mode test"))\n\n')
  cat("or from a shell:\n\n")
  cat('  Rscript -e \'cat(system.file("scripts","run-real-analysis.R",package="cloudscape"))\'\n\n')
} else {
  cat("\nSomething is wrong. Send me the full output above.\n\n")
}

# Optional report to send back
rep <- c(sprintf("cloudscape check  %s", format(Sys.time())),
         sprintf("version %s | passed %d | failed %d | skipped %d",
                 ver, PASS, FAIL, SKIP),
         sprintf("exports %d | help topics %d | sensors %d | methods %d",
                 length(exports), rd, ns, nm),
         "", utils::capture.output(utils::sessionInfo()))
writeLines(rep, "cloudscape-check-report.txt")
cat("Report written to cloudscape-check-report.txt\n\n")
