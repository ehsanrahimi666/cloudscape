# Figures for the Andong analysis, drawn from the saved outputs. Widths follow
# the two-column format (180 mm) and one-column format (85 mm).
source("analysis/config.R")
suppressPackageStartupMessages({
  library(cloudscape); library(ggplot2); library(patchwork); library(sf)
})
area <- study_area(cfg)
rd <- function(name) utils::read.csv(file.path(out_dir, paste0(name, ".csv")), stringsAsFactors = FALSE)
FONT <- "Liberation Sans"
COL <- list(sensor = c("Sentinel-2" = "#2166ac", "Landsat 8/9" = "#e08214"),
            tier = c("Scene metadata" = "#8073ac", "Quality layer" = "#35978f"),
            est = c("Median-interval conversion" = "#969696", "Lag-aware fit" = "#3182bd",
                    "Lag-aware, deseasonalised" = "#e6550d"),
            metric = c("Start of season" = "#1a9850", "Peak" = "#f1a340", "End of season" = "#d73027"))
sensor_label <- function(x) ifelse(x == "sentinel-2-msi", "Sentinel-2", "Landsat 8/9")
theme_cs <- function(base = 8) theme_minimal(base_size = base, base_family = FONT) +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(colour = "grey92", linewidth = 0.25),
        axis.line = element_line(colour = "grey35", linewidth = 0.3), axis.ticks = element_line(colour = "grey35", linewidth = 0.3),
        plot.title = element_text(face = "bold", size = base + 1, hjust = 0),
        plot.subtitle = element_text(colour = "grey40", size = base - 0.5),
        legend.key.size = unit(3, "mm"), legend.position = "bottom", legend.title = element_text(size = base - 0.5),
        plot.background = element_rect(fill = "white", colour = NA), panel.background = element_rect(fill = "white", colour = NA))
save_fig <- function(p, name, width, height) {
  ggsave(file.path(fig_dir, paste0(name, ".png")), p, width = width, height = height, units = "mm", dpi = 600, bg = "white")
  ggsave(file.path(fig_dir, paste0(name, ".tif")), p, width = width, height = height, units = "mm", dpi = 600,
         bg = "white", compression = "lzw")
  if (name %in% readme_figures)
    ggsave(file.path("man", "figures", paste0("readme-", sub("^fig_", "", name), ".png")), p,
           width = width, height = height, units = "mm", dpi = 160, bg = "white")
}
readme_figures <- c("fig_workflow", "fig_study_area", "fig_scene_example", "fig_timeline", "fig_scene_vs_cell",
                    "fig_cell_maps", "fig_seasonality", "fig_phenology")
dir.create(file.path("man", "figures"), showWarnings = FALSE, recursive = TRUE)
tag <- function(p, letter, title, subtitle = NULL) p + labs(title = sprintf("(%s) %s", letter, title), subtitle = subtitle)

# Cell polygons in the grid's equal-area projection.
cc <- cl_grid_cells(area$grid, area$cells)
h <- area$grid$res / 2
cell_sf <- st_sf(cell = cc$cell, geometry = st_sfc(lapply(seq_len(nrow(cc)), function(i)
  st_polygon(list(cbind(cc$x[i] + c(-h, h, h, -h, -h), cc$y[i] + c(-h, -h, h, h, -h))))), crs = 6933))
map_theme <- theme_cs() + theme(axis.line = element_blank(), panel.grid.major = element_line(colour = "grey88", linewidth = 0.2),
                                axis.title = element_blank(), legend.key.width = unit(7, "mm"), legend.key.height = unit(2, "mm"))
lon_breaks <- scale_x_continuous(breaks = c(128.2, 128.6, 129.0))
cell_map <- function(df, value, fill_scale, title, letter, subtitle = NULL) {
  g <- merge(cell_sf, df, by = "cell")
  tag(ggplot(g) + geom_sf(aes(fill = .data[[value]]), colour = "white", linewidth = 0.4) +
        geom_sf_label(aes(label = round(.data[[value]])), size = 2.3, family = FONT, colour = "grey10",
                      fill = scales::alpha("white", 0.75), linewidth = 0, label.padding = unit(0.4, "mm")) +
        fill_scale + lon_breaks + coord_sf(crs = 6933, datum = 4326) + map_theme +
        ggspatial::annotation_scale(location = "bl", height = unit(1.2, "mm"), text_cex = 0.55, text_family = FONT,
                                    style = "ticks"), letter, title, subtitle)
}

