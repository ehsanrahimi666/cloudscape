#!/usr/bin/env Rscript
# =============================================================================
#  cloudscape — GLOBAL CLOUD AND AVAILABILITY MAPS
#
#  Produces the global maps the manuscript needs and the 24-site sample cannot
#  give: cloud density, acquisition density and usable-observation density,
#  mapped worldwide, separately for every sensor, on one equal-area grid.
#
#  This is the analysis that answers the question the 2024 Frontiers paper
#  asked on WRS-2 path/row footprints, but on a unit that is comparable across
#  latitude and across sensors.
#
#  RUN (about 90-150 minutes, resumable):
#      cd D:\sdm\new papers\idea\cloudscape
#      Rscript "C:/Users/USER/Downloads/global-map.R" --years 2023,2024 \
#              --spacing 5 --out "D:/sdm/new papers/idea/cloudscape/out/global"
#
#  Quick look first (about 5 minutes):
#      Rscript "C:/Users/USER/Downloads/global-map.R" --spacing 15 --years 2024 \
#              --out "D:/sdm/new papers/idea/cloudscape/out/global-test"
#
#  Needs the 'maps' package, which supplies the land test:
#      install.packages("maps")
# =============================================================================

suppressPackageStartupMessages(library(cloudscape))
stopifnot(requireNamespace("httr2", quietly = TRUE),
          requireNamespace("maps", quietly = TRUE))

args <- commandArgs(trailingOnly = TRUE)
getarg <- function(n, d) { i <- match(paste0("--", n), args)
  if (is.na(i) || i == length(args)) d else args[i + 1L] }

SPACING <- as.numeric(getarg("spacing", "3"))       # degrees between samples
YEARS   <- as.integer(strsplit(getarg("years", "2024"), ",")[[1]])
OUT     <- getarg("out", "cloudscape-global")
BACKEND <- getarg("backend", "element84")
WINDOWS <- as.integer(getarg("windows", "2"))
# Landsat 7 is excluded by default: its imaging ended in 2024, so including it
# in a single recent year spends a third of the requests to return almost
# nothing. Add it back with --sensors if the target year is earlier.
SENSORS <- strsplit(getarg("sensors",
  "landsat-8-9-oli,sentinel-2-msi"), ",")[[1]]
BOX     <- as.numeric(getarg("box", "0.4"))         # half-width of each sample

dir.create(file.path(OUT, "raw"), recursive = TRUE, showWarnings = FALSE)
msg <- function(...) cat(sprintf(...), "\n", sep = "")
rule <- function() cat(strrep("-", 74), "\n")

GRID <- cl_grid(res = 25000)
cl_options(max_page = 100L, verbose = FALSE)

rule(); msg("cloudscape global maps")
msg("spacing  : %g degrees", SPACING)
msg("years    : %s", paste(YEARS, collapse = ", "))
msg("sensors  : %s", paste(SENSORS, collapse = ", "))
msg("output   : %s", normalizePath(OUT, mustWork = FALSE)); rule()

# --- sample points over land -------------------------------------------------
#
# Ocean points would triple the request count and return almost nothing: the
# archives schedule very few acquisitions there. maps::map.where() returns NA
# over water, which is a sufficient land test at this resolution.
lons <- seq(-180 + SPACING / 2, 180 - SPACING / 2, by = SPACING)
lats <- seq(-56 + SPACING / 2, 82 - SPACING / 2, by = SPACING)
g <- expand.grid(lon = lons, lat = lats)
g$where <- maps::map.where("world", g$lon, g$lat)
pts <- g[!is.na(g$where), c("lon", "lat")]
pts <- pts[!grepl("Antarctica", g$where[!is.na(g$where)]), , drop = FALSE]
pts$pid <- sprintf("P%05d", seq_len(nrow(pts)))
msg("Land sample points: %d (of %d grid nodes)", nrow(pts), nrow(g))
utils::write.csv(pts, file.path(OUT, "points.csv"), row.names = FALSE)

SENSOR_START <- c("landsat-4-7-tm-etm" = 1982L, "landsat-8-9-oli" = 2013L,
                  "sentinel-2-msi" = 2015L)
