#!/usr/bin/env Rscript
# =============================================================================
#  cloudscape — WORKED EXAMPLE
#
#  A complete pass over one real place, from "where is it" to "can I do my
#  study here". This is the demonstration the package needed: every function
#  in sequence, on data anyone can fetch, with the output of each step shown.
#
#  RUN:
#      OUTDIR <- "D:/sdm/new papers/idea/cloudscape/out"
#      source("path/to/worked-example.R")
#
#  Change the site with:
#      SITE <- list(name = "Wageningen", lon = 5.66, lat = 51.97)
#
#  Takes about two minutes and downloads only metadata.
# =============================================================================

suppressPackageStartupMessages(library(cloudscape))
stopifnot(requireNamespace("httr2", quietly = TRUE),
          requireNamespace("jsonlite", quietly = TRUE))

# This script uses features added after the first release. Check once, here,
# rather than letting a missing argument surface as an unexplained empty result.
.need <- c("cl_persistence", "cl_items_to_obs", "cl_pheno_map", "cl_solar_position")
.have <- vapply(.need, function(f) {
  e <- tryCatch(getNamespaceExports("cloudscape"), error = function(x) NULL)
  if (!is.null(e)) f %in% e else exists(f, mode = "function")
}, logical(1))
if (!all(.have)) {
  stop("The installed cloudscape is too old: missing ",
       paste(.need[!.have], collapse = ", "), ".\n",
       "  remotes::install_github(\"ehsanrahimi666/cloudscape@main\", force = TRUE)",
       call. = FALSE)
}
if (!"n_tiles" %in% names(formals(cl_items_to_obs)) &&
    !"overpass_minutes" %in% names(formals(cl_items_to_obs))) {
  warning("Installed cloudscape predates overpass collapsing; observation ",
          "counts will be inflated. Reinstall from @main.", call. = FALSE)
}

if (!exists("OUTDIR")) OUTDIR <- "out"
if (!exists("SITE")) SITE <- list(name = "Andong, Republic of Korea",
                                  lon = 128.73, lat = 36.57)
if (!exists("YEARS")) YEARS <- 2019:2024

EX <- file.path(OUTDIR, "worked-example")
dir.create(EX, recursive = TRUE, showWarnings = FALSE)
LOG <- character()
say <- function(...) { t <- sprintf(...); cat(t, "\n", sep = ""); LOG <<- c(LOG, t) }
step <- function(n, title) { say(""); say("=== STEP %d  %s ===", n, title) }

say("cloudscape worked example")
say("site   : %s  (%.2f, %.2f)", SITE$name, SITE$lon, SITE$lat)
say("period : %d-%d", min(YEARS), max(YEARS))
say("output : %s", normalizePath(EX, mustWork = FALSE))

# -----------------------------------------------------------------------------
step(1, "Define an equal-area analysis area")
# -----------------------------------------------------------------------------
# The unit of analysis is a block of equal-area grid cells, not a box in
# degrees. A degree box shrinks towards the poles; these cells do not, so the
# same code gives comparable answers anywhere on Earth.
grid <- cl_grid(res = 25000)
k <- cl_grid_lookup(grid, SITE$lon, SITE$lat)
row <- ((k - 1L) %/% grid$ncol) + 1L; col <- ((k - 1L) %% grid$ncol) + 1L
off <- -2:1
cells <- as.vector(outer((row + off - 1L) * grid$ncol, col + off, "+"))
cc <- cl_grid_cells(grid, cells)
x0 <- grid$xmin + (min(col + off) - 1L) * grid$res
x1 <- grid$xmin + max(col + off) * grid$res
y1 <- grid$ymax - (min(row + off) - 1L) * grid$res
y0 <- grid$ymax - max(row + off) * grid$res
ll <- cl_unproject(c(x0, x1), c(y0, y1))
aoi <- c(ll[1, "lon"], ll[1, "lat"], ll[2, "lon"], ll[2, "lat"])
say("  %d cells of %g x %g km = %g km2 total",
    nrow(cc), grid$res / 1000, grid$res / 1000, nrow(cc) * (grid$res / 1000)^2)
say("  query box: %.3f, %.3f to %.3f, %.3f", aoi[1], aoi[2], aoi[3], aoi[4])
say("  every cell has area %g km2, identical at any latitude", cc$area_km2[1])

