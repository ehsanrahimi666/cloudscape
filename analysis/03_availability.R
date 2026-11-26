# Compares the metadata and quality-layer evidence tiers over the study cells:
# counts of usable observations, agreement at the cell-observation level,
# longest gaps, seasonality, persistence, the effect of assigning footprints
# to cells by centroid containment, and the sensitivity of these results to
# the definition of usability, the spatial support of the metadata tier, the
# cell-observations without a quality-layer record and the resampling design.
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

# Scene cloud cover of every tile, and the number of tiles whose footprint
# contains each cell in each overpass of the metadata tier.
tiles <- do.call(rbind, lapply(items, function(it) data.frame(
  id = it$id, tile_cloud = it$cloud_cover / 100, stringsAsFactors = FALSE)))
per_tile <- do.call(rbind, lapply(items, function(it) do.call(rbind, lapply(seq_len(nrow(it)), function(i) {
  # A sliver footprint that contains no cell centre is assigned to no cell.
  o <- tryCatch(suppressMessages(cl_items_to_obs(subset_items(it, i), area$grid,
                                                 overpass_minutes = cfg$overpass_minutes)),
                error = function(e) if (grepl("No item footprints", conditionMessage(e))) NULL else stop(e))
  if (is.null(o)) return(NULL)
  o <- o[o$cell %in% area$cells, , drop = FALSE]
  if (!nrow(o)) return(NULL)
  data.frame(cell = o$cell, sensor = it$sensor[i], date = o$date)
}))))
n_tiles <- stats::aggregate(list(n_tiles = rep(1L, nrow(per_tile))),
                            per_tile[, c("cell", "sensor", "date")], sum)

m <- merge(as.data.frame(meta)[, c("cell", "sensor", "platform", "date", "cloud_fraction")],
           as.data.frame(qa)[, c("cell", "sensor", "date", "cloud_fraction", "shadow_fraction",
                                 "snow_fraction", "valid_fraction", "id")],
           by = c("cell", "sensor", "date"), all.x = TRUE, suffixes = c("_scene", "_cell"))
m <- merge(m, n_tiles, by = c("cell", "sensor", "date"), all.x = TRUE)
m$tile_cloud <- tiles$tile_cloud[match(m$id, tiles$id)]
versions <- utils::read.csv(file.path(out_dir, "landsat_mirror_versions.csv"), stringsAsFactors = FALSE)
m$other_version <- m$id %in% versions$id[versions$status == "other version"]
m <- m[order(m$cell, m$sensor, m$date), ]
m$year <- as.integer(format(m$date, "%Y"))
m$month <- as.integer(format(m$date, "%m"))
m$season <- season_of(m$month)
m$overpass <- paste(m$sensor, m$date)
m$screened <- m$cloud_fraction_scene <= thr
m$screened_tile <- m$tile_cloud <= thr
m$clear_share <- m$valid_fraction * (1 - m$cloud_fraction_cell)
m$usable <- m$clear_share >= 1 - thr - 1e-12
m$usable_shadow <- m$valid_fraction * (1 - m$cloud_fraction_cell - m$shadow_fraction) >= 1 - thr - 1e-12
for (v in cfg$sens_min_valid) {
  m[[sprintf("usable_v%02d", round(100 * v))]] <-
    m$cloud_fraction_cell <= thr & m$valid_fraction >= v
}
save_csv(m, "obs_matched")

# Cell-observations whose overpass includes a scene that no anonymous mirror
# serves, and that therefore lack a quality-layer record.
unread <- utils::read.csv(file.path(data_dir, "qa_unread.csv"), stringsAsFactors = FALSE)
unread_keys <- unlist(lapply(items, function(it) {
  k <- which(it$id %in% unread$id)
  if (!length(k)) return(character())
  o <- suppressMessages(cl_items_to_obs(subset_items(it, k), area$grid,
                                        overpass_minutes = cfg$overpass_minutes))
  paste(o$cell, o$sensor, o$date)
}))
no_qa <- is.na(m$cloud_fraction_cell)
cov <- data.frame(n_metadata = nrow(m), n_matched = sum(!no_qa),
                  n_qa = nrow(qa), n_items = sum(vapply(items, nrow, 1L)),
                  n_unread = nrow(unread),
                  n_no_qa_unread = sum(no_qa & paste(m$cell, m$sensor, m$date) %in% unread_keys),
                  n_no_qa_other = sum(no_qa & !paste(m$cell, m$sensor, m$date) %in% unread_keys),
                  n_overpasses_matched = length(unique(m$overpass[!no_qa])),
                  n_other_version = sum(m$other_version[!no_qa]),
                  n_multi_tile = sum(m$n_tiles[!no_qa] > 1L))
