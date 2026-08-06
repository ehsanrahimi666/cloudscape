#!/usr/bin/env Rscript
# =============================================================================
#  cloudscape — STUDY AREA MAPS
#
#  Three panels the manuscript needs and does not yet have:
#    A  where the study area is, on a map of Korea
#    B  the equal-area analysis cells, with the real sensor footprints that
#       cover them, which is the whole argument for not using footprints as
#       the unit of analysis
#    C  the global distribution of sites, if a harvest has been run
#
#  RUN:
#      OUTDIR <- "D:/sdm/new papers/idea/cloudscape/out"
#      source("C:/Users/USER/Downloads/study-area-map.R")
#
#  Optional:
#      SITE    <- list(name = "Andong", lon = 128.73, lat = 36.57)
#      RESULTS <- "D:/sdm/new papers/idea/cloudscape/out/deep"   # for panel C
#
#  Needs the 'maps' package for coastlines. If it is missing the script says
#  so and draws the cells and footprints without a coastline rather than
#  failing.
# =============================================================================

suppressPackageStartupMessages(library(cloudscape))

if (!exists("OUTDIR")) OUTDIR <- "out"
if (!exists("SITE")) SITE <- list(name = "Andong, Republic of Korea",
                                  lon = 128.73, lat = 36.57)
if (!exists("MAP_MONTH")) MAP_MONTH <- c("2024-06-01", "2024-06-30")

MD <- file.path(OUTDIR, "maps")
dir.create(MD, recursive = TRUE, showWarnings = FALSE)
say <- function(...) cat(sprintf(...), "\n", sep = "")
P <- c("#1b6ca8", "#c0392b", "#16a085", "#e08a1e", "#7b3294")

HAVE_MAPS <- requireNamespace("maps", quietly = TRUE)
if (!HAVE_MAPS) {
  say("NOTE: the 'maps' package is not installed, so coastlines are omitted.")
  say("      install.packages(\"maps\")   then run this again for the full map.")
}

# --- the analysis area, exactly as the harvest defines it --------------------
grid <- cl_grid(res = 25000); SIDE <- 4L
k <- cl_grid_lookup(grid, SITE$lon, SITE$lat)
row <- ((k - 1L) %/% grid$ncol) + 1L
col <- ((k - 1L) %% grid$ncol) + 1L
off <- seq(-(SIDE %/% 2L), by = 1L, length.out = SIDE)
rows <- row + off; cols <- col + off
cells <- as.vector(outer((rows - 1L) * grid$ncol, cols, "+"))
cc <- cl_grid_cells(grid, cells)

# Cell outlines in lon/lat. In a cylindrical equal-area projection x depends
# only on longitude and y only on latitude, so corners unproject exactly.
cell_poly <- function(cell) {
  r <- ((cell - 1L) %/% grid$ncol) + 1L
  cl <- ((cell - 1L) %% grid$ncol) + 1L
  x0 <- grid$xmin + (cl - 1L) * grid$res; x1 <- x0 + grid$res
  y1 <- grid$ymax - (r - 1L) * grid$res;  y0 <- y1 - grid$res
  ll <- cl_unproject(c(x0, x1), c(y0, y1))
  list(lon = c(ll[1, "lon"], ll[2, "lon"], ll[2, "lon"], ll[1, "lon"], ll[1, "lon"]),
       lat = c(ll[1, "lat"], ll[1, "lat"], ll[2, "lat"], ll[2, "lat"], ll[1, "lat"]))
}
polys <- lapply(cells, cell_poly)
AOI <- c(min(vapply(polys, function(p) min(p$lon), 0)),
         min(vapply(polys, function(p) min(p$lat), 0)),
         max(vapply(polys, function(p) max(p$lon), 0)),
         max(vapply(polys, function(p) max(p$lat), 0)))
say("study area: %.3f, %.3f to %.3f, %.3f  (%d cells, %g km2)",
    AOI[1], AOI[2], AOI[3], AOI[4], length(cells),
    length(cells) * (grid$res / 1000)^2)
say("site sits %.0f%% across in longitude, %.0f%% up in latitude",
    100 * (SITE$lon - AOI[1]) / (AOI[3] - AOI[1]),
    100 * (SITE$lat - AOI[2]) / (AOI[4] - AOI[2]))