# ---- Figure: workflow ------------------------------------------------------
box <- function(x, y, w, hh, title, lines, fill) list(
  annotate("rect", xmin = x, xmax = x + w, ymin = y, ymax = y + hh, fill = fill, colour = "grey45", linewidth = 0.25),
  annotate("text", x = x + 0.08, y = y + hh - 0.16, label = title, hjust = 0, vjust = 1, fontface = "bold", size = 2.7, family = FONT),
  annotate("text", x = x + 0.08, y = y + hh - 0.48, label = paste(lines, collapse = "\n"), hjust = 0, vjust = 1,
           size = 2.25, family = FONT, lineheight = 0.95, colour = "grey15"))
arrow_ <- function(x1, y1, x2, y2) annotate("segment", x = x1, y = y1, xend = x2, yend = y2, colour = "grey30", linewidth = 0.35,
                                            arrow = grid::arrow(length = unit(1.4, "mm"), type = "closed"))
pal <- c(unit = "#deebf7", acq = "#e5f5e0", tier = "#fee6ce", use = "#efedf5", dec = "#fde0dd", exp = "#f0f0f0")
wf <- ggplot() + xlim(0, 12.6) + ylim(0.3, 5.1) + theme_void() +
  box(0.1, 2.8, 2.3, 2.2, "1 Define the unit", c("cl_grid()", "25 km equal-area cells", "(EASE-Grid 2.0)"), pal["unit"]) +
  box(2.8, 2.8, 2.3, 2.2, "2 Find what exists", c("cl_search()", "STAC, no account", "latest version only"), pal["acq"]) +
  box(5.5, 3.95, 2.6, 1.05, "3a Scene metadata tier", c("cl_items_to_obs()"), pal["tier"]) +
  box(5.5, 2.8, 2.6, 1.05, "3b Quality-layer tier", c("cl_qa_obs(): SCL, QA_PIXEL"), pal["tier"]) +
  box(8.5, 2.8, 2.0, 2.2, "4 Judge usability", c("cl_clear_obs()", "cl_gaps()", "cl_seasonality()", "cl_persistence()"), pal["use"]) +
  box(10.8, 2.8, 1.7, 2.2, "5 Decide", c("cl_pheno_power()", "cl_pheno_map()", "cl_feasibility()", "cl_synergy()"), pal["dec"]) +
  box(2.8, 0.45, 4.1, 1.45, "Pixel-level detection (experimental)", c("cl_probability(), cl_shadow()", "cl_qa_decode(), cl_terrain_shadow()", "learned methods registered, not implemented"), pal["exp"]) +
  box(7.3, 0.45, 3.2, 1.45, "Benchmark and test", c("cl_simulate(), cl_validate()", "cl_compare(), cl_calibration()"), pal["exp"]) +
  box(10.8, 0.45, 1.7, 1.45, "Share", c("cl_explore()", "cl_export()"), pal["exp"]) +
  arrow_(2.4, 3.9, 2.8, 3.9) + arrow_(5.1, 4.3, 5.5, 4.45) + arrow_(5.1, 3.5, 5.5, 3.3) +
  arrow_(8.1, 4.45, 8.5, 4.2) + arrow_(8.1, 3.3, 8.5, 3.6) + arrow_(10.5, 3.9, 10.8, 3.9) +
  arrow_(3.95, 2.8, 3.95, 1.9) + arrow_(7.3, 1.17, 6.9, 1.17) + arrow_(11.65, 2.8, 11.65, 1.9)
save_fig(wf, "fig_workflow", 180, 66)

# ---- Figure: study area ------------------------------------------------------
items <- readRDS(file.path(data_dir, "items.rds"))
ring_sf <- function(it, i) {
  r <- getFromNamespace(".cs_geom_rings", "cloudscape")(attr(it, "geometry")[[i]])
  st_sfc(st_polygon(list(r[[1]])), crs = 4326)
}
s2 <- items[["sentinel-2-msi"]]; ls_ <- items[["landsat-8-9-oli"]]
fp <- rbind(
  st_sf(kind = "Sentinel-2 MGRS tile", label = s2$tile[!duplicated(s2$tile)],
        geometry = do.call(c, lapply(which(!duplicated(s2$tile)), function(i) ring_sf(s2, i)))),
  st_sf(kind = "Landsat WRS-2 scene", label = sprintf("%03d/%03d", ls_$path, ls_$row)[!duplicated(paste(ls_$path, ls_$row))],
        geometry = do.call(c, lapply(which(!duplicated(paste(ls_$path, ls_$row))), function(i) ring_sf(ls_, i)))))