save_csv(cov, "coverage")
missing <- do.call(rbind, lapply(c("sensor", "season", "year"), function(v) {
  t <- table(m[[v]], no_qa)
  data.frame(variable = v, level = rownames(t), n_all = as.integer(rowSums(t)),
             n_missing = as.integer(t[, "TRUE"]), share_missing = as.numeric(t[, "TRUE"] / rowSums(t)),
             screened_all = as.numeric(tapply(m$screened, m[[v]], mean)[rownames(t)]),
             screened_missing = as.numeric(tapply(m$screened[no_qa], m[[v]][no_qa], mean)[rownames(t)]))
}))
save_csv(missing, "missing_qa")
mm <- m[!no_qa, ]
# Every comparison between tiers uses the cell-observations that have both a
# metadata and a quality-layer record.
obs_key <- function(o) paste(o$cell, o$sensor, o$date)
meta_matched <- obs_subset(meta, obs_key(meta) %in% obs_key(mm))
qa_cells <- obs_subset(qa, qa$cell %in% area$cells)

# ---- counts per cell-year -----------------------------------------------
cell_year <- function(d) do.call(rbind, lapply(split(d, list(d$cell, d$year), drop = TRUE), function(x)
  data.frame(cell = x$cell[1], year = x$year[1], n_obs = nrow(x),
             n_obs_s2 = sum(x$sensor == "sentinel-2-msi"),
             n_obs_landsat = sum(x$sensor == "landsat-8-9-oli"),
             n_screened = sum(x$screened), n_usable = sum(x$usable),
             n_usable_shadow = sum(x$usable_shadow),
             n_usable_v00 = sum(x$usable_v00),
             clear_per_pixel = sum(x$clear_share),
             clear_per_valid_pixel = sum(1 - x$cloud_fraction_cell),
             mean_scene_cloud = mean(x$cloud_fraction_scene),
             mean_cell_cloud = mean(x$cloud_fraction_cell))))
cy <- cell_year(mm)
save_csv(cy, "counts_cell_year")
num <- setdiff(names(cy), c("cell", "year"))
by_year <- do.call(rbind, lapply(split(cy, cy$year), function(d) {
  f <- function(x) formatC(x, format = "f", digits = 6)
  q <- function(v) sprintf("%s (%s-%s)", f(stats::median(v)), f(min(v)), f(max(v)))
  data.frame(year = d$year[1], cells = nrow(d), total_obs = sum(d$n_obs),
             total_screened = sum(d$n_screened), total_usable = sum(d$n_usable),
             as.list(stats::setNames(vapply(num, function(v) q(d[[v]]), ""), paste0(num, "_median_range"))))
}))
save_csv(by_year, "counts_by_year")

# Spatial variation: the usable count of a cell is its number of acquisitions
# times the share of them that is usable, so the variance of the log count
# splits into the two terms and their covariance.
per_cell <- do.call(rbind, lapply(split(cy, cy$cell), function(d) data.frame(
  cell = d$cell[1], n_obs = stats::median(d$n_obs), n_usable = stats::median(d$n_usable),
  n_screened = stats::median(d$n_screened), n_obs_s2 = stats::median(d$n_obs_s2),
  p_usable = sum(d$n_usable) / sum(d$n_obs), p_screened = sum(d$n_screened) / sum(d$n_obs),
  usable_minus_screened = stats::median(d$n_usable - d$n_screened))))
save_csv(per_cell, "counts_per_cell")
lN <- log(per_cell$n_obs); lp <- log(per_cell$p_usable); lU <- log(per_cell$n_obs * per_cell$p_usable)
save_csv(data.frame(var_log_usable = stats::var(lU), var_log_acquisitions = stats::var(lN),
                    var_log_share = stats::var(lp), cov2 = 2 * stats::cov(lN, lp),
                    cv_acquisitions = stats::sd(per_cell$n_obs) / mean(per_cell$n_obs),
                    cv_share = stats::sd(per_cell$p_usable) / mean(per_cell$p_usable),
                    cor_acquisitions_share = stats::cor(per_cell$n_obs, per_cell$p_usable)),
         "variance_decomposition")

