#!/usr/bin/env Rscript
# =============================================================================
#  cloudscape — FIGURES AND TABLES FOR THE MANUSCRIPT
#
#  Reads the CSVs produced by run-real-analysis.R, checks them for the errors
#  that have actually occurred, repairs the two that are recoverable, and
#  writes publication figures and tables.
#
#  RUN FROM R:
#      setwd("C:/Users/USER/Documents")
#      source(system.file("scripts", "make-figures.R", package = "cloudscape"))
#
#  OR FROM CMD:
#      cd C:\Users\USER\Documents
#      Rscript -e "source(system.file('scripts','make-figures.R',package='cloudscape'))"
#
#  Optional: set either or both, using FORWARD slashes
#      RESULTS <- "C:/Users/USER/Documents/cloudscape-results"   # where to read
#      OUTDIR  <- "D:/sdm/new papers/idea/cloudscape"            # where to write
#      source(...)
#
#  OUTPUT (in OUTDIR, or <results>/paper/ if OUTDIR is not set):
#      figures/*.pdf   vector, for the journal
#      figures/*.png   raster, for quick viewing and for sending to review
#      tables/*.csv    every manuscript table
#      QC-REPORT.txt   the data check, pass by pass
#
#  Nothing is downloaded and nothing already present is overwritten except the
#  contents of <results>/paper/.
# =============================================================================

suppressPackageStartupMessages(library(cloudscape))

# Locate the results.
#
# The script is usually sourced from whatever directory R happens to be in,
# which is rarely the one the harvest wrote to. Rather than fail, look in the
# obvious places first and say clearly what was tried.
.cs_find_results <- function() {
  cand <- c("cloudscape-results",
            file.path(path.expand("~"), "Documents", "cloudscape-results"),
            file.path(path.expand("~"), "cloudscape-results"),
            file.path(path.expand("~"), "Desktop", "cloudscape-results"),
            file.path(dirname(getwd()), "cloudscape-results"))
  hit <- cand[dir.exists(cand) &
                file.exists(file.path(cand, "R3_persistence.csv"))]
  if (length(hit)) return(hit[1])
  # Last resort: search two levels below the home directory
  roots <- list.dirs(path.expand("~"), recursive = FALSE)
  deep <- unlist(lapply(roots, function(r)
    list.dirs(r, recursive = FALSE)[
      basename(list.dirs(r, recursive = FALSE)) == "cloudscape-results"]))
  deep <- deep[file.exists(file.path(deep, "R3_persistence.csv"))]
  if (length(deep)) return(deep[1])
  character()
}
if (!exists("RESULTS")) {
  found <- .cs_find_results()
  if (length(found)) {
    RESULTS <- found
    message("Using results found at: ", normalizePath(RESULTS, mustWork = FALSE))
  } else RESULTS <- "cloudscape-results"
}
# RESULTS may be the zip the harvest produced. Unpacking it removes any
# question of which folder the CSVs are in.
if (grepl("\\.zip$", RESULTS, ignore.case = TRUE) && file.exists(RESULTS)) {
  ztmp <- file.path(tempdir(), "cloudscape-unzipped")
  unlink(ztmp, recursive = TRUE); dir.create(ztmp, recursive = TRUE)
  utils::unzip(RESULTS, exdir = ztmp)
  hit <- list.files(ztmp, pattern = "^R3_persistence\\.csv$",
                    recursive = TRUE, full.names = TRUE)
  if (!length(hit)) {
    stop("That zip does not contain R3_persistence.csv: ", RESULTS, call. = FALSE)
  }
  message("Reading results from inside the zip: ", RESULTS)
  RESULTS <- dirname(hit[1])
}