todo <- expand.grid(pid = pts$pid, sensor = SENSORS, year = YEARS,
                    stringsAsFactors = FALSE)
todo <- todo[todo$year >= SENSOR_START[todo$sensor], , drop = FALSE]
todo$id <- sprintf("%s_%s_%d", todo$pid, gsub("[^A-Za-z0-9]", "", todo$sensor),
                   todo$year)
sfile <- function(id) file.path(OUT, "raw", paste0(id, ".rds"))
done <- file.exists(vapply(todo$id, sfile, character(1)))
msg("Harvest plan: %d point-sensor-years (%d done, %d to fetch)",
    nrow(todo), sum(done), sum(!done))
todo <- todo[!done, , drop = FALSE]

# --- harvest -----------------------------------------------------------------
fetch <- function(p, sn, yr) {
  aoi <- c(p$lon - BOX, p$lat - BOX, p$lon + BOX, p$lat + BOX)
  edges <- seq(as.Date(sprintf("%d-01-01", yr)),
               as.Date(sprintf("%d-12-31", yr)) + 1, length.out = WINDOWS + 1L)
  out <- list()
  for (w in seq_len(WINDOWS)) {
    it <- tryCatch(suppressWarnings(
      cl_search(aoi, sn, edges[w], edges[w + 1L] - 1, limit = Inf)),
      error = function(e) e)
    if (inherits(it, "error")) return(NULL)     # incomplete year, retry later
    if (nrow(it)) out[[length(out) + 1L]] <- as.data.frame(it)
    Sys.sleep(0.15)
  }
  if (!length(out)) {
    return(data.frame(n = 0L, cloud = NA_real_, usable = 0L,
                      stringsAsFactors = FALSE))
  }
  d <- do.call(rbind, out)
  # Collapse tiles of one overpass: several products can cover one point.
  d$slot <- round(as.numeric(as.POSIXct(d$datetime, tz = "UTC")) / 1200)
  a <- stats::aggregate(cloud_cover ~ slot, d, mean)
  data.frame(n = nrow(a), cloud = mean(a$cloud_cover, na.rm = TRUE) / 100,
             usable = sum(a$cloud_cover <= 20, na.rm = TRUE),
             stringsAsFactors = FALSE)
}

if (nrow(todo)) {
  t0 <- Sys.time(); failed <- character()
  for (i in seq_len(nrow(todo))) {
    r <- todo[i, ]
    p <- pts[pts$pid == r$pid, ]
    res <- tryCatch(fetch(p, r$sensor, r$year), error = function(e) NULL)
    if (is.null(res)) { failed <- c(failed, r$id); next }
    res$pid <- r$pid; res$sensor <- r$sensor; res$year <- r$year
    res$lon <- p$lon; res$lat <- p$lat
    saveRDS(res, sfile(r$id), compress = "xz")
    if (i %% 50 == 0 || i == nrow(todo)) {
      el <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
      msg("  [%d/%d] %.0f min elapsed, ~%.0f min left (%d failed)",
          i, nrow(todo), el, el / i * (nrow(todo) - i), length(failed))
    }
  }
  if (length(failed)) {
    msg("%d fetches failed; re-run the same command to retry only those.",
        length(failed))
    writeLines(failed, file.path(OUT, "failed.txt"))
  }
}

# --- assemble ----------------------------------------------------------------
parts <- list.files(file.path(OUT, "raw"), pattern = "\\.rds$", full.names = TRUE)
if (!length(parts)) stop("Nothing harvested.", call. = FALSE)
G <- do.call(rbind, lapply(parts, readRDS))
G$usable_frac <- ifelse(G$n > 0, G$usable / G$n, NA_real_)
utils::write.csv(G, file.path(OUT, "G1_global_by_point_sensor_year.csv"),
                 row.names = FALSE)
rule(); msg("Harvested %d point-sensor-years over %d land points",
            nrow(G), length(unique(G$pid))); rule()