# ---- agreement between scene screening and cell usability ----------------
stats_agree <- function(s = "screened", u = "usable") list(
  agreement = function(x) mean(x[[s]] == x[[u]]),
  p_usable_given_screened = function(x) mean(x[[u]][x[[s]]]),
  p_screened_given_usable = function(x) mean(x[[s]][x[[u]]]),
  usable_minus_screened = function(x) mean(x[[u]]) - mean(x[[s]]),
  mean_abs_cloud_difference = function(x) mean(abs(x$cloud_fraction_cell - x$cloud_fraction_scene)),
  spearman = function(x) stats::cor(x$cloud_fraction_cell, x$cloud_fraction_scene, method = "spearman"))
agree <- function(d) {
  d <- d[, c("screened", "usable", "cloud_fraction_cell", "cloud_fraction_scene",
             "year", "month", "overpass")]
  st <- stats_agree()
  do.call(rbind, lapply(names(st), function(k) {
    b <- block_ci(d, st[[k]])
    o <- cluster_ci(d, d$overpass, st[[k]])
    data.frame(statistic = k, estimate = b[["estimate"]], lower = b[["lower"]], upper = b[["upper"]],
               lower_overpass = o[["lower"]], upper_overpass = o[["upper"]],
               n_obs = nrow(d), n_overpasses = length(unique(d$overpass)))
  }))
}
groups <- c(list(all = mm), split(mm, mm$sensor), split(mm, mm$season))
ag <- do.call(rbind, lapply(names(groups), function(g) cbind(group = g, agree(groups[[g]]))))
save_csv(ag, "agreement")
cont <- do.call(rbind, lapply(names(groups)[1:3], function(g) {
  d <- groups[[g]]
  data.frame(group = g, n = nrow(d),
             both = sum(d$screened & d$usable), screened_only = sum(d$screened & !d$usable),
             usable_only = sum(!d$screened & d$usable), neither = sum(!d$screened & !d$usable))
}))
save_csv(cont, "agreement_table")

# ---- sensitivity of the comparison ---------------------------------------
gap_median <- function(o) {
  g <- cl_stats_wide(cl_gaps(o, threshold = thr, by = "year", critical = cfg$gap_critical,
                             coverage = cfg$coverage))
  stats::median(g$max_gap_days)
}
as_obs <- function(d, usable_col, tier) {
  o <- cl_obs(d$cell, d$date, ifelse(d[[usable_col]], 0, 1), sensor = "combined", tier = tier)
  o
}
ratio <- function(x, v) mean(x[[v]][x$month %in% cfg$winter_months]) /
  mean(x[[v]][x$month %in% cfg$summer_months])
robust_row <- function(label, d, s = "screened", u = "usable") {
  st <- stats_agree(s, u)
  cyd <- stats::aggregate(list(u = d[[u]], s = d[[s]]), d[, c("cell", "year")], sum)
  data.frame(variant = label, n_obs = nrow(d), n_usable = sum(d[[u]]), p_usable = mean(d[[u]]),
             n_screened = sum(d[[s]]), p_screened = mean(d[[s]]),
             agreement = st$agreement(d), p_usable_given_screened = st$p_usable_given_screened(d),
             p_screened_given_usable = st$p_screened_given_usable(d),
             median_usable_cell_year = stats::median(cyd$u), median_screened_cell_year = stats::median(cyd$s),
             gap_usable = gap_median(as_obs(d, u, "qa")), gap_screened = gap_median(as_obs(d, s, "metadata")),
             ratio_usable = ratio(d, u), ratio_screened = ratio(d, s))
}
rob <- rbind(
  robust_row("primary", mm),
  do.call(rbind, lapply(cfg$sens_min_valid, function(v)
    robust_row(sprintf("cloud at most 0.2, valid share at least %.2f", v), mm,
               u = sprintf("usable_v%02d", round(100 * v))))),
  robust_row("cloud shadow counted as cloud", mm, u = "usable_shadow"),
  robust_row("metadata from the tile read for the quality layer", mm, s = "screened_tile"),
  robust_row("cells covered by one tile", mm[mm$n_tiles == 1L, ]),
  robust_row("cells covered by one tile, same tile", mm[mm$n_tiles == 1L, ], s = "screened_tile"),
  robust_row("without scenes of another processing version", mm[!mm$other_version, ]))
save_csv(rob, "robustness")
# The metadata tier on all records, including the cell-observations without a
# quality-layer record.
save_csv(data.frame(p_screened_all = mean(m$screened), p_screened_matched = mean(mm$screened),
                    gap_screened_all = gap_median(as_obs(m, "screened", "metadata")),
                    gap_screened_matched = gap_median(as_obs(mm, "screened", "metadata")),
                    ratio_screened_all = ratio(m, "screened"), ratio_screened_matched = ratio(mm, "screened")),
         "missing_qa_effect")

