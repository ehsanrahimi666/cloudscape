# Usability of the phenology year at three cell sizes. The quality layers read
# on 6.25 km cells are aggregated to 12.5 and 25 km by summing valid and
# cloudy pixels, so every cell size is computed from the same pixels. As in the
# extraction at every cell size, a cell is observed in an overpass when its
# centre lies within the footprint of a scene of that overpass.
source("analysis/config.R")
suppressPackageStartupMessages(library(cloudscape))
area <- study_area(cfg)
fine <- as.data.frame(readRDS(file.path(data_dir, "obs_qa_fine.rds")))
items <- readRDS(file.path(data_dir, "items.rds"))
r0 <- min(cfg$fine_res)
g0 <- cl_grid(res = r0)
# Centres of the fine cells in the grid projection. A fine cell lies in the
# coarse cell that contains its centre; grids of different resolutions share
# the origin but not their first row and column, so parents are located by
# coordinates rather than by row and column numbers.
fc <- cl_grid_cells(g0, unique(fine$cell))
fx <- fc$x[match(fine$cell, fc$cell)]; fy <- fc$y[match(fine$cell, fc$cell)]
# Cells whose centre lies within the footprints of each sensor and date.
rings <- getFromNamespace(".cs_geom_rings", "cloudscape")
covered <- function(g) {
  do.call(rbind, lapply(names(items), function(s) {
    it <- items[[s]]
    k <- which(format(it$datetime, "%Y") == as.character(cfg$pheno_year))
    geo <- attr(it, "geometry")[k]
    do.call(rbind, lapply(seq_along(k), function(j) {
      cc <- unique(unlist(lapply(rings(geo[[j]]), function(m) cl_grid_index(m, g, method = "centroid")$cell)))
      if (!length(cc)) return(NULL)
      data.frame(key = paste(cc, s, as.Date(it$datetime[k[j]]), sep = "\r"))
    }))
  }))$key
}
# The valid share of a parent is the mean over its k^2 children: a child
# without a record in an overpass contributes no valid pixels.
aggregate_to <- function(res) {
  k <- res / r0
  g <- cl_grid(res = res)
  parent <- (floor((g$ymax - fy) / res)) * g$ncol + floor((fx - g$xmin) / res) + 1
  key <- paste(parent, fine$sensor, fine$date, sep = "\r")
  cloudy <- fine$cloud_fraction * fine$n_valid
  shadow <- fine$shadow_fraction * fine$n_valid
  s <- function(x) as.numeric(tapply(x, key, sum))
  n_valid <- s(fine$n_valid)
  ukey <- sort(unique(key))
  parts <- do.call(rbind, strsplit(ukey, "\r", fixed = TRUE))
  out <- data.frame(cell = as.integer(parts[, 1]), sensor = parts[, 2], date = as.Date(parts[, 3]),
                    res_km = res / 1000, n_valid = n_valid,
                    cloud_fraction = s(cloudy) / n_valid, shadow_fraction = s(shadow) / n_valid,
                    valid_fraction = s(fine$valid_fraction) / k^2)
  out[ukey %in% covered(g), ]
}
obs <- do.call(rbind, lapply(cfg$fine_res, aggregate_to))
n_cells <- tapply(obs$cell, obs$res_km, function(x) length(unique(x)))
stopifnot(setequal(obs$cell[obs$res_km == cfg$grid_res / 1000], area$cells),
          all(n_cells == length(area$cells) * (cfg$grid_res / (1000 * as.numeric(names(n_cells))))^2))
obs$clear_share <- obs$valid_fraction * (1 - obs$cloud_fraction)
obs$usable <- obs$clear_share >= 1 - cfg$threshold - 1e-12
save_csv(obs, "scale_obs")

# Usable observations and longest gap of each cell, with the package
# definitions used at 25 km.
per_cell <- do.call(rbind, lapply(split(obs, obs$res_km), function(d) {
  o <- cl_obs(d$cell, d$date, d$cloud_fraction, sensor = "combined", tier = "qa",
              valid_fraction = d$valid_fraction, percent = FALSE)
  g <- cl_stats_wide(cl_gaps(o, threshold = cfg$threshold, by = "year",
                             critical = cfg$gap_critical, coverage = cfg$coverage))
  u <- cl_stats_wide(cl_clear_obs(o, by = "year", threshold = cfg$threshold,
                                  coverage = cfg$coverage))
  cs <- tapply(d$clear_share, d$cell, sum)
  out <- merge(u[, c("cell", "n_scenes", "n_clear_obs")], g[, c("cell", "max_gap_days")], by = "cell")
  data.frame(res_km = d$res_km[1], cell = out$cell, n_obs = out$n_scenes,
             n_usable = out$n_clear_obs, p_usable = out$n_clear_obs / out$n_scenes,
             clear_per_pixel = as.numeric(cs[as.character(out$cell)]),
             max_gap = out$max_gap_days)
}))
save_csv(per_cell, "scale_cells")
summ <- do.call(rbind, lapply(split(per_cell, per_cell$res_km), function(d)
  data.frame(res_km = d$res_km[1], cells = nrow(d), n_obs = stats::median(d$n_obs),
             n_usable = stats::median(d$n_usable), n_usable_q25 = unname(stats::quantile(d$n_usable, 0.25)),
             n_usable_q75 = unname(stats::quantile(d$n_usable, 0.75)),
             p_usable = sum(d$n_usable) / sum(d$n_obs), clear_per_pixel = stats::median(d$clear_per_pixel),
             max_gap = stats::median(d$max_gap),
             share_obs_mixed = mean(obs$cloud_fraction[obs$res_km == d$res_km[1]] > 0.05 &
                                      obs$cloud_fraction[obs$res_km == d$res_km[1]] < 0.95))))
save_csv(summ, "scale_summary")

# Agreement of the aggregated 25 km values with the archived 25 km extraction.
qa <- as.data.frame(readRDS(file.path(data_dir, "obs_qa.rds")))
qa <- qa[format(qa$date, "%Y") == as.character(cfg$pheno_year) & qa$cell %in% area$cells, ]
a25 <- obs[obs$res_km == cfg$grid_res / 1000, ]
mm <- merge(a25, qa[, c("cell", "sensor", "date", "cloud_fraction", "valid_fraction")],
            by = c("cell", "sensor", "date"), suffixes = c("_agg", "_archived"))
save_csv(data.frame(n_matched = nrow(mm), n_aggregated = nrow(a25), n_archived = nrow(qa),
                    mean_abs_cloud_diff = mean(abs(mm$cloud_fraction_agg - mm$cloud_fraction_archived)),
                    cor_cloud = stats::cor(mm$cloud_fraction_agg, mm$cloud_fraction_archived),
                    mean_abs_valid_diff = mean(abs(mm$valid_fraction_agg - mm$valid_fraction_archived))),
         "scale_check")
message("scale analysis complete")