# Per point and sensor, averaged over years
PS <- do.call(rbind, lapply(split(G, list(G$pid, G$sensor), drop = TRUE),
  function(d) data.frame(pid = d$pid[1], sensor = d$sensor[1],
                         lon = d$lon[1], lat = d$lat[1],
                         acquisitions = mean(d$n),
                         cloud = mean(d$cloud, na.rm = TRUE),
                         usable = mean(d$usable),
                         usable_frac = mean(d$usable_frac, na.rm = TRUE),
                         stringsAsFactors = FALSE)))
utils::write.csv(PS, file.path(OUT, "G2_global_by_point_sensor.csv"),
                 row.names = FALSE)

# Combined across sensors
CB <- do.call(rbind, lapply(split(G, G$pid), function(d) {
  data.frame(pid = d$pid[1], lon = d$lon[1], lat = d$lat[1],
             acquisitions = sum(d$n) / length(unique(d$year)),
             usable = sum(d$usable) / length(unique(d$year)),
             cloud = stats::weighted.mean(d$cloud, d$n, na.rm = TRUE),
             stringsAsFactors = FALSE)
}))
utils::write.csv(CB, file.path(OUT, "G3_global_combined.csv"), row.names = FALSE)

# --- maps --------------------------------------------------------------------
fig <- function(name, w, h, draw) {
  grDevices::pdf(file.path(OUT, paste0(name, ".pdf")), width = w, height = h,
                 pointsize = 10)
  draw(); grDevices::dev.off()
  try({ grDevices::png(file.path(OUT, paste0(name, ".png")),
                       width = round(w * 150), height = round(h * 150), res = 150)
        draw(); grDevices::dev.off() }, silent = TRUE)
  msg("  wrote %s.pdf + .png", name)
}
world <- function() {
  maps::map("world", add = TRUE, col = "grey55", lwd = .35, interior = FALSE)
}
ramp <- function(v, lo, hi, pal) {
  t <- pmin(pmax((v - lo) / (hi - lo), 0), 1)
  grDevices::colorRampPalette(pal)(101)[round(t * 100) + 1]
}
panel <- function(d, val, lo, hi, pal, ttl, unit) {
  plot(NA, xlim = c(-180, 180), ylim = c(-58, 84), asp = 1, xlab = "", ylab = "",
       main = ttl, cex.main = .95, xaxt = "n", yaxt = "n")
  graphics::rect(-180, -58, 180, 84, col = "grey97", border = NA)
  world()
  # Draw each sample as a cell of the sampling grid rather than a dot, so the
  # map reads as a continuous surface instead of scattered points.
  h <- SPACING / 2
  graphics::rect(d$lon - h, d$lat - h, d$lon + h, d$lat + h,
                 col = ramp(d[[val]], lo, hi, pal), border = NA)
  world()
  graphics::box(col = "grey60")
  graphics::axis(1, seq(-180, 180, 60), cex.axis = .65, tck = -.015, mgp = c(2, .3, 0))
  graphics::axis(2, seq(-60, 80, 30), cex.axis = .65, tck = -.015, mgp = c(2, .5, 0), las = 1)
  xs <- seq(-175, -95, length.out = 100)
  graphics::rect(xs[-100], -52, xs[-1], -44,
                 col = grDevices::colorRampPalette(pal)(99), border = NA)
  graphics::text(c(-175, -95), -56, sprintf("%.2g", c(lo, hi)), cex = .6)
  graphics::text(-135, -40, unit, cex = .65)
}

BLUE <- c("#f7fbff", "#6baed6", "#08306b")
HEAT <- c("#ffffcc", "#fd8d3c", "#800026")

sn <- unique(PS$sensor)
fig("G_cloud_by_sensor", 8.2, 3.2 * length(sn), function() {
  graphics::par(mfrow = c(length(sn), 1), mar = c(2.4, 2.4, 1.8, .6))
  for (s in sn) panel(PS[PS$sensor == s, ], "cloud", 0, 1, BLUE,
                      sprintf("Mean reported cloud fraction: %s", s),
                      "cloud fraction")
})

fig("G_usable_by_sensor", 8.2, 3.2 * length(sn), function() {
  graphics::par(mfrow = c(length(sn), 1), mar = c(2.4, 2.4, 1.8, .6))
  for (s in sn) {
    d <- PS[PS$sensor == s, ]
    panel(d, "usable", 0, stats::quantile(d$usable, .98, na.rm = TRUE), HEAT,
          sprintf("Usable observations per year: %s", s), "observations")
  }
})