world <- rnaturalearth::ne_countries(scale = "medium", returnclass = "sf")
box_ll <- st_as_sfc(st_bbox(c(xmin = area$aoi[1], ymin = area$aoi[2], xmax = area$aoi[3], ymax = area$aoi[4]), crs = 4326))
pa <- tag(ggplot() + geom_sf(data = world, fill = "grey90", colour = "grey60", linewidth = 0.2) +
            geom_sf(data = box_ll, fill = NA, colour = "#b2182b", linewidth = 0.6) +
            coord_sf(crs = 6933, datum = 4326, xlim = c(11.9e6, 12.9e6), ylim = c(4.0e6, 4.65e6)) + map_theme,
          "A", "Location", "Andong, Republic of Korea")
pb <- tag(ggplot() + geom_sf(data = st_transform(fp, 6933), aes(colour = kind), fill = NA, linewidth = 0.35) +
            geom_sf(data = cell_sf, aes(fill = "Analysis cell"), alpha = 0.3, colour = "#35978f", linewidth = 0.3) +
            scale_colour_manual(values = c("Sentinel-2 MGRS tile" = "#2166ac", "Landsat WRS-2 scene" = "#e08214"), name = NULL) +
            scale_fill_manual(values = c("Analysis cell" = "#35978f"), name = NULL) +
            coord_sf(crs = 6933, datum = 4326, xlim = area$bounds[c(1, 3)] + c(-9e4, 9e4),
                     ylim = area$bounds[c(2, 4)] + c(-9e4, 9e4)) + map_theme +
            ggspatial::annotation_scale(location = "bl", height = unit(1.2, "mm"), text_cex = 0.55, text_family = FONT, style = "ticks"),
          "B", "Analysis cells and footprints", "Sixteen 25 km equal-area cells; footprints of the scenes that cover them")
save_fig(pa + pb + plot_layout(widths = c(1, 1.35)), "fig_study_area", 180, 92)

# ---- Figure: one overpass, scene cloud cover against cell cloud fractions ----
m <- rd("obs_matched"); m <- m[!is.na(m$cloud_fraction_cell), ]
m$sensor_l <- sensor_label(m$sensor)
sx <- rd("scene_example"); sx_date <- as.Date(sx$date[1])
tci <- terra::rast(file.path(data_dir, "scene_example_tci.tif"))
scl <- terra::rast(file.path(data_dir, "scene_example_scl.tif"))
e <- as.vector(terra::ext(tci))
arr <- terra::as.array(tci) / 255
arr[is.na(arr)] <- 1
lim_x <- e[c("xmin", "xmax")]; lim_y <- e[c("ymin", "ymax")]
grid_lines <- geom_sf(data = cell_sf, fill = NA, colour = "white", linewidth = 0.35)
s1 <- tag(ggplot() + annotation_raster(grDevices::as.raster(arr), e[["xmin"]], e[["xmax"]], e[["ymin"]], e[["ymax"]]) +
            grid_lines + lon_breaks + coord_sf(crs = 6933, datum = 4326, xlim = lim_x, ylim = lim_y, expand = FALSE) + map_theme +
            ggspatial::annotation_scale(location = "bl", height = unit(1.2, "mm"), text_cex = 0.55, text_family = FONT,
                                        style = "ticks", text_col = "white", line_col = "white"),
          "A", "True colour", sprintf("Sentinel-2, %s; white squares: analysis cells", format(sx_date, "%d %B %Y")))
scl_lab <- c("0" = "No data", "1" = "No data", "2" = "Clear", "3" = "Cloud shadow", "4" = "Clear", "5" = "Clear",
             "6" = "Water", "7" = "Clear", "8" = "Cloud", "9" = "Cloud", "10" = "Thin cirrus", "11" = "Snow or ice")
scl_col <- c("Clear" = "#c7e9c0", "Water" = "#6baed6", "Cloud" = "#f7f7f7", "Thin cirrus" = "#bcbddc",
             "Cloud shadow" = "#525252", "Snow or ice" = "#41b6c4", "No data" = "#bdbdbd")
sd_ <- as.data.frame(terra::aggregate(scl, 2, fun = "modal"), xy = TRUE)
names(sd_)[3] <- "code"
sd_$class <- factor(scl_lab[as.character(sd_$code)], levels = names(scl_col))
s2p <- tag(ggplot() + geom_raster(data = sd_, aes(x, y, fill = class)) + grid_lines +
             scale_fill_manual(values = scl_col, drop = TRUE, name = NULL) + lon_breaks +
             coord_sf(crs = 6933, datum = 4326, xlim = lim_x, ylim = lim_y, expand = FALSE) + map_theme +
             theme(legend.position = "right", legend.key = element_rect(colour = "grey60", linewidth = 0.2),
                   legend.key.spacing.y = unit(0.8, "mm")),
           "B", "Scene classification (SCL)", "Producer quality layer, resampled to 200 m for display")