# -----------------------------------------------------------------------------
step(2, "Ask the catalogue what exists")
# -----------------------------------------------------------------------------
say("  backend: %s (no account needed)", cl_catalog()$url)
items <- list(); n_err <- 0L
for (sn in c("landsat-8-9-oli", "sentinel-2-msi")) {
  for (y in YEARS) {
    for (q in 1:4) {
      a <- as.Date(sprintf("%d-%02d-01", y, (q - 1) * 3 + 1))
      b <- seq(a, by = "3 months", length.out = 2)[2] - 1
      it <- tryCatch(suppressWarnings(cl_search(aoi, sn, a, b, limit = Inf)),
                     error = function(e) e)
      if (inherits(it, "error")) {
        # Never swallow this. An earlier version turned every failure into
        # NULL, so a wrong argument and a network outage looked identical:
        # "0 scenes", with no way to tell which.
        n_err <- n_err + 1L
        if (n_err <= 3L) say("  ! %s %s: %s", sn, format(a, "%Y-%m"),
                             conditionMessage(it))
        next
      }
      if (nrow(it)) items[[length(items) + 1L]] <- it
    }
  }
  say("  %s: cumulative %d scenes", sn,
      sum(vapply(items, nrow, integer(1))))
}
if (!length(items)) {
  stop("No scenes were returned by any query.\n",
       if (n_err) sprintf("  %d request(s) failed; the first errors are above.\n", n_err)
       else "  Every request succeeded but returned nothing, which is unusual.\n",
       "  Check the site coordinates, then try this single call directly:\n",
       "    cl_search(c(", paste(round(aoi, 3), collapse = ", "),
       "), \"sentinel-2-msi\", \"2024-06-01\", \"2024-06-30\")",
       call. = FALSE)
}
geoms <- unlist(lapply(items, function(x) attr(x, "geometry")), recursive = FALSE)
IT <- structure(do.call(rbind, lapply(items, as.data.frame)),
                class = c("cl_items", "data.frame"), geometry = geoms,
                assets = list(), manifest = attr(items[[1]], "manifest"))
say("  total %d scenes, %s to %s", nrow(IT),
    min(as.Date(IT$datetime)), max(as.Date(IT$datetime)))
utils::write.csv(as.data.frame(IT)[, c("id", "datetime", "sensor", "platform",
                                       "cloud_cover")],
                 file.path(EX, "E1_scenes.csv"), row.names = FALSE)

# -----------------------------------------------------------------------------
step(3, "Turn scenes into observations of each cell")
# -----------------------------------------------------------------------------
obs <- suppressWarnings(cl_items_to_obs(IT, grid))
obs <- obs[obs$cell %in% cells, , drop = FALSE]
say("  %d cell-observations over %d cells", nrow(obs), length(unique(obs$cell)))
say("  mean tiles collapsed per observation: %.2f", mean(obs$n_tiles))
say("  NOTE tier is '%s': cloud cover is a SCENE average, so what follows",
    attr(obs, "tier"))
say("       is an upper bound on usability. See ?cl_clear_prob.")

# -----------------------------------------------------------------------------
step(4, "How much usable data is there?")
# -----------------------------------------------------------------------------
av <- suppressMessages(cl_clear_obs(obs, by = "year", threshold = 0.2, grid = grid))
avw <- cl_stats_wide(av)
yr <- stats::aggregate(cbind(n_scenes, n_clear_obs) ~ period, avw, mean)
say("  year  acquisitions  usable  cloud")
for (i in seq_len(nrow(yr))) {
  cf <- mean(avw$cloud_fraction[avw$period == yr$period[i]])
  say("  %s        %6.0f  %6.0f  %5.2f", yr$period[i], yr$n_scenes[i],
      yr$n_clear_obs[i], cf)
}
utils::write.csv(avw, file.path(EX, "E2_availability.csv"), row.names = FALSE)

# -----------------------------------------------------------------------------
step(5, "What actually breaks a time series: the gaps")
# -----------------------------------------------------------------------------
g <- cl_stats_wide(cl_gaps(obs, threshold = 0.2, by = "year", critical = 21))
say("  longest gap without a usable image, per cell-year:")
say("    median %.0f d, 90th percentile %.0f d, worst %.0f d",
    stats::median(g$max_gap_days), stats::quantile(g$max_gap_days, .9),
    max(g$max_gap_days))
utils::write.csv(g, file.path(EX, "E3_gaps.csv"), row.names = FALSE)

# -----------------------------------------------------------------------------
step(6, "When is the sky clearest here?")
# -----------------------------------------------------------------------------
se <- cl_seasonality(obs, threshold = 0.2, harmonics = 2L, window_days = 60)
se <- se[se$converged, , drop = FALSE]
if (nrow(se)) {
  say("  clearest day of year : %.0f (%s)", stats::median(se$peak_doy),
      format(as.Date(stats::median(se$peak_doy) - 1, origin = "2023-01-01"), "%d %B"))
  say("  best 60-day window   : day %.0f to %.0f",
      stats::median(se$window_start), stats::median(se$window_end))
  say("  clear probability    : %.2f at the peak, %.2f at the trough",
      mean(se$p_clear_peak), mean(se$p_clear_trough))
  utils::write.csv(se, file.path(EX, "E4_seasonality.csv"), row.names = FALSE)
}