# ---- longest gaps, both sensors combined --------------------------------
combined <- function(o) { o$sensor <- "combined"; o }
gap_tab <- do.call(rbind, lapply(c("metadata", "qa"), function(t) do.call(rbind, lapply(c(TRUE, FALSE), function(edges) {
  o <- combined(if (t == "metadata") meta_matched else qa_cells)
  g <- cl_stats_wide(cl_gaps(o, threshold = thr, by = "year", critical = cfg$gap_critical,
                             include_edges = edges, coverage = cfg$coverage))
  g$tier <- t; g$include_edges <- edges
  g
}))))
save_csv(gap_tab, "gaps_cell_year")

# ---- seasonality ---------------------------------------------------------
mon <- do.call(rbind, lapply(split(mm, mm$month), function(d) {
  b <- d[, c("screened", "usable", "year", "month")]
  s <- block_ci(b, function(x) mean(x$screened))
  u <- block_ci(b, function(x) mean(x$usable))
  data.frame(month = d$month[1], n_obs = nrow(d), n_overpasses = length(unique(d$overpass)),
             n_usable = sum(d$usable), n_screened = sum(d$screened),
             p_screened = s[["estimate"]], p_screened_lower = s[["lower"]], p_screened_upper = s[["upper"]],
             p_usable = u[["estimate"]], p_usable_lower = u[["lower"]], p_usable_upper = u[["upper"]],
             p_usable_shadow = mean(d$usable_shadow),
             mean_scene_cloud = mean(d$cloud_fraction_scene),
             mean_cell_cloud = mean(d$cloud_fraction_cell))
}))
save_csv(mon, "seasonal_monthly")
ws <- mm[mm$month %in% c(cfg$winter_months, cfg$summer_months),
         c("screened", "usable", "year", "month", "overpass")]
sratio <- do.call(rbind, lapply(c("screened", "usable"), function(v) {
  b <- block_ci(ws, function(x) ratio(x, v))
  o <- cluster_ci(ws, ws$overpass, function(x) ratio(x, v))
  data.frame(measure = v, p_winter = mean(ws[[v]][ws$month %in% cfg$winter_months]),
             p_summer = mean(ws[[v]][ws$month %in% cfg$summer_months]),
             n_winter = sum(ws$month %in% cfg$winter_months), n_summer = sum(ws$month %in% cfg$summer_months),
             ratio = b[["estimate"]], lower = b[["lower"]], upper = b[["upper"]],
             lower_overpass = o[["lower"]], upper_overpass = o[["upper"]])
}))
save_csv(sratio, "seasonal_ratio")
seas <- do.call(rbind, lapply(c("metadata", "qa"), function(t) {
  s <- suppressWarnings(cl_seasonality(combined(if (t == "metadata") meta_matched else qa_cells),
                                       threshold = thr, harmonics = cfg$harmonics,
                                       window_days = cfg$window_days, coverage = cfg$coverage))
  s$tier <- t
  s
}))
save_csv(seas, "seasonality_cells")

# ---- persistence ---------------------------------------------------------
pers_run <- function(o, max_interval) suppressWarnings(cl_persistence(
  o, threshold = thr, max_interval = max_interval, coverage = cfg$coverage))
pers <- do.call(rbind, lapply(c("metadata", "qa"), function(t) {
  p <- pers_run(if (t == "metadata") meta_matched else qa_cells, cfg$max_interval)
  p$tier <- t
  p
}))
save_csv(pers, "persistence_cells")
summarise_pers <- function(pers) do.call(rbind, lapply(split(pers, list(pers$tier, pers$sensor), drop = TRUE), function(d)
  data.frame(tier = d$tier[1], sensor = d$sensor[1], cells = nrow(d),
             median_interval = stats::median(d$median_interval_days),
             rho = stats::median(d$rho), decorrelation_days = stats::median(d$decorrelation_days, na.rm = TRUE),
             tau_days = stats::median(d$tau_days, na.rm = TRUE),
             tau_deseasonalised_days = stats::median(d$tau_deseasonalised_days, na.rm = TRUE),
             n_pairs = stats::median(d$n_pairs))))
save_csv(summarise_pers(pers), "persistence_summary")
pmax_tab <- do.call(rbind, lapply(cfg$sens_max_interval, function(mi) {
  p <- pers_run(qa_cells, mi); p$tier <- "qa"
  cbind(max_interval = mi, summarise_pers(p))
}))
save_csv(pmax_tab, "persistence_max_interval")

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