day <- m[as.Date(m$date) == sx_date & m$sensor == "sentinel-2-msi", ]
day$cell_pct <- 100 * day$cloud_fraction_cell; day$scene_pct <- 100 * day$cloud_fraction_scene
s3 <- cell_map(day, "cell_pct", scale_fill_gradient(low = "#f7fcfd", high = "#4d004b", limits = c(0, 100), name = "Cloud (%)"),
               "Cell cloud fraction", "C", sprintf("Scene metadata of the %d tiles: %.0f\u2013%.0f%% cloud",
                                                  nrow(sx), 100 * min(sx$scene_cloud_cover), 100 * max(sx$scene_cloud_cover)))
day <- day[order(day$cell_pct), ]; day$rank <- factor(seq_len(nrow(day)))
dl_ <- rbind(data.frame(rank = day$rank, value = day$scene_pct, tier = "Scene metadata"),
             data.frame(rank = day$rank, value = day$cell_pct, tier = "Quality layer"))
s4 <- tag(ggplot(dl_, aes(value, rank)) +
            annotate("rect", xmin = -Inf, xmax = 100 * cfg$threshold, ymin = -Inf, ymax = Inf, fill = "grey93") +
            geom_line(aes(group = rank), colour = "grey70", linewidth = 0.35) + geom_point(aes(colour = tier), size = 1.6) +
            scale_colour_manual(values = COL$tier, name = NULL) + scale_x_continuous(limits = c(0, 100)) +
            labs(x = "Cloud (%)", y = "Cells, ordered by cell cloud fraction") + theme_cs() +
            theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(), panel.grid.major.y = element_blank()),
          "D", "The same overpass, cell by cell", "Shaded: at most 20% cloud (usable)")
save_fig((s1 | s2p) / (s3 | s4), "fig_scene_example", 180, 165)

# ---- Figure: acquisition record of the median cell ---------------------------
cnt <- table(m$cell)
mc <- as.integer(names(cnt)[which.min(abs(cnt - stats::median(cnt)))])
tl <- m[m$cell == mc, ]; tl$date <- as.Date(tl$date)
tl$screen <- ifelse(tl$screened, "Passes scene screening", "Fails scene screening")
summer <- data.frame(xmin = as.Date(paste0(cfg$years, "-07-01")), xmax = as.Date(paste0(cfg$years, "-08-31")))
t1 <- tag(ggplot(tl, aes(date, cloud_fraction_cell)) +
            geom_rect(data = summer, aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf), inherit.aes = FALSE, fill = "grey92") +
            geom_hline(yintercept = cfg$threshold, linetype = 2, colour = "grey35", linewidth = 0.3) +
            geom_point(aes(colour = sensor_l, shape = screen), size = 1, stroke = 0.35, alpha = 0.9) +
            scale_shape_manual(values = c("Passes scene screening" = 16, "Fails scene screening" = 1), name = NULL) +
            scale_colour_manual(values = COL$sensor, name = NULL) + scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
            labs(x = NULL, y = "Cell cloud fraction") + theme_cs() + guides(colour = guide_legend(override.aes = list(size = 1.6))),
          "A", sprintf("Acquisitions of one cell, %d\u2013%d", min(cfg$years), max(cfg$years)),
          sprintf("Median cell (n = %s); dashed: threshold 0.2; grey: July\u2013August", format(nrow(tl), big.mark = ",")))
cum <- do.call(rbind, lapply(split(tl, tl$year), function(d) {
  d <- d[order(d$date), ]; doy <- as.integer(format(d$date, "%j"))
  rbind(data.frame(year = d$year[1], doy = doy, n = cumsum(d$screened), tier = "Scene metadata"),
        data.frame(year = d$year[1], doy = doy, n = cumsum(d$usable), tier = "Quality layer"))
}))
t2 <- tag(ggplot(cum, aes(doy, n, colour = tier, group = interaction(tier, year))) +
            annotate("rect", xmin = 182, xmax = 243, ymin = -Inf, ymax = Inf, fill = "grey92") +
            geom_step(linewidth = 0.35, alpha = 0.75) + scale_colour_manual(values = COL$tier, name = NULL) +
            scale_x_continuous(breaks = c(1, 91, 182, 274, 365), labels = c("Jan", "Apr", "Jul", "Oct", "Dec")) +
            labs(x = NULL, y = "Cumulative usable acquisitions") + theme_cs(),
          "B", "Accumulation by year", "One line per year and tier")
save_fig(t1 + t2 + plot_layout(widths = c(2, 1)), "fig_timeline", 180, 80)