# -----------------------------------------------------------------------------
step(7, "How persistent is the cloud?")
# -----------------------------------------------------------------------------
pe <- cl_persistence(obs, threshold = 0.2, max_interval = 20)
if (nrow(pe)) {
  say("  cloud fraction        : %.2f", mean(pe$p_cloud))
  say("  lag-1 autocorrelation : %.3f at a %.0f-day interval",
      mean(pe$rho), stats::median(pe$median_interval_days))
  say("  decorrelation time    : %.2f days", mean(pe$decorrelation_days, na.rm = TRUE))
  say("  mean cloudy run       : %.2f observations", mean(pe$mean_cloudy_run))
  say("  (run length reflects cloud AMOUNT; decorrelation time is the")
  say("   clustering that amount does not explain)")
  utils::write.csv(pe, file.path(EX, "E5_persistence.csv"), row.names = FALSE)
}

# -----------------------------------------------------------------------------
step(8, "Can I retrieve start of season here?")
# -----------------------------------------------------------------------------
y_last <- max(YEARS)
sub <- obs[format(obs$date, "%Y") == as.character(y_last), , drop = FALSE]
ph <- cl_pheno_map(sub, year = y_last, n_sim = 200)
det <- attr(ph, "details")
say("  using the ACTUAL acquisition dates of %d:", y_last)
say("    acquisitions %.0f, usable %.0f", stats::median(det$n_acquisitions),
    stats::median(det$n_usable_median))
say("    SOS error %.1f days (IQR %.1f), fits failing %.1f%%",
    stats::median(det$sos_mae, na.rm = TRUE),
    stats::median(det$sos_iqr, na.rm = TRUE),
    100 * stats::median(det$failure_rate, na.rm = TRUE))
utils::write.csv(det, file.path(EX, "E6_phenology.csv"), row.names = FALSE)

# Counterfactual: the same place with one satellite instead of four.
say("  counterfactual, Sentinel-2 alone (as before Landsat 9 joined):")
# One cell, not all of them. Pooling dates across 16 cells multiplies the
# apparent acquisition count sixteenfold and would make the counterfactual
# look better than the full constellation, which is the opposite of the truth.
ref_cell <- names(sort(table(sub$cell), decreasing = TRUE))[1]
one <- sub[sub$cell == as.integer(ref_cell), , drop = FALSE]
combo <- cl_pheno_power(one$date, one$cloud_fraction, n_sim = 200, seed = 1)$summary
s2 <- one[grepl("sentinel", one$sensor), , drop = FALSE]
say("    all sensors    : %3.0f acquisitions, %3.0f usable, SOS error %.1f d, %.0f%% fail",
    combo$n_acquisitions, combo$n_usable_median, combo$sos_mae,
    100 * combo$failure_rate)
if (nrow(s2) > 20) {
  p2 <- cl_pheno_power(s2$date, s2$cloud_fraction, n_sim = 200, seed = 1)$summary
  say("    Sentinel-2 only: %3.0f acquisitions, %3.0f usable, SOS error %.1f d, %.0f%% fail",
      p2$n_acquisitions, p2$n_usable_median, p2$sos_mae, 100 * p2$failure_rate)
}

# -----------------------------------------------------------------------------
step(9, "Detect cloud and shadow on a synthetic scene")
# -----------------------------------------------------------------------------
# Detection is shown on a simulated scene because the truth is then known
# exactly, which is what makes the accuracy figures meaningful. The same call
# runs on a real scene once reflectance is loaded with cl_import().
bg <- list(blue = matrix(0.06, 160, 160), green = matrix(0.08, 160, 160),
           red = matrix(0.05, 160, 160), nir = matrix(0.32, 160, 160),
           swir16 = matrix(0.20, 160, 160), swir22 = matrix(0.12, 160, 160))
solar <- cl_solar_position(as.POSIXct(sprintf("%d-06-15 02:30:00", y_last), tz = "UTC"),
                           SITE$lon, SITE$lat)
say("  sun at this site, 15 June: zenith %.1f deg, azimuth %.1f deg",
    solar$zenith, solar$azimuth)
sim <- cl_simulate(background = bg, coverage = 0.30, opacity = c(0.3, 1),
                   height = 2500, res = 30, sun_zenith = solar$zenith,
                   sun_azimuth = solar$azimuth, seed = 42)
