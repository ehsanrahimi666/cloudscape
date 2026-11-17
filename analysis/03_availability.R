# Compares the metadata and quality-layer evidence tiers over the study cells:
# counts of usable observations, agreement at the cell-observation level,
# longest gaps, seasonality, persistence, and the effect of assigning
# footprints to cells by centroid containment.
source("analysis/config.R")
suppressPackageStartupMessages(library(cloudscape))
area <- study_area(cfg)
items <- readRDS(file.path(data_dir, "items.rds"))
qa <- readRDS(file.path(data_dir, "obs_qa.rds"))
thr <- cfg$threshold
season_of <- function(m) ifelse(m %in% c(12, 1, 2), "DJF", ifelse(m %in% 3:5, "MAM",
                         ifelse(m %in% 6:8, "JJA", "SON")))

# ---- observation tables --------------------------------------------------
meta <- bind_obs(lapply(items, function(it) suppressMessages(
  cl_items_to_obs(it, area$grid, overpass_minutes = cfg$overpass_minutes))))
meta <- obs_subset(meta, meta$cell %in% area$cells)
stopifnot(!anyDuplicated(paste(meta$cell, meta$sensor, meta$date)),
          !anyDuplicated(paste(qa$cell, qa$sensor, qa$date)))

m <- merge(as.data.frame(meta)[, c("cell", "sensor", "platform", "date", "cloud_fraction")],
           as.data.frame(qa)[, c("cell", "sensor", "date", "cloud_fraction", "shadow_fraction",
                                 "snow_fraction", "valid_fraction")],
           by = c("cell", "sensor", "date"), all.x = TRUE, suffixes = c("_scene", "_cell"))
m$year <- as.integer(format(m$date, "%Y"))
m$month <- as.integer(format(m$date, "%m"))
m$season <- season_of(m$month)
m$overpass <- paste(m$sensor, m$date)
m$screened <- m$cloud_fraction_scene <= thr
m$usable <- m$cloud_fraction_cell <= thr
m$usable_shadow <- (m$cloud_fraction_cell + m$shadow_fraction) <= thr
save_csv(m, "obs_matched")

cov <- data.frame(n_metadata = nrow(m), n_matched = sum(!is.na(m$cloud_fraction_cell)),
                  n_qa = nrow(qa), n_items = sum(vapply(items, nrow, 1L)))
save_csv(cov, "coverage")
mm <- m[!is.na(m$cloud_fraction_cell), ]

# ---- counts per cell-year -----------------------------------------------
cy <- do.call(rbind, lapply(split(mm, list(mm$cell, mm$year), drop = TRUE), function(d)
  data.frame(cell = d$cell[1], year = d$year[1], n_obs = nrow(d),
             n_obs_s2 = sum(d$sensor == "sentinel-2-msi"),
             n_obs_landsat = sum(d$sensor == "landsat-8-9-oli"),
             n_screened = sum(d$screened), n_usable = sum(d$usable),
             n_usable_shadow = sum(d$usable_shadow),
             clear_per_pixel = sum(1 - d$cloud_fraction_cell),
             mean_scene_cloud = mean(d$cloud_fraction_scene),
             mean_cell_cloud = mean(d$cloud_fraction_cell))))
save_csv(cy, "counts_cell_year")
num <- setdiff(names(cy), c("cell", "year"))
by_year <- do.call(rbind, lapply(split(cy, cy$year), function(d) {
  q <- function(v) sprintf("%s (%s-%s)", format(round(stats::median(v), 2)),
                           format(round(min(v), 2)), format(round(max(v), 2)))
  data.frame(year = d$year[1], cells = nrow(d), total_obs = sum(d$n_obs),
             total_screened = sum(d$n_screened), total_usable = sum(d$n_usable),
             as.list(stats::setNames(vapply(num, function(v) q(d[[v]]), ""), paste0(num, "_median_range"))))
}))
save_csv(by_year, "counts_by_year")

# ---- agreement between scene screening and cell usability ----------------
agree <- function(d) {
  stat <- list(
    agreement = function(x) mean(x$screened == x$usable),
    p_usable_given_screened = function(x) mean(x$usable[x$screened]),
    p_screened_given_usable = function(x) mean(x$screened[x$usable]),
    usable_minus_screened = function(x) mean(x$usable) - mean(x$screened),
    mean_cloud_difference = function(x) mean(x$cloud_fraction_cell - x$cloud_fraction_scene),
    mean_abs_cloud_difference = function(x) mean(abs(x$cloud_fraction_cell - x$cloud_fraction_scene)),
    spearman = function(x) stats::cor(x$cloud_fraction_cell, x$cloud_fraction_scene, method = "spearman"))
  do.call(rbind, lapply(names(stat), function(k) {
    ci <- cluster_ci(d, d$overpass, stat[[k]])
    data.frame(statistic = k, estimate = ci[["estimate"]], lower = ci[["lower"]],
               upper = ci[["upper"]], n_obs = nrow(d), n_overpasses = length(unique(d$overpass)))
  }))
}
groups <- c(list(all = mm), split(mm, mm$sensor), split(mm, mm$season))
ag <- do.call(rbind, lapply(names(groups), function(g) cbind(group = g, agree(groups[[g]]))))
save_csv(ag, "agreement")
save_csv(as.data.frame(table(screened = mm$screened, usable = mm$usable)), "agreement_table")