# ---- Figure: scene metadata against cell quality layers --------------------
ag <- rd("agreement")
rho <- ag$estimate[ag$group == "all" & ag$statistic == "spearman"]
p1 <- tag(ggplot(m, aes(cloud_fraction_scene, cloud_fraction_cell)) +
            geom_hex(bins = 30) + scale_fill_viridis_c(trans = "log10", name = "Cell-observations", option = "mako", direction = -1) +
            geom_abline(slope = 1, intercept = 0, linetype = 2, colour = "grey30", linewidth = 0.3) +
            annotate("rect", xmin = -0.01, xmax = cfg$threshold, ymin = -0.01, ymax = 1.01, fill = NA, colour = "#8073ac", linewidth = 0.3, linetype = 3) +
            labs(x = "Scene cloud cover (metadata)", y = "Cell cloud fraction (quality layer)") +
            coord_equal() + theme_cs() +
            theme(legend.key.width = unit(7, "mm"), legend.key.height = unit(2, "mm"), legend.title.position = "top"),
          "A", "Scene against cell", sprintf("Spearman \u03c1 = %.2f; n = %s", rho, format(nrow(m), big.mark = ",")))
cond <- ag[ag$statistic %in% c("p_usable_given_screened", "p_screened_given_usable") & ag$group %in% c("DJF", "MAM", "JJA", "SON", "all"), ]
cond$group <- factor(cond$group, levels = c("DJF", "MAM", "JJA", "SON", "all"),
                     labels = c("Dec\u2013\nFeb", "Mar\u2013\nMay", "Jun\u2013\nAug", "Sep\u2013\nNov", "All"))
cond$what <- ifelse(cond$statistic == "p_usable_given_screened", "Screened scenes usable at the cell", "Usable cells passing scene screening")
p2 <- tag(ggplot(cond, aes(group, estimate, colour = what)) +
            geom_pointrange(aes(ymin = lower, ymax = upper), position = position_dodge(width = 0.5), size = 0.25, linewidth = 0.4) +
            scale_colour_manual(values = c("#8073ac", "#35978f"), name = NULL) +
            scale_y_continuous(limits = c(0, 1), labels = scales::percent) + labs(x = NULL, y = "Share (95% CI)") +
            theme_cs() + theme(legend.direction = "vertical"),
          "B", "Agreement by season", "Cluster bootstrap over overpasses")
scr <- m[m$cloud_fraction_scene <= cfg$threshold, ]
p3 <- tag(ggplot(scr, aes(cloud_fraction_cell, fill = sensor_l)) +
            geom_histogram(binwidth = 0.05, boundary = 0, colour = "white", linewidth = 0.15) +
            geom_vline(xintercept = cfg$threshold, linetype = 2, colour = "grey30", linewidth = 0.3) +
            scale_fill_manual(values = COL$sensor, name = NULL) +
            labs(x = "Cell cloud fraction", y = "Cell-observations") + theme_cs(),
          "C", "What screening admits", sprintf("Scene-screened only (n = %s)", format(nrow(scr), big.mark = ",")))
save_fig((p1 | p2 | p3) + plot_layout(widths = c(1, 1, 1)), "fig_scene_vs_cell", 180, 84)

# ---- Figure: cell maps -------------------------------------------------------
cy <- rd("counts_cell_year")
med <- stats::aggregate(cbind(n_obs, n_screened, n_usable, clear_per_pixel) ~ cell, cy, stats::median)
g <- rd("gaps_cell_year")
gq <- stats::aggregate(max_gap_days ~ cell, g[g$tier == "qa", ], stats::median)
gm <- stats::aggregate(max_gap_days ~ cell, g[g$tier == "metadata", ], stats::median)
names(gq)[2] <- "gap_qa"; names(gm)[2] <- "gap_meta"
med <- merge(merge(med, gq), gm); med$diff <- med$n_usable - med$n_screened
lim <- range(c(med$n_screened, med$n_usable))
seq_fill <- scale_fill_viridis_c(option = "viridis", limits = lim, name = "Per year")
m1 <- cell_map(med, "n_screened", seq_fill, "Scene-screened acquisitions", "A", "Median per cell-year, 2019\u20132024")
m2 <- cell_map(med, "n_usable", seq_fill, "Cell-usable observations", "B", "Quality layer, cloud fraction at most 0.2")
dl <- max(abs(med$diff))
m3 <- cell_map(med, "diff", scale_fill_distiller(palette = "RdBu", direction = 1, limits = c(-dl, dl), name = "Per year"),
               "Difference (B minus A)", "C", "Median per cell-year")
m4 <- cell_map(med, "gap_qa", scale_fill_viridis_c(option = "rocket", direction = -1, name = "Days"),
               "Longest gap, quality layer", "D", "Median of annual maxima")