# --- real sensor footprints over the area -----------------------------------
foot <- list()
if (requireNamespace("httr2", quietly = TRUE)) {
  for (sn in c("landsat-8-9-oli", "sentinel-2-msi")) {
    it <- tryCatch(suppressWarnings(
      cl_search(AOI, sn, MAP_MONTH[1], MAP_MONTH[2], limit = 200)),
      error = function(e) e)
    if (inherits(it, "error")) { say("  ! %s: %s", sn, conditionMessage(it)); next }
    if (!nrow(it)) { say("  %s: no scenes in the window", sn); next }
    g <- attr(it, "geometry")
    keep <- !duplicated(if (sn == "sentinel-2-msi") it$tile
                        else paste(it$path, it$row))
    say("  %s: %d scenes, %d distinct footprints", sn, nrow(it), sum(keep))
    foot[[sn]] <- lapply(g[keep], function(gg) {
      # Polygon nests coordinates one level, MultiPolygon two.
      if (is.null(gg) || is.null(gg$coordinates)) return(NULL)
      ring <- if (identical(gg$type, "MultiPolygon")) gg$coordinates[[1]][[1]]
              else gg$coordinates[[1]]
      m <- do.call(rbind, lapply(ring, function(p) c(p[[1]], p[[2]])))
      storage.mode(m) <- "double"; m
    })
  }
} else say("  httr2 not installed; footprints omitted")

fig <- function(name, w, h, draw) {
  grDevices::pdf(file.path(MD, paste0(name, ".pdf")), width = w, height = h,
                 pointsize = 10)
  draw(); grDevices::dev.off()
  try({ grDevices::png(file.path(MD, paste0(name, ".png")),
                       width = round(w * 150), height = round(h * 150), res = 150)
        draw(); grDevices::dev.off() }, silent = TRUE)
  say("  wrote %s.pdf + .png", name)
}

# =============================================================================
# M1 — two panels: Korea, then the analysis cells with real footprints
# =============================================================================
fig("M1_study_area", 9.0, 4.6, function() {
  graphics::par(mfrow = c(1, 2), mar = c(3.4, 3.4, 2.0, 0.8),
                mgp = c(2.1, 0.6, 0), las = 1, cex.axis = 0.8)

  # --- Panel A: regional context
  plot(NA, xlim = c(124.5, 131.5), ylim = c(33, 39.5), asp = 1/cos(36.5*pi/180),
       xlab = "Longitude", ylab = "Latitude",
       main = "(a) Location", cex.main = 1.0)
  if (HAVE_MAPS) {
    maps::map("world", regions = c("South Korea", "North Korea"), add = TRUE,
              fill = TRUE, col = "grey92", border = "grey55", lwd = .7)
    maps::map("world", add = TRUE, col = "grey70", lwd = .5)
  }
  graphics::rect(AOI[1], AOI[2], AOI[3], AOI[4], border = P[2], lwd = 2.2)
  graphics::points(SITE$lon, SITE$lat, pch = 21, bg = P[2], cex = 1.3)
  graphics::text(SITE$lon, AOI[2], sub(",.*", "", SITE$name), pos = 1,
                 offset = .6, cex = .85, font = 2)
  graphics::box()

  # --- Panel B: the analysis unit, and the footprints it is built from
  pad <- 0.55
  plot(NA, xlim = c(AOI[1] - pad, AOI[3] + pad),
       ylim = c(AOI[2] - pad, AOI[4] + pad), asp = 1/cos(36.5*pi/180),
       xlab = "Longitude", ylab = "Latitude",
       main = "(b) Equal-area cells and sensor footprints", cex.main = 1.0)
  if (HAVE_MAPS) {
    maps::map("world", regions = c("South Korea"), add = TRUE, fill = TRUE,
              col = "grey95", border = "grey60", lwd = .7)
  }
  # Footprints first, underneath
  if (length(foot$`landsat-8-9-oli`)) {
    for (m in foot$`landsat-8-9-oli`) if (!is.null(m))
      graphics::polygon(m[, 1], m[, 2], border = P[4], lwd = 1.6, lty = 1)
  }
  if (length(foot$`sentinel-2-msi`)) {
    for (m in foot$`sentinel-2-msi`) if (!is.null(m))
      graphics::polygon(m[, 1], m[, 2], border = P[5], lwd = 1.4, lty = 2)
  }
  for (p in polys) graphics::polygon(p$lon, p$lat, border = P[1],
                                     col = grDevices::adjustcolor(P[1], .10), lwd = 1.1)
  graphics::points(cc$lon, cc$lat, pch = 3, cex = .5, col = P[1])
  graphics::points(SITE$lon, SITE$lat, pch = 21, bg = P[2], cex = 1.3)
  graphics::legend("topleft", bty = "n", cex = .72, bg = "white",
    legend = c(sprintf("%d equal-area cells (25 km)", length(cells)),
               "Landsat WRS-2 scenes", "Sentinel-2 MGRS tiles", SITE$name),
    col = c(P[1], P[4], P[5], P[2]), lwd = c(1.1, 1.6, 1.4, NA),
    lty = c(1, 1, 2, NA), pch = c(NA, NA, NA, 21), pt.bg = c(NA, NA, NA, P[2]))
})