res <- do.call(rbind, lapply(c("threshold", "fmask"), function(m) {
  p <- cl_probability(sim$bands, m, sensor = "sentinel-2-msi")
  v <- cl_validate(p$class, sim$cloud); i <- which(v$class == "1")
  data.frame(method = m, precision = v$precision[i], recall = v$recall[i],
             iou = v$iou[i],
             accuracy = unname(attr(v, "overall")["overall_accuracy"]),
             ece = attr(cl_calibration(p$probability, sim$cloud), "ece"),
             stringsAsFactors = FALSE)
}))
for (i in seq_len(nrow(res))) {
  say("  %-10s IoU %.3f  recall %.3f  accuracy %.3f  calibration error %.3f",
      res$method[i], res$iou[i], res$recall[i], res$accuracy[i], res$ece[i])
}
sh <- cl_shadow(sim$cloud, nir = sim$bands$nir, swir = sim$bands$swir16,
                res = 30, sun_zenith = solar$zenith, sun_azimuth = solar$azimuth,
                heights = seq(500, 6000, by = 100))
say("  cloud-top height: planted 2500 m, recovered %.0f m", sh$params$height)
vs <- cl_validate(sh$shadow, sim$shadow)
say("  shadow IoU %.3f", vs$iou[vs$class == "1"])
utils::write.csv(res, file.path(EX, "E7_detection.csv"), row.names = FALSE)

# -----------------------------------------------------------------------------
step(10, "Figures and an interactive map")
# -----------------------------------------------------------------------------
fig <- function(name, w, h, draw) {
  grDevices::pdf(file.path(EX, paste0(name, ".pdf")), width = w, height = h, pointsize = 10)
  draw(); grDevices::dev.off()
  try({ grDevices::png(file.path(EX, paste0(name, ".png")),
                       width = round(w * 150), height = round(h * 150), res = 150)
        draw(); grDevices::dev.off() }, silent = TRUE)
  say("  wrote %s.pdf + .png", name)
}
P <- c("#1b6ca8", "#c0392b", "#16a085", "#e08a1e")

fig("W1_timeline", 8.0, 3.6, function() {
  graphics::par(mar = c(4, 4.4, 1.6, .8), mgp = c(2.6, .7, 0), bty = "l", las = 1)
  o <- obs[order(obs$date), ]
  plot(o$date, o$cloud_fraction, type = "h",
       col = ifelse(o$cloud_fraction <= 0.2, P[3], grDevices::adjustcolor(P[1], .35)),
       xlab = "", ylab = "Scene cloud fraction", ylim = c(0, 1),
       main = sprintf("%s: every acquisition, %d-%d", SITE$name,
                      min(YEARS), max(YEARS)), cex.main = .95)
  graphics::abline(h = 0.2, lty = 2, col = P[2])
  graphics::legend("topleft", bty = "n", cex = .78, horiz = TRUE,
                   legend = c("usable", "cloudy"), fill = c(P[3], P[1]), border = NA)
})

fig("W2_seasonal_clear", 6.4, 4.0, function() {
  graphics::par(mar = c(4.2, 4.4, 1.6, .8), mgp = c(2.6, .7, 0), bty = "l", las = 1)
  doy <- as.integer(format(obs$date, "%j"))
  br <- seq(0, 366, by = 14)
  b <- cut(doy, br)
  p <- tapply(obs$cloud_fraction <= 0.2, b, mean)
  mid <- (br[-1] + br[-length(br)]) / 2
  plot(mid, as.numeric(p), type = "h", lwd = 8, lend = 1, col = P[1],
       ylim = c(0, 1), xlab = "Day of year",
       ylab = "Probability an acquisition is usable",
       main = sprintf("Seasonal usability at %s", SITE$name), cex.main = .95)
  graphics::abline(h = mean(obs$cloud_fraction <= 0.2), lty = 2, col = P[2])
})

fig("W3_detection", 7.6, 2.9, function() {
  graphics::par(mfrow = c(1, 4), mar = c(.6, .6, 2.0, .6))
  shw <- function(m, ttl) {
    graphics::image(t(m[nrow(m):1, ]), axes = FALSE,
                    col = grDevices::grey.colors(64), main = ttl, cex.main = 1.0)
    graphics::box(col = "grey70")
  }
  shw(sim$bands$red, "Contaminated red")
  shw(sim$cloud, "True cloud")
  p <- cl_probability(sim$bands, "fmask", sensor = "sentinel-2-msi")
  shw(p$probability, "fmask probability")
  shw(sim$shadow + 2 * sh$shadow, "Shadow: true vs found")
})

mp <- tryCatch({
  st <- av[av$metric == "n_clear_obs", ]
  cl_explore(st, metric = "n_clear_obs", period = as.character(y_last),
             file = file.path(EX, "W4_map.html"), grid = grid,
             title = sprintf("Usable observations, %s, %d", SITE$name, y_last))
}, error = function(e) NULL)
if (!is.null(mp)) say("  wrote W4_map.html (open in a browser)")

# -----------------------------------------------------------------------------
writeLines(LOG, file.path(EX, "WORKED-EXAMPLE-LOG.txt"))
say(""); say("Done. %d files in %s",
             length(list.files(EX)), normalizePath(EX, mustWork = FALSE))