save_fig((m1 | m2) / (m3 | m4), "fig_cell_maps", 180, 150)

# ---- Figure: seasonality -----------------------------------------------------
mon <- rd("seasonal_monthly")
ml <- rbind(data.frame(month = mon$month, tier = "Scene metadata", p = mon$p_screened, lo = mon$p_screened_lower, hi = mon$p_screened_upper),
            data.frame(month = mon$month, tier = "Quality layer", p = mon$p_usable, lo = mon$p_usable_lower, hi = mon$p_usable_upper))
sr <- rd("seasonal_ratio")
ps <- tag(ggplot(ml, aes(month, p, colour = tier, fill = tier)) +
            annotate("rect", xmin = 6.5, xmax = 8.5, ymin = -Inf, ymax = Inf, fill = "grey92") +
            geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.18, colour = NA) + geom_line(linewidth = 0.6) + geom_point(size = 1.2) +
            scale_colour_manual(values = COL$tier, name = NULL) + scale_fill_manual(values = COL$tier, name = NULL) +
            scale_x_continuous(breaks = 1:12, labels = month.abb) + scale_y_continuous(labels = scales::percent, limits = c(0, NA)) +
            labs(x = NULL, y = "Usable acquisitions (95% CI)") + theme_cs(),
          "A", "Usable share by month", "Shaded: July\u2013August")
rr <- sr; rr$measure <- ifelse(rr$measure == "screened", "Scene metadata", "Quality layer")
pr <- tag(ggplot(rr, aes(measure, ratio, colour = measure)) + geom_pointrange(aes(ymin = lower, ymax = upper), size = 0.3, linewidth = 0.5) +
            geom_text(aes(label = sprintf("%.1f", ratio)), nudge_x = 0.28, size = 2.6, family = FONT, show.legend = FALSE) +
            scale_colour_manual(values = COL$tier, guide = "none") + geom_hline(yintercept = 1, linetype = 2, colour = "grey50", linewidth = 0.3) +
            labs(x = NULL, y = "Ratio of usable shares (95% CI)") + theme_cs(),
          "B", "Seasonal contrast", "Nov\u2013Feb against Jul\u2013Aug")
save_fig(ps + pr + plot_layout(widths = c(2.4, 1)), "fig_seasonality", 180, 72)

# ---- Figure: persistence -----------------------------------------------------
sim <- rd("persistence_simulation")
sim$estimator <- factor(c(decorrelation_days = "Median-interval conversion", tau_days = "Lag-aware fit",
                          tau_deseasonalised_days = "Lag-aware, deseasonalised")[sim$estimator], levels = names(COL$est))
sim$error <- factor(c(none = "No misclassification", independent = "Independent errors", seasonal = "Seasonal commission")[sim$error],
                    levels = c("No misclassification", "Independent errors", "Seasonal commission"))
pp1 <- tag(ggplot(sim, aes(factor(tau_true), median / tau_true, colour = estimator)) +
             geom_hline(yintercept = 1, linetype = 2, colour = "grey50", linewidth = 0.3) +
             geom_pointrange(aes(ymin = q25 / tau_true, ymax = q75 / tau_true), position = position_dodge(width = 0.55), size = 0.2, linewidth = 0.4) +
             facet_wrap(~error) + scale_colour_manual(values = COL$est, name = NULL) +
             labs(x = "True decorrelation time (days)", y = "Estimate / truth (median, IQR)") + theme_cs(),
           "A", "Recovery under the Andong schedule", "Sentinel-2 acquisition dates and seasonal cloud probability of one cell")
pc <- rd("persistence_cells")
pcl <- do.call(rbind, lapply(c("decorrelation_days", "tau_days", "tau_deseasonalised_days"), function(k)
  data.frame(tier = ifelse(pc$tier == "metadata", "Scene metadata", "Quality layer"), sensor = sensor_label(pc$sensor),
             estimator = c(decorrelation_days = "Median-interval conversion", tau_days = "Lag-aware fit",
                           tau_deseasonalised_days = "Lag-aware, deseasonalised")[[k]], tau = pc[[k]])))
pcl$estimator <- factor(pcl$estimator, levels = names(COL$est))
pp2 <- tag(ggplot(pcl[is.finite(pcl$tau), ], aes(estimator, tau, colour = estimator)) +
             geom_boxplot(outlier.shape = NA, width = 0.55, linewidth = 0.3) +
             geom_jitter(width = 0.12, size = 0.6, alpha = 0.6) + facet_grid(sensor ~ tier) +
             scale_colour_manual(values = COL$est, guide = "none") + scale_x_discrete(labels = c("Median\ninterval", "Lag-aware", "Deseason-\nalised")) +
             labs(x = NULL, y = "Decorrelation time (days)") + theme_cs(),
           "B", "Andong cells", "16 cells; boxes show the median and quartiles")