fig("G_combined", 8.2, 6.4, function() {
  graphics::par(mfrow = c(2, 1), mar = c(2.4, 2.4, 1.8, .6))
  panel(CB, "acquisitions", 0, stats::quantile(CB$acquisitions, .98, na.rm = TRUE),
        HEAT, "All sensors combined: acquisitions per year", "acquisitions")
  panel(CB, "usable", 0, stats::quantile(CB$usable, .98, na.rm = TRUE), HEAT,
        "All sensors combined: usable observations per year", "observations")
})

# Difference between the two producers, on identical points
w <- reshape(PS[PS$sensor %in% c("landsat-8-9-oli", "sentinel-2-msi"),
                c("pid", "lon", "lat", "sensor", "cloud")],
             idvar = c("pid", "lon", "lat"), timevar = "sensor",
             direction = "wide")
names(w) <- sub("^cloud\\.", "", names(w))
if (all(c("landsat-8-9-oli", "sentinel-2-msi") %in% names(w))) {
  w$diff <- w$`sentinel-2-msi` - w$`landsat-8-9-oli`
  w <- w[is.finite(w$diff), ]
  utils::write.csv(w, file.path(OUT, "G4_sensor_difference.csv"), row.names = FALSE)
  fig("G_sensor_difference", 8.2, 3.4, function() {
    graphics::par(mar = c(2.4, 2.4, 1.8, .6))
    panel(w, "diff", -0.2, 0.2, c("#2166ac", "#f7f7f7", "#b2182b"),
          "Sentinel-2 (Sen2Cor) minus Landsat (CFMask), same points",
          "difference in cloud fraction")
  })
  msg("  global mean difference: %+.3f (n = %d land points)",
      mean(w$diff, na.rm = TRUE), nrow(w))
}

# --- latitudinal profiles ----------------------------------------------------
band <- function(d, v, w = 5) {
  d$b <- round(d$lat / w) * w
  a <- stats::aggregate(stats::as.formula(paste(v, "~ b")), d, mean, na.rm = TRUE)
  a[order(a$b), ]
}
fig("G_latitude_profiles", 8.0, 3.4, function() {
  graphics::par(mfrow = c(1, 3), mar = c(4.0, 4.2, 1.8, .6), mgp = c(2.4, .7, 0),
                bty = "l", las = 1, cex.axis = .8)
  cols <- c("#1b6ca8", "#c0392b", "#16a085")
  for (j in seq_along(c("cloud", "acquisitions", "usable"))) {
    v <- c("cloud", "acquisitions", "usable")[j]
    ylab <- c("Mean cloud fraction", "Acquisitions per year",
              "Usable observations per year")[j]
    plot(NA, xlim = c(-56, 82),
         ylim = c(0, max(PS[[v]], na.rm = TRUE) * 1.05),
         xlab = "Latitude (degrees)", ylab = ylab, main = "", cex.lab = .95)
    for (i in seq_along(sn)) {
      b <- band(PS[PS$sensor == sn[i], ], v)
      graphics::lines(b$b, b[[v]], lwd = 2.2, col = cols[i])
    }
    if (j == 1) graphics::legend("topleft", bty = "n", cex = .72, legend = sn,
                                 col = cols[seq_along(sn)], lwd = 2.2)
  }
})
utils::write.csv(do.call(rbind, lapply(sn, function(s) {
  d <- PS[PS$sensor == s, ]; b <- band(d, "cloud")
  data.frame(sensor = s, lat_band = b$b, cloud = round(b$cloud, 4),
             acquisitions = round(band(d, "acquisitions")$acquisitions, 1),
             usable = round(band(d, "usable")$usable, 1))
})), file.path(OUT, "G5_latitude_profile.csv"), row.names = FALSE)
msg("  wrote G5_latitude_profile.csv")

rule(); msg("DONE. Maps and CSVs in %s", normalizePath(OUT, mustWork = FALSE)); rule()