# =============================================================================
# M2 — why footprints are the wrong unit
#
# The same 16 cells are covered by a handful of Landsat scenes and a different
# handful of Sentinel-2 tiles, of different sizes and in different places. Any
# statistic reported per footprint is reported on a different unit for each
# sensor; reported per cell it is the same unit for both.
# =============================================================================
if (length(foot)) {
  fig("M2_unit_comparison", 8.4, 3.4, function() {
    graphics::par(mfrow = c(1, 3), mar = c(3.2, 3.2, 2.2, .6),
                  mgp = c(2.0, .6, 0), las = 1, cex.axis = .75)
    pad <- 0.7
    frame_ <- function(ttl) {
      plot(NA, xlim = c(AOI[1] - pad, AOI[3] + pad),
           ylim = c(AOI[2] - pad, AOI[4] + pad), asp = 1/cos(36.5*pi/180),
           xlab = "", ylab = "", main = ttl, cex.main = .95)
      if (HAVE_MAPS) maps::map("world", regions = "South Korea", add = TRUE,
                               fill = TRUE, col = "grey95", border = "grey65", lwd = .6)
    }
    frame_("Landsat WRS-2 scenes")
    for (m in foot$`landsat-8-9-oli`) if (!is.null(m))
      graphics::polygon(m[, 1], m[, 2], border = P[4],
                        col = grDevices::adjustcolor(P[4], .12), lwd = 1.6)
    frame_("Sentinel-2 MGRS tiles")
    for (m in foot$`sentinel-2-msi`) if (!is.null(m))
      graphics::polygon(m[, 1], m[, 2], border = P[5],
                        col = grDevices::adjustcolor(P[5], .12), lwd = 1.6)
    frame_("cloudscape analysis cells")
    for (p in polys) graphics::polygon(p$lon, p$lat, border = P[1],
                                       col = grDevices::adjustcolor(P[1], .15), lwd = 1.1)
  })
}

# =============================================================================
# M3 — global site distribution, if a harvest exists
# =============================================================================
sites <- NULL
if (exists("RESULTS") && file.exists(file.path(RESULTS, "sites.csv"))) {
  sites <- utils::read.csv(file.path(RESULTS, "sites.csv"), stringsAsFactors = FALSE)
} else {
  for (cand in c(file.path(OUTDIR, "deep", "sites.csv"),
                 file.path(OUTDIR, "sites.csv"),
                 "cloudscape-results/sites.csv")) {
    if (file.exists(cand)) { sites <- utils::read.csv(cand, stringsAsFactors = FALSE); break }
  }
}
if (!is.null(sites) && nrow(sites)) {
  fig("M3_global_sites", 8.4, 4.4, function() {
    graphics::par(mar = c(3.4, 3.4, 2.0, .8), mgp = c(2.1, .6, 0), las = 1,
                  cex.axis = .8)
    plot(NA, xlim = c(-180, 180), ylim = c(-60, 85), asp = 1,
         xlab = "Longitude", ylab = "Latitude",
         main = sprintf("Sampling design: %d sites, %d equal-area cells",
                        nrow(sites), nrow(sites) * 16), cex.main = 1.0)
    if (HAVE_MAPS) maps::map("world", add = TRUE, fill = TRUE, col = "grey93",
                             border = "grey70", lwd = .4)
    reg <- factor(sites$regime)
    cols <- grDevices::hcl.colors(nlevels(reg), "Dark 3")
    graphics::points(sites$lon, sites$lat, pch = 21, bg = cols[as.integer(reg)],
                     cex = 1.2, lwd = .6)
    graphics::abline(h = 0, lty = 3, col = "grey60")
    graphics::legend("bottomleft", bty = "n", cex = .55, ncol = 2,
                     legend = levels(reg), pt.bg = cols, pch = 21, pt.cex = .9)
  })
  say("  sites: %d, latitudes %.1f to %.1f", nrow(sites),
      min(sites$lat), max(sites$lat))
} else {
  say("  no sites.csv found; panel M3 skipped (run a harvest first)")
}

say("")
say("Done. %d files in %s", length(list.files(MD)),
    normalizePath(MD, mustWork = FALSE))