save_fig(pp1 / pp2 + plot_layout(heights = c(1, 1.15)), "fig_persistence", 180, 150)

# ---- Figure: phenology -------------------------------------------------------
ph <- rd("pheno_cells")
ph$tier <- ifelse(ph$tier == "metadata", "Scene metadata", "Quality layer")
ph$scenario <- factor(ph$scenario, levels = c("Landsat 8 and 9", "Sentinel-2", "Landsat 8 and Sentinel-2", "Landsat 8, 9 and Sentinel-2"))
pl <- do.call(rbind, lapply(c("sos_mae", "peak_mae", "eos_mae"), function(k)
  data.frame(scenario = ph$scenario, tier = ph$tier, metric = c(sos_mae = "Start of season", peak_mae = "Peak", eos_mae = "End of season")[[k]],
             value = ph[[k]])))
pl$metric <- factor(pl$metric, levels = names(COL$metric))
f1 <- tag(ggplot(pl, aes(value, scenario, colour = metric)) +
            stat_summary(fun = stats::median, fun.min = min, fun.max = max, position = position_dodge(width = 0.6), size = 0.2, linewidth = 0.4) +
            facet_wrap(~tier) + scale_colour_manual(values = COL$metric, name = NULL) + scale_x_log10() +
            labs(x = "Median absolute error (days, log scale)", y = NULL) + theme_cs(),
          "A", "Error by constellation, 2024", "Median and range over 16 cells; 200 simulations per cell")
fr <- stats::aggregate(failure_rate ~ scenario + tier, ph, max)
f2 <- tag(ggplot(fr, aes(failure_rate, scenario, fill = tier)) + geom_col(position = position_dodge(width = 0.7), width = 0.65) +
            geom_text(aes(label = scales::percent(failure_rate, accuracy = 0.1)), position = position_dodge(width = 0.7), hjust = -0.15,
                      size = 2.3, family = FONT) +
            scale_fill_manual(values = COL$tier, name = NULL) + scale_x_continuous(labels = scales::percent, expand = expansion(mult = c(0, 0.35))) +
            labs(x = "Failed retrievals", y = NULL) + theme_cs() + theme(axis.text.y = element_blank()),
          "B", "Failure rate", "Highest of the 16 cells")
gp <- rd("pheno_gap_position"); ref <- rd("pheno_reference")
gl <- do.call(rbind, lapply(c("sos_mae", "peak_mae", "eos_mae"), function(k)
  data.frame(centre = gp$gap_centre, metric = c(sos_mae = "Start of season", peak_mae = "Peak", eos_mae = "End of season")[[k]], value = gp[[k]])))
gl$metric <- factor(gl$metric, levels = names(COL$metric))
f3 <- tag(ggplot(gl, aes(centre, value, colour = metric)) +
            geom_vline(xintercept = c(ref$reference_sos, ref$reference_peak, ref$reference_eos), colour = COL$metric, linetype = 3, linewidth = 0.3) +
            geom_line(linewidth = 0.5) + geom_point(size = 0.8) + scale_colour_manual(values = COL$metric, name = NULL) +
            labs(x = "Centre of a 30-day gap (day of year)", y = "Median absolute error (days)") + theme_cs(),
          "C", "Where the gap falls", "Five-day series without cloud; dotted lines: reference dates")
se <- rd("pheno_sensitivity")
se$label <- sprintf("%s = %s", sub("(rho)", "(\u03c1)", se$assumption, fixed = TRUE), se$value)
f4 <- tag(ggplot(se, aes(sos_mae, stats::reorder(label, sos_mae))) + geom_col(fill = COL$metric[["Start of season"]], width = 0.6) +
            geom_text(aes(label = sprintf("%.1f", sos_mae)), hjust = -0.2, size = 2.3, family = FONT) +
            scale_x_continuous(expand = expansion(mult = c(0, 0.2))) + labs(x = "Start-of-season error (days, median cell)", y = NULL) + theme_cs(),
          "D", "Sensitivity to assumptions", "Quality-layer tier, all platforms, 2024")
save_fig((f1 | f2) / (free(f3) | f4) + plot_layout(heights = c(1, 1)), "fig_phenology", 180, 140)