if (!dir.exists(RESULTS) || !file.exists(file.path(RESULTS, "R3_persistence.csv"))) {
  stop("Could not find the harvest results.\n",
       "  Looked in: ", normalizePath(RESULTS, mustWork = FALSE), "\n",
       "  and the usual places under ", path.expand("~"), "\n\n",
       "Set the path explicitly and source again, using FORWARD slashes:\n",
       "  RESULTS <- \"C:/Users/USER/Documents/cloudscape-results\"\n",
       "  source(\"path/to/make-figures.R\")\n\n",
       "The folder is the one run-real-analysis.R wrote to; it contains\n",
       "R3_persistence.csv and sites.csv.\n\n",
       "You can also point RESULTS at the zip file directly:\n",
       "  RESULTS <- \"C:/path/to/cloudscape-results-20260806.zip\"\n\n",
       "To find either one:\n",
       "  list.files(\"C:/Users\", pattern = \"R3_persistence.csv\",\n",
       "             recursive = TRUE, full.names = TRUE)",
       call. = FALSE)
}
# Where to write. Defaults beside the results; set OUTDIR to put the figures
# and tables somewhere else, for example alongside the manuscript.
OUT <- if (exists("OUTDIR")) OUTDIR else file.path(RESULTS, "paper")
dir.create(file.path(OUT, "figures"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(OUT, "tables"),  recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(file.path(OUT, "figures"))) {
  stop("Cannot write to: ", OUT, "\n",
       "Check the drive exists and the path is spelled correctly, and use\n",
       "forward slashes. Spaces in the path are fine.", call. = FALSE)
}

QC <- character()
say <- function(...) { t <- sprintf(...); cat(t, "\n", sep = ""); QC <<- c(QC, t) }
rule <- function() say(strrep("-", 72))
PASS <- 0L; FAIL <- 0L; WARN <- 0L
ok <- function(label, cond, detail = "") {
  cond <- isTRUE(tryCatch(cond, error = function(e) FALSE))
  if (cond) { PASS <<- PASS + 1L; s <- "PASS" } else { FAIL <<- FAIL + 1L; s <- "FAIL" }
  say("  [%s] %-44s %s", s, label, detail)
}
note <- function(label, detail) { WARN <<- WARN + 1L; say("  [NOTE] %-44s %s", label, detail) }

rd <- function(f) {
  # Accept a name with or without the extension. Calling rd("D1_x") instead of
  # rd("D1_x.csv") silently returned NULL, so six discovery figures were
  # skipped without any message.
  if (!grepl("\\.csv$", f)) f <- paste0(f, ".csv")
  p <- file.path(RESULTS, f)
  if (!file.exists(p)) return(NULL)
  utils::read.csv(p, stringsAsFactors = FALSE)
}

say(""); rule(); say("cloudscape figures and tables"); rule()
say("results : %s", normalizePath(RESULTS, mustWork = FALSE))
say("output  : %s", normalizePath(OUT, mustWork = FALSE))

sites <- rd("sites.csv")
r1 <- rd("R1_clear_observations.csv"); r2 <- rd("R2_gaps.csv")
r3 <- rd("R3_persistence.csv");        r4 <- rd("R4_cross_sensor.csv")
r5 <- rd("R5_seasonality.csv");        r6 <- rd("R6_phenology_feasibility.csv")
r7 <- rd("R7_measured_vs_nominal.csv")
miss <- c("sites.csv","R1_clear_observations.csv","R2_gaps.csv","R3_persistence.csv",
          "R4_cross_sensor.csv","R5_seasonality.csv","R6_phenology_feasibility.csv"
          )[c(is.null(sites), is.null(r1), is.null(r2), is.null(r3), is.null(r4),
              is.null(r5), is.null(r6))]
if (length(miss)) stop("Missing result file(s): ", paste(miss, collapse = ", "),
                       call. = FALSE)

# =============================================================================
# REPAIR 1 — rebuild the cell-to-site map
#
# Earlier runs attached site identity by row position after cl_obs() had
# re-sorted the rows, which scrambled the regime column while leaving latitude
# correct. Cells map to sites deterministically from the sampling design, so
# the labels are recoverable without re-harvesting. Recomputing them here is
# also the check: if the file's labels already agree, nothing changes.
# =============================================================================
GRID <- cl_grid(res = 25000); SIDE <- 4L
cells_of <- function(lon, lat) {
  k <- cl_grid_lookup(GRID, lon, lat); if (is.na(k)) return(integer())
  row <- ((k - 1L) %/% GRID$ncol) + 1L; col <- ((k - 1L) %% GRID$ncol) + 1L
  off <- seq(-(SIDE %/% 2L), by = 1L, length.out = SIDE)
  rows <- row + off; cols <- col + off
  rows <- rows[rows >= 1L & rows <= GRID$nrow]
  cols <- cols[cols >= 1L & cols <= GRID$ncol]
  as.integer(as.vector(outer((rows - 1L) * GRID$ncol, cols, "+")))
}
MAP <- do.call(rbind, lapply(seq_len(nrow(sites)), function(i) {
  cc <- cells_of(sites$lon[i], sites$lat[i])
  if (!length(cc)) return(NULL)
  data.frame(cell = cc, site_id = sites$site_id[i], site = sites$name[i],
             regime = sites$regime[i], stringsAsFactors = FALSE)
}))
MAP <- MAP[!duplicated(MAP$cell), , drop = FALSE]
gc0 <- cl_grid_cells(GRID, MAP$cell); MAP$lat <- gc0$lat; MAP$lon <- gc0$lon

fixup <- function(d) {
  if (is.null(d) || !nrow(d) || !"cell" %in% names(d)) return(d)
  k <- match(d$cell, MAP$cell)
  d$regime <- MAP$regime[k]; d$site <- MAP$site[k]
  d$lat <- MAP$lat[k]; d$abs_lat <- abs(d$lat)
  d
}
orig_regime <- if ("regime" %in% names(r3)) r3$regime else NA
r1 <- fixup(r1); r2 <- fixup(r2); r3 <- fixup(r3)
r4 <- fixup(r4); r5 <- fixup(r5); r6 <- fixup(r6)

# =============================================================================
# REPAIR 2 — lag-standardise the autocorrelation
#
# rho is a lag-1 autocorrelation measured at the local acquisition interval,
# which is ~1 day near the poles and ~5 days in the tropics because orbits
# converge. Autocorrelation decays with lag, so raw rho is not comparable
# across latitude. tau = -dt / log(rho) is.
# =============================================================================
if (!"decorrelation_days" %in% names(r3)) {
  r3$decorrelation_days <- NA_real_
  est <- !is.na(r3$rho) & r3$rho > 0 & r3$rho < 1
  r3$decorrelation_days[est] <- -r3$median_interval_days[est] / log(r3$rho[est])
}
r3$tau <- r3$decorrelation_days

# =============================================================================
# QC
# =============================================================================
say(""); rule(); say("DATA CHECK"); rule()

say("-- integrity --")
ok("cell-to-site map is one-to-one",
   !any(duplicated(MAP$cell)), sprintf("%d cells, %d sites",
                                       nrow(MAP), length(unique(MAP$site_id))))
ok("every result cell is in the map", all(!is.na(r1$regime)),
   sprintf("%d unmatched", sum(is.na(r1$regime))))
if (!identical(orig_regime, r3$regime) && !all(is.na(orig_regime))) {
  n <- sum(orig_regime != r3$regime, na.rm = TRUE)
  note("regime labels repaired",
       sprintf("%d of %d rows relabelled (row-position join bug)", n, nrow(r3)))
}

say("")
say("-- physical plausibility --")
NOM <- c("landsat-8-9-oli" = 46, "sentinel-2-msi" = 146)   # 2 platforms each
for (s in names(NOM)) {
  v <- r1$n_scenes[r1$sensor == s]
  if (!length(v)) next
  ok(sprintf("%s counts plausible", s),
     stats::median(v) < 3 * NOM[[s]],
     sprintf("median %.0f, nominal %d, max %.0f", stats::median(v), NOM[[s]], max(v)))
}
tot <- stats::aggregate(n_scenes ~ cell + period, r1, sum)
ok("combined density near nominal (192/cell-yr)",
   abs(stats::median(tot$n_scenes) / 192 - 1) < 0.5,
   sprintf("median %.0f (ratio %.2f)", stats::median(tot$n_scenes),
           stats::median(tot$n_scenes) / 192))
ok("clear observations never exceed acquisitions",
   all(r1$n_clear_obs <= r1$n_scenes + 1e-9))
ok("cloud fraction within [0, 1]",
   all(r1$cloud_fraction >= 0 & r1$cloud_fraction <= 1, na.rm = TRUE))
ok("gaps within one year", all(r2$max_gap_days <= 366, na.rm = TRUE),
   sprintf("max %.0f days", max(r2$max_gap_days, na.rm = TRUE)))
ok("rho within [-1, 1]", all(abs(r3$rho) <= 1, na.rm = TRUE))
ok("decorrelation time positive and finite",
   all(is.na(r3$tau) | (r3$tau > 0 & is.finite(r3$tau))),
   sprintf("%d of %d estimable", sum(!is.na(r3$tau)), nrow(r3)))

say("")
say("-- consistency --")
sp <- do.call(rbind, lapply(split(r3, r3$regime), function(d)
  data.frame(regime = d$regime[1], span = diff(range(abs(d$lat))))))
ok("regime labels match |latitude|", max(sp$span) < 25,
   sprintf("max span %.1f deg", max(sp$span)))
ok("cross-sensor rows have both sensors",
   all(r4$landsat_n > 0 & r4$sentinel_n > 0, na.rm = TRUE))
key <- paste(r1$cell, r1$period, r1$sensor)
ok("no duplicated cell-period-sensor rows", !any(duplicated(key)))
if (!is.null(r5)) {
  ok("seasonality fits converged", mean(r5$converged) > 0.8,
     sprintf("%.0f%% of %d cells", 100 * mean(r5$converged), nrow(r5)))
}

say("")
say("-- interpretation guards --")
byreg <- do.call(rbind, lapply(split(r3, r3$regime), function(d) data.frame(
  regime = d$regime[1], n = nrow(d), abs_lat = mean(abs(d$lat)),
  p_cloud = mean(d$p_cloud), rho = mean(d$rho),
  lag_days = stats::median(d$median_interval_days),
  tau = mean(d$tau, na.rm = TRUE), run = mean(d$mean_cloudy_run),
  stringsAsFactors = FALSE)))
cs <- suppressWarnings(stats::cor(byreg$run, byreg$p_cloud, method = "spearman"))
note("run length vs cloud amount",
     sprintf("Spearman %.2f -- run length is NOT evidence of clustering", cs))
ct <- suppressWarnings(stats::cor(byreg$tau, byreg$p_cloud, method = "spearman"))
note("decorrelation time vs cloud amount", sprintf("Spearman %.2f", ct))
thin <- byreg$regime[byreg$n < 32]
if (length(thin)) note("regimes with few cells",
                       paste(thin, collapse = ", "))

rule()
say("QC RESULT: %d passed, %d failed, %d notes", PASS, FAIL, WARN)
rule()

# =============================================================================
# FIGURES
# =============================================================================
PAL <- c("#1b6ca8", "#c0392b", "#16a085", "#e08a1e", "#6c3483", "#555555")
dev_open <- function(name, w, h) {
  grDevices::pdf(file.path(OUT, "figures", paste0(name, ".pdf")),
                 width = w, height = h, pointsize = 10)
}
dev_close <- function(name, w, h) {
  grDevices::dev.off()
  ok2 <- try(grDevices::png(file.path(OUT, "figures", paste0(name, ".png")),
                            width = w * 150, height = h * 150, res = 150), silent = TRUE)
  if (!inherits(ok2, "try-error")) { replay <- TRUE } else replay <- FALSE
  replay
}
# Draw each figure twice (PDF then PNG) rather than replaying a recorded plot,
# which is fragile across devices.
figure <- function(name, w, h, draw) {
  grDevices::pdf(file.path(OUT, "figures", paste0(name, ".pdf")),
                 width = w, height = h, pointsize = 10)
  draw(); grDevices::dev.off()
  res <- try({
    grDevices::png(file.path(OUT, "figures", paste0(name, ".png")),
                   width = round(w * 150), height = round(h * 150), res = 150)
    draw(); grDevices::dev.off()
  }, silent = TRUE)
  say("  wrote figures/%s.pdf%s", name,
      if (inherits(res, "try-error")) " (png failed)" else " + .png")
}
base_par <- function(...) graphics::par(mar = c(4.2, 4.3, 1.4, 0.8),
                                        mgp = c(2.6, 0.7, 0), bty = "l",
                                        las = 1, cex.axis = 0.9, ...)
wtab <- function(x, name) {
  utils::write.csv(x, file.path(OUT, "tables", paste0(name, ".csv")),
                   row.names = FALSE)
  say("  wrote tables/%s.csv (%d rows)", name, nrow(x))
}

say(""); rule(); say("FIGURES AND TABLES"); rule()

# --- F1: acquisition density against latitude -------------------------------
tot2 <- stats::aggregate(n_scenes ~ cell + period, r1, sum)
tot2 <- fixup(tot2)
figure("F1_acquisition_density", 6.6, 4.2, function() {
  base_par()
  plot(tot2$lat, tot2$n_scenes, pch = 16, col = grDevices::adjustcolor(PAL[1], .35),
       cex = .6, xlab = "Latitude (degrees)",
       ylab = "Acquisitions per cell per year",
       ylim = c(0, stats::quantile(tot2$n_scenes, .995)))
  graphics::abline(h = 192, lty = 2, col = PAL[2], lwd = 1.6)
  graphics::text(min(tot2$lat), 192, "nominal 192", pos = 3, cex = .8, col = PAL[2])
  lo <- stats::lowess(tot2$lat, tot2$n_scenes, f = .4)
  graphics::lines(lo, lwd = 2.4, col = PAL[1])
})

# --- F2: cloud amount and gaps against latitude -----------------------------
figure("F2_cloud_and_gaps", 7.2, 3.6, function() {
  graphics::par(mfrow = c(1, 2), mar = c(4.2, 4.3, 1.6, .6), mgp = c(2.5, .7, 0),
                bty = "l", las = 1, cex.axis = .85)
  plot(r1$lat, r1$cloud_fraction, pch = 16, cex = .5,
       col = grDevices::adjustcolor(PAL[1], .3), xlab = "Latitude (degrees)",
       ylab = "Cloud fraction", main = "Cloud amount", cex.main = .95)
  graphics::lines(stats::lowess(r1$lat, r1$cloud_fraction, f = .4), lwd = 2.4, col = PAL[2])
  plot(r2$lat, r2$max_gap_days, pch = 16, cex = .5,
       col = grDevices::adjustcolor(PAL[3], .3), xlab = "Latitude (degrees)",
       ylab = "Longest gap without a usable image (days)",
       main = "Observation gaps", cex.main = .95)
  graphics::lines(stats::lowess(r2$lat, r2$max_gap_days, f = .4), lwd = 2.4, col = PAL[2])
})

# --- F3: THE KEY FIGURE — persistence, lag-standardised ---------------------
byreg <- byreg[order(byreg$tau), ]
figure("F3_persistence", 7.4, 5.4, function() {
  graphics::layout(matrix(c(1, 1, 2, 3), 2, 2, byrow = TRUE), heights = c(1.35, 1))
  graphics::par(mar = c(4.0, 11.5, 1.6, .8), mgp = c(2.4, .6, 0), bty = "l",
                las = 1, cex.axis = .82)
  b <- graphics::barplot(byreg$tau, horiz = TRUE, names.arg = byreg$regime,
                         col = PAL[1], border = NA, xlab = "Decorrelation time (days)",
                         main = "Cloud persistence by climate regime", cex.main = .95,
                         xlim = c(0, max(byreg$tau, na.rm = TRUE) * 1.15))
  graphics::text(byreg$tau, b, sprintf(" %.1f", byreg$tau), pos = 4, cex = .72)

  graphics::par(mar = c(4.2, 4.4, 2.0, .8), las = 1)
  plot(byreg$p_cloud, byreg$run, pch = 21, bg = PAL[2], cex = 1.2,
       xlab = "Cloud fraction", ylab = "Mean cloudy run (observations)",
       main = "Run length tracks cloud amount", cex.main = .9)
  graphics::abline(stats::lm(run ~ p_cloud, byreg), lwd = 2, col = PAL[2], lty = 2)
  graphics::legend("topleft", bty = "n", cex = .75,
    legend = sprintf("Spearman %.2f", stats::cor(byreg$run, byreg$p_cloud,
                                                 method = "spearman")))
  plot(byreg$p_cloud, byreg$tau, pch = 21, bg = PAL[1], cex = 1.2,
       xlab = "Cloud fraction", ylab = "Decorrelation time (days)",
       main = "Persistence does not", cex.main = .9)
  graphics::legend("topright", bty = "n", cex = .75,
    legend = sprintf("Spearman %.2f", stats::cor(byreg$tau, byreg$p_cloud,
                                                 method = "spearman")))
})

# --- F4: cross-sensor -------------------------------------------------------
if (!is.null(r4) && nrow(r4)) {
  figure("F4_cross_sensor", 7.0, 3.6, function() {
    graphics::par(mfrow = c(1, 2), mar = c(4.2, 4.3, 1.6, .6), mgp = c(2.5, .7, 0),
                  bty = "l", las = 1, cex.axis = .85)
    plot(r4$landsat_cloud, r4$sentinel_cloud, pch = 16, cex = .5,
         col = grDevices::adjustcolor(PAL[1], .3), xlim = c(0, 1), ylim = c(0, 1),
         xlab = "Landsat cloud fraction (CFMask)",
         ylab = "Sentinel-2 cloud fraction (Sen2Cor)",
         main = "Same cells, same years", cex.main = .95)
    graphics::abline(0, 1, lty = 2, col = "grey40")
    graphics::abline(stats::lm(sentinel_cloud ~ landsat_cloud, r4), lwd = 2.2, col = PAL[2])
    graphics::legend("topleft", bty = "n", cex = .75,
      legend = c(sprintf("r = %.3f", stats::cor(r4$landsat_cloud, r4$sentinel_cloud)),
                 sprintf("n = %d", nrow(r4))))
    h <- graphics::hist(r4$difference, breaks = 40, plot = FALSE)
    graphics::plot(h, col = grDevices::adjustcolor(PAL[3], .7), border = "white",
                   xlab = "Sentinel-2 minus Landsat cloud fraction",
                   main = "Systematic offset", cex.main = .95, ylab = "Cell-years")
    graphics::abline(v = 0, lty = 2, col = "grey40")
    graphics::abline(v = mean(r4$difference), lwd = 2.2, col = PAL[2])
    graphics::legend("topright", bty = "n", cex = .75,
      legend = sprintf("mean %+.3f", mean(r4$difference)))
  })
}

# --- F5: phenological feasibility -------------------------------------------
if (!is.null(r6) && nrow(r6)) {
  figure("F5_phenology", 7.0, 3.6, function() {
    graphics::par(mfrow = c(1, 2), mar = c(4.2, 4.3, 1.6, .6), mgp = c(2.5, .7, 0),
                  bty = "l", las = 1, cex.axis = .85)
    plot(r6$n_usable_median, r6$sos_mae, pch = 16, cex = .6,
         col = grDevices::adjustcolor(PAL[1], .4),
         xlab = "Usable observations per year", ylab = "SOS error (days)",
         main = "Retrieval error", cex.main = .95)
    plot(r6$n_usable_median, r6$failure_rate, pch = 16, cex = .6,
         col = grDevices::adjustcolor(PAL[2], .4),
         xlab = "Usable observations per year", ylab = "Fit failure rate",
         main = "Retrieval failure", cex.main = .95)
  })
}

# --- F6: best acquisition window --------------------------------------------
if (!is.null(r5) && nrow(r5)) {
  r5c <- r5[isTRUE(r5$converged) | r5$converged %in% c(TRUE, "TRUE"), , drop = FALSE]
  if (nrow(r5c)) figure("F6_seasonality", 6.6, 4.2, function() {
    base_par()
    plot(r5c$lat, r5c$peak_doy, pch = 16, cex = .7,
         col = grDevices::adjustcolor(PAL[1], .5), ylim = c(1, 365),
         xlab = "Latitude (degrees)", ylab = "Day of year of clearest conditions")
    graphics::abline(h = c(80, 172, 264, 355), lty = 3, col = "grey70")
    graphics::axis(4, at = c(80, 172, 264, 355), labels = c("Mar", "Jun", "Sep", "Dec"),
                   las = 1, cex.axis = .75, tick = FALSE)
  })
}

# --- F7: measured against nominal density -----------------------------------
if (!is.null(r7) && nrow(r7)) {
  figure("F7_measured_vs_nominal", 6.2, 4.0, function() {
    base_par()
    yr <- as.integer(r7$period)
    plot(yr, r7$measured_obs_per_cell, type = "b", pch = 19, lwd = 2.2, col = PAL[1],
         ylim = c(0, max(c(r7$measured_obs_per_cell, r7$combined_obs), na.rm = TRUE) * 1.1),
         xlab = "Year", ylab = "Observations per cell per year")
    graphics::lines(yr, r7$combined_obs, type = "b", pch = 17, lwd = 2.2, col = PAL[2], lty = 2)
    graphics::lines(yr, r7$measured_clear_per_cell, type = "b", pch = 15, lwd = 2.2, col = PAL[3])
    graphics::legend("bottomleft", bty = "n", cex = .8,
      legend = c("Measured acquisitions", "Nominal (constellation model)", "Measured clear"),
      col = PAL[c(1, 2, 3)], lwd = 2.2, pch = c(19, 17, 15), lty = c(1, 2, 1))
  })
}

# --- D1: feasibility crossover ----------------------------------------------
d1  <- rd("D1_feasibility_by_year"); cross <- rd("D1_crossover_year")
if (!is.null(d1) && nrow(d1)) {
  d1 <- fixup(d1)
  fy <- do.call(rbind, lapply(split(d1, d1$year), function(d) data.frame(
    year = d$year[1], n = nrow(d),
    usable = stats::median(d$n_usable_median, na.rm = TRUE),
    sos_err = stats::median(d$sos_mae, na.rm = TRUE),
    fail = mean(d$failure_rate, na.rm = TRUE),
    p_feasible = mean(d$feasible, na.rm = TRUE), stringsAsFactors = FALSE)))
  figure("F8_feasibility_crossover", 7.2, 3.6, function() {
    graphics::par(mfrow = c(1, 2), mar = c(4.2, 4.4, 1.6, .6), mgp = c(2.6, .7, 0),
                  bty = "l", las = 1, cex.axis = .85)
    plot(fy$year, fy$usable, type = "b", pch = 19, lwd = 2.2, col = PAL[1],
         xlab = "Year", ylab = "Usable observations per year",
         main = "Constellation growth", cex.main = .95, ylim = c(0, max(fy$usable)))
    plot(fy$year, 100 * fy$p_feasible, type = "b", pch = 19, lwd = 2.2, col = PAL[3],
         xlab = "Year", ylab = "Cells where phenology is retrievable (%)",
         main = "Feasibility", cex.main = .95, ylim = c(0, 100))
  })
  wtab(fy, "T6_feasibility_by_year")
  if (!is.null(cross) && nrow(cross)) {
    cross <- fixup(cross)
    tc <- do.call(rbind, lapply(split(cross, cross$regime), function(d) data.frame(
      regime = d$regime[1], n = nrow(d),
      median_crossover = stats::median(d$crossover_year, na.rm = TRUE),
      never = sum(is.na(d$crossover_year)), stringsAsFactors = FALSE)))
    wtab(tc[order(tc$median_crossover), ], "T7_crossover_by_regime")
  }
}

# --- D2: structure of the cross-sensor offset -------------------------------
d2b <- rd("D2_offset_by_cloud_amount")
if (!is.null(d2b) && nrow(d2b) > 2) {
  figure("F9_offset_structure", 6.4, 4.0, function() {
    base_par()
    plot(d2b$mid, d2b$mean_difference, type = "n",
         ylim = range(c(d2b$lo, d2b$hi, 0)), xlab = "Mean cloud fraction",
         ylab = "Sentinel-2 minus Landsat")
    graphics::abline(h = 0, lty = 2, col = "grey50")
    graphics::arrows(d2b$mid, d2b$lo, d2b$mid, d2b$hi, angle = 90, code = 3,
                     length = .03, col = PAL[1], lwd = 1.6)
    graphics::points(d2b$mid, d2b$mean_difference, pch = 21, bg = PAL[1], cex = 1.2)
    graphics::title("The offset is not constant", cex.main = .95)
  })
}

# --- D3: reported cloud drift, Landsat as control ---------------------------
d3 <- rd("D3_reported_cloud_by_year")
if (!is.null(d3) && nrow(d3) > 4) {
  figure("F10_reported_cloud_drift", 6.6, 4.0, function() {
    base_par()
    sn <- unique(d3$sensor)
    yl <- range(c(d3$mean_cloud - 2 * d3$se, d3$mean_cloud + 2 * d3$se), na.rm = TRUE)
    plot(NA, xlim = range(d3$year), ylim = yl, xlab = "Year",
         ylab = "Mean reported cloud fraction")
    for (i in seq_along(sn)) {
      d <- d3[d3$sensor == sn[i] & d3$n > 500, ]
      d <- d[order(d$year), ]
      graphics::arrows(d$year, d$mean_cloud - 2 * d$se, d$year,
                       d$mean_cloud + 2 * d$se, angle = 90, code = 3,
                       length = .02, col = PAL[i])
      graphics::lines(d$year, d$mean_cloud, type = "b", pch = 15 + i, lwd = 2.2,
                      col = PAL[i])
    }
    graphics::legend("topleft", bty = "n", cex = .8, legend = sn,
                     col = PAL[seq_along(sn)], lwd = 2.2, pch = 16:17)
    graphics::title("Same cells, two processing chains", cex.main = .95)
  })
  wtab(d3, "T8_reported_cloud_by_year")
}

# --- D5: seasonal blind spots -----------------------------------------------
d5  <- rd("D5_usability_by_month"); d5s <- rd("D5_blind_spots")
if (!is.null(d5) && nrow(d5)) {
  d5 <- fixup(d5)
  byreg5 <- do.call(rbind, lapply(split(d5, list(d5$regime, d5$month), drop = TRUE),
    function(d) data.frame(regime = d$regime[1], month = d$month[1],
                           p = stats::weighted.mean(d$p_usable, d$n),
                           stringsAsFactors = FALSE)))
  regs <- unique(byreg5$regime)
  figure("F11_seasonal_blind_spots", 7.6, 5.0, function() {
    graphics::par(mar = c(4.0, 8.6, 2.0, 3.0), mgp = c(2.4, .6, 0), las = 1,
                  cex.axis = .78)
    ord <- names(sort(tapply(byreg5$p, byreg5$regime, min)))
    M <- matrix(NA_real_, length(ord), 12,
                dimnames = list(ord, month.abb))
    for (i in seq_len(nrow(byreg5)))
      M[byreg5$regime[i], byreg5$month[i]] <- byreg5$p[i]
    cols <- grDevices::hcl.colors(64, "YlGnBu", rev = TRUE)
    graphics::image(1:12, seq_along(ord), t(M), col = cols, axes = FALSE,
                    xlab = "", ylab = "", zlim = c(0, max(M, na.rm = TRUE)))
    graphics::axis(1, 1:12, month.abb, tick = FALSE, cex.axis = .75)
    graphics::axis(2, seq_along(ord), ord, tick = FALSE, cex.axis = .72)
    graphics::box(col = "grey70")
    graphics::title("Probability an acquisition is usable, by month",
                    cex.main = .98)
    # mark cells below the blind-spot threshold
    for (i in seq_len(nrow(M))) for (j in 1:12)
      if (!is.na(M[i, j]) && M[i, j] < 0.15)
        graphics::points(j, i, pch = 4, cex = .6, col = "white", lwd = 1.4)
    graphics::mtext("x  below 0.15", side = 4, line = .6, cex = .7, las = 0)
  })
  wtab(byreg5[order(byreg5$regime, byreg5$month), ], "T9_usability_by_month")
}
if (!is.null(d5s) && nrow(d5s)) {
  d5s <- fixup(d5s)
  # Recompute with a 1 percent floor: an unfloored ratio divides by sampling
  # noise where a month is almost never usable.
  d5s$seasonal_ratio <- d5s$best_p / pmax(d5s$worst_p, 0.01)
  figure("F12_blind_spot_vs_annual", 6.6, 4.2, function() {
    base_par()
    plot(d5s$annual_p_usable, d5s$seasonal_ratio, log = "y", pch = 21,
         bg = grDevices::adjustcolor(PAL[1], .5), cex = .9,
         xlab = "Annual probability an acquisition is usable",
         ylab = "Seasonal ratio, best month : worst month")
    graphics::abline(h = 2, lty = 3, col = "grey60")
    graphics::legend("topright", bty = "n", cex = .78,
      legend = sprintf("Spearman %.2f",
        stats::cor(d5s$annual_p_usable, log(d5s$seasonal_ratio),
                   method = "spearman")))
    graphics::title("An annual figure does not predict when the gap falls",
                    cex.main = .95)
  })
  t10 <- do.call(rbind, lapply(split(d5s, d5s$regime), function(d) data.frame(
    regime = d$regime[1], n = nrow(d),
    annual_usable = round(stats::median(d$annual_p_usable), 3),
    worst_month = round(stats::median(d$worst_month)),
    worst_p = round(stats::median(d$worst_p), 3),
    seasonal_ratio = round(stats::median(d$seasonal_ratio), 1),
    blind_months = round(stats::median(d$blind_months), 1),
    stringsAsFactors = FALSE)))
  wtab(t10[order(-t10$blind_months, -t10$seasonal_ratio), ], "T10_blind_spots")
}

# --- D6: shape dependence ----------------------------------------------------
d6 <- rd("D6_shape_dependence")
if (!is.null(d6) && nrow(d6) > 3) {
  figure("F13_shape_dependence", 6.6, 4.2, function() {
    base_par()
    plot(d6$peak_parametric, d6$peak_spline, pch = 21,
         bg = grDevices::adjustcolor(PAL[3], .5), cex = .9,
         xlab = "Peak day, parametric double logistic",
         ylab = "Peak day, spline")
    graphics::abline(0, 1, lty = 2, col = "grey40")
    graphics::title("Where the two disagree, the answer is the model's",
                    cex.main = .95)
  })
  wtab(d6, "T11_shape_dependence")
}

# =============================================================================
# TABLES
# =============================================================================
wtab(byreg[order(-byreg$tau), ], "T1_persistence_by_regime")

lat_band <- cut(r1$lat, breaks = seq(-60, 90, by = 15))
t2 <- do.call(rbind, lapply(split(r1, list(lat_band, r1$sensor), drop = TRUE), function(d)
  data.frame(lat_band = as.character(cut(d$lat, breaks = seq(-60, 90, by = 15))[1]),
             sensor = d$sensor[1], n_cell_years = nrow(d),
             acquisitions = round(mean(d$n_scenes), 1),
             clear = round(mean(d$n_clear_obs), 1),
             cloud_fraction = round(mean(d$cloud_fraction), 3),
             stringsAsFactors = FALSE)))
wtab(t2[order(t2$sensor, t2$lat_band), ], "T2_availability_by_latitude")

t3 <- do.call(rbind, lapply(split(r2, r2$regime), function(d) data.frame(
  regime = d$regime[1], n = nrow(d),
  clear_obs = round(stats::median(d$n_clear_obs), 1),
  median_max_gap = round(stats::median(d$max_gap_days), 1),
  p90_max_gap = round(stats::quantile(d$max_gap_days, .9, names = FALSE), 1),
  stringsAsFactors = FALSE)))
wtab(t3[order(-t3$median_max_gap), ], "T3_gaps_by_regime")

if (!is.null(r4)) {
  tt <- stats::t.test(r4$difference)
  wtab(data.frame(
    comparison = "Sentinel-2 (Sen2Cor) minus Landsat (CFMask)",
    n_cell_years = nrow(r4), mean_difference = round(mean(r4$difference), 4),
    ci_low = round(tt$conf.int[1], 4), ci_high = round(tt$conf.int[2], 4),
    correlation = round(stats::cor(r4$landsat_cloud, r4$sentinel_cloud), 4),
    p_value = format.pval(tt$p.value), stringsAsFactors = FALSE),
    "T4_cross_sensor")
}

if (!is.null(r6)) {
  t5 <- do.call(rbind, lapply(split(r6, r6$regime), function(d) data.frame(
    regime = d$regime[1], n = nrow(d),
    usable_obs = round(stats::median(d$n_usable_median), 1),
    sos_error_days = round(stats::median(d$sos_mae, na.rm = TRUE), 2),
    sos_iqr_days = round(stats::median(d$sos_iqr, na.rm = TRUE), 2),
    failure_rate = round(mean(d$failure_rate, na.rm = TRUE), 4),
    stringsAsFactors = FALSE)))
  wtab(t5[order(-t5$sos_error_days), ], "T5_phenology_by_regime")
}

wtab(sites[, intersect(c("site_id","name","lon","lat","regime","n_cells"),
                       names(sites))], "TS1_sites")

# =============================================================================
writeLines(QC, file.path(OUT, "QC-REPORT.txt"))
say("")
rule()
say("DONE. %d figures, %d tables.",
    length(list.files(file.path(OUT, "figures"), pattern = "\\.pdf$")),
    length(list.files(file.path(OUT, "tables"), pattern = "\\.csv$")))
say("")
say("Send me the PNG files in:")
say("   %s", normalizePath(file.path(OUT, "figures"), mustWork = FALSE))
say("and QC-REPORT.txt from the folder above it.")
rule()