# ---- longest gaps, both sensors combined --------------------------------
combined <- function(o) { o$sensor <- "combined"; o }
qa_cells <- obs_subset(qa, qa$cell %in% area$cells)
gap_tab <- do.call(rbind, lapply(c("metadata", "qa"), function(t) {
  o <- combined(if (t == "metadata") meta else qa_cells)
  g <- cl_stats_wide(cl_gaps(o, threshold = thr, by = "year", critical = cfg$gap_critical))
  g$tier <- t
  g
}))
save_csv(gap_tab, "gaps_cell_year")

# ---- seasonality ---------------------------------------------------------
mon <- do.call(rbind, lapply(split(mm, mm$month), function(d) {
  s <- cluster_ci(d, d$overpass, function(x) mean(x$screened))
  u <- cluster_ci(d, d$overpass, function(x) mean(x$usable))
  data.frame(month = d$month[1], n_obs = nrow(d), n_overpasses = length(unique(d$overpass)),
             p_screened = s[["estimate"]], p_screened_lower = s[["lower"]], p_screened_upper = s[["upper"]],
             p_usable = u[["estimate"]], p_usable_lower = u[["lower"]], p_usable_upper = u[["upper"]],
             p_usable_shadow = mean(d$usable_shadow),
             mean_scene_cloud = mean(d$cloud_fraction_scene),
             mean_cell_cloud = mean(d$cloud_fraction_cell))
}))
save_csv(mon, "seasonal_monthly")
period <- function(d, months) d[d$month %in% months, ]
ratio <- do.call(rbind, lapply(c("screened", "usable"), function(v) {
  dor <- period(mm, cfg$dormant_months); sum_ <- period(mm, cfg$summer_months)
  ci <- cluster_ci(rbind(transform(dor, grp = "d"), transform(sum_, grp = "s")),
                   c(dor$overpass, sum_$overpass), function(x)
                     mean(x[[v]][x$grp == "d"]) / mean(x[[v]][x$grp == "s"]))
  data.frame(measure = v, p_dormant = mean(dor[[v]]), p_summer = mean(sum_[[v]]),
             ratio = ci[["estimate"]], lower = ci[["lower"]], upper = ci[["upper"]])
}))
save_csv(ratio, "seasonal_ratio")
seas <- do.call(rbind, lapply(c("metadata", "qa"), function(t) {
  s <- suppressWarnings(cl_seasonality(combined(if (t == "metadata") meta else qa_cells),
                                       threshold = thr, harmonics = cfg$harmonics,
                                       window_days = cfg$window_days))
  s$tier <- t
  s
}))
save_csv(seas, "seasonality_cells")

# ---- persistence ---------------------------------------------------------
pers <- do.call(rbind, lapply(c("metadata", "qa"), function(t) {
  p <- suppressWarnings(cl_persistence(if (t == "metadata") meta else qa_cells,
                                       threshold = thr, max_interval = cfg$max_interval))
  p$tier <- t
  p
}))
save_csv(pers, "persistence_cells")
ps <- do.call(rbind, lapply(split(pers, list(pers$tier, pers$sensor), drop = TRUE), function(d)
  data.frame(tier = d$tier[1], sensor = d$sensor[1], cells = nrow(d),
             median_interval = stats::median(d$median_interval_days),
             rho = stats::median(d$rho), decorrelation_days = stats::median(d$decorrelation_days, na.rm = TRUE),
             tau_days = stats::median(d$tau_days, na.rm = TRUE),
             tau_deseasonalised_days = stats::median(d$tau_deseasonalised_days, na.rm = TRUE))))
save_csv(ps, "persistence_summary")

# ---- centroid containment against exact overlap --------------------------
ov <- do.call(rbind, lapply(items, function(it) {
  g <- attr(it, "geometry")
  do.call(rbind, lapply(seq_len(nrow(it)), function(i) {
    rings <- getFromNamespace(".cs_geom_rings", "cloudscape")(g[[i]])
    a <- do.call(rbind, lapply(rings, function(r) cl_grid_index(r, area$grid, method = "area")))
    c0 <- unlist(lapply(rings, function(r) cl_grid_index(r, area$grid, method = "centroid")$cell))
    a <- a[a$cell %in% area$cells, , drop = FALSE]
    if (!nrow(a)) return(NULL)
    a <- stats::aggregate(weight ~ cell, a, function(x) min(1, sum(x)))
    data.frame(sensor = it$sensor[i], overpass = paste(it$sensor[i], as.Date(it$datetime[i])),
               cell = a$cell, fraction = a$weight, centroid = a$cell %in% c0)
  }))
}))
ov <- do.call(rbind, lapply(split(ov, paste(ov$overpass, ov$cell)), function(d)
  data.frame(sensor = d$sensor[1], overpass = d$overpass[1], cell = d$cell[1],
             fraction = max(d$fraction), centroid = any(d$centroid))))
save_csv(ov, "overlap_pairs")
ovc <- do.call(rbind, lapply(split(ov, list(ov$cell, ov$sensor), drop = TRUE), function(d)
  data.frame(cell = d$cell[1], sensor = d$sensor[1], n_centroid = sum(d$centroid),
             area_weighted = sum(d$fraction), n_any_overlap = nrow(d),
             rel_diff = sum(d$centroid) / sum(d$fraction) - 1)))
save_csv(ovc, "overlap_cells")
message("availability analysis complete: ", nrow(mm), " matched cell-observations")