# ---- Figure: centroid against exact overlap ----------------------------------
ov <- rd("overlap_cells"); ov$sensor_l <- sensor_label(ov$sensor)
o1 <- tag(ggplot(ov, aes(area_weighted, n_centroid, colour = sensor_l)) +
            geom_abline(slope = 1, intercept = 0, linetype = 2, colour = "grey40", linewidth = 0.3) + geom_point(size = 1.3, alpha = 0.85) +
            scale_colour_manual(values = COL$sensor, name = NULL) +
            labs(x = "Area-weighted overpass count", y = "Centroid-containment count") + theme_cs(),
          "A", "Counts per cell, 2019\u20132024")
ovw <- stats::aggregate(rel_diff ~ cell, ov[ov$sensor == "landsat-8-9-oli", ], mean); ovw$pct <- 100 * ovw$rel_diff
ovs <- stats::aggregate(rel_diff ~ cell, ov[ov$sensor == "sentinel-2-msi", ], mean); ovs$pct <- 100 * ovs$rel_diff
L <- max(abs(c(ovw$pct, ovs$pct)))
dscale <- scale_fill_distiller(palette = "RdBu", direction = -1, limits = c(-L, L), name = "Percent")
o2 <- cell_map(ovs, "pct", dscale, "Sentinel-2", "B", "Centroid count relative to area-weighted count")
o3 <- cell_map(ovw, "pct", dscale, "Landsat 8/9", "C")
save_fig(o1 + o2 + o3 + plot_layout(widths = c(1, 1, 1)), "fig_overlap", 180, 70)

# ---- Appendix figure: detection consistency test -----------------------------
det <- rd("detection_synthetic"); geo <- rd("detection_geometry")
bg <- list(blue = matrix(0.06, 160, 160), green = matrix(0.08, 160, 160), red = matrix(0.05, 160, 160),
           nir = matrix(0.32, 160, 160), swir16 = matrix(0.20, 160, 160), swir22 = matrix(0.12, 160, 160))
sim1 <- cl_simulate(background = bg, coverage = 0.30, opacity = c(0.3, 1), height = 2500, res = 30,
                    sun_zenith = geo$zenith, sun_azimuth = geo$azimuth, seed = 1)
prb <- cl_probability(sim1$bands, "fmask", sensor = "sentinel-2-msi")
sh1 <- cl_shadow(sim1$cloud, nir = sim1$bands$nir, swir = sim1$bands$swir16, res = 30, sun_zenith = geo$zenith,
                 sun_azimuth = geo$azimuth, heights = seq(500, 6000, by = 100))
rast_df <- function(mat, name) { d <- expand.grid(y = seq_len(nrow(mat)), x = seq_len(ncol(mat))); d$v <- as.vector(mat); d$panel <- name; d }
img <- function(mat, title, letter, scale) tag(ggplot(rast_df(mat, title), aes(x, -y, fill = v)) + geom_raster() + scale +
                                                 coord_equal() + theme_void(base_family = FONT, base_size = 8) +
                                                 theme(legend.position = "bottom", legend.key.height = unit(1.5, "mm"),
                                                       plot.title = element_text(face = "bold", size = 8.5)), letter, title)
sh_cmp <- matrix(c("None", "Detected only", "Simulated only", "Both")[2 * sim1$shadow + sh1$shadow + 1],
                 nrow(sim1$shadow))
a1 <- img(sim1$bands$red, "Red reflectance", "A", scale_fill_gradient(low = "black", high = "white", name = NULL))
a2 <- img(prb$probability, "Cloud probability", "B", scale_fill_viridis_c(option = "mako", name = NULL, limits = c(0, 1)))
a3 <- img(sh_cmp, "Cloud shadow", "C",
          scale_fill_manual(values = c("None" = "white", "Detected only" = "#e08214", "Simulated only" = "#2166ac",
                                       "Both" = "grey25"), name = NULL)) +
  theme(legend.key = element_rect(colour = "grey60", linewidth = 0.2), legend.text = element_text(size = 6.5)) +
  guides(fill = guide_legend(nrow = 2))
dd <- det[, c("seed", "method", "iou")]; dd$method <- ifelse(dd$method == "fmask", "Decision cascade", "Threshold")
a4 <- tag(ggplot(dd, aes(method, iou, colour = method)) + geom_boxplot(outlier.shape = NA, width = 0.5, linewidth = 0.3) +
            geom_jitter(width = 0.1, size = 0.8) + scale_colour_manual(values = c("#35978f", "#969696"), guide = "none") +
            labs(x = NULL, y = "Cloud IoU (20 simulated scenes)") + theme_cs(), "D", "Across scenes")
save_fig(a1 + a2 + a3 + a4 + plot_layout(widths = c(1, 1, 1, 1.1)), "fig_detection_appendix", 180, 62)
message("figures written to ", fig_dir)
