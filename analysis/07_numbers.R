# Collects the summary numbers quoted in the text from the saved outputs, so
# that each one is traceable to a file. Writes output/numbers.csv with one
# row per number: key, value and the file it was derived from.
source("analysis/config.R")
rd <- function(name) utils::read.csv(file.path(out_dir, paste0(name, ".csv")), stringsAsFactors = FALSE)
rdd <- function(name) utils::read.csv(file.path(data_dir, paste0(name, ".csv")), stringsAsFactors = FALSE)
num <- list()
put <- function(key, value, source) num[[key]] <<- data.frame(key = key, value = value, source = source)
q90 <- function(x) unname(stats::quantile(x, 0.9, na.rm = TRUE))

# ---- archive query -------------------------------------------------------
qm <- rdd("query_manifest")
for (s in unique(qm$sensor)) {
  k <- if (grepl("^sentinel", s)) "s2" else "ls"
  put(paste0("items_", k), sum(qm$n_items[qm$sensor == s]), "data/query_manifest.csv")
  put(paste0("superseded_", k), sum(qm$n_superseded[qm$sensor == s]), "data/query_manifest.csv")
}
put("items_total", sum(qm$n_items), "data/query_manifest.csv")
put("accessed", substr(min(qm$accessed), 1, 10), "data/query_manifest.csv")
cov <- rd("coverage")
for (v in names(cov)) put(paste0("coverage_", v), cov[[v]], "output/coverage.csv")
put("coverage_pct_matched", 100 * cov$n_matched / cov$n_metadata, "output/coverage.csv")

# ---- matched cell-observations -------------------------------------------
m <- rd("obs_matched")
mm <- m[!is.na(m$cloud_fraction_cell), ]
for (s in c("all", "sentinel-2-msi", "landsat-8-9-oli")) {
  d <- if (s == "all") mm else mm[mm$sensor == s, ]
  k <- c(all = "all", "sentinel-2-msi" = "s2", "landsat-8-9-oli" = "ls")[[s]]
  put(paste0("n_obs_", k), nrow(d), "output/obs_matched.csv")
  put(paste0("n_meta_", k), if (s == "all") nrow(m) else sum(m$sensor == s), "output/obs_matched.csv")
  put(paste0("n_overpass_", k), length(unique(d$overpass)), "output/obs_matched.csv")
  put(paste0("pct_screened_", k), 100 * mean(d$screened), "output/obs_matched.csv")
  put(paste0("pct_usable_", k), 100 * mean(d$usable), "output/obs_matched.csv")
  put(paste0("pct_usable_shadow_", k), 100 * mean(d$usable_shadow), "output/obs_matched.csv")
  put(paste0("mean_scene_cloud_", k), mean(d$cloud_fraction_scene), "output/obs_matched.csv")
  put(paste0("mean_cell_cloud_", k), mean(d$cloud_fraction_cell), "output/obs_matched.csv")
}
put("cells_per_overpass", nrow(mm) / length(unique(mm$overpass)), "output/obs_matched.csv")
at <- rd("agreement_table")
for (i in seq_len(nrow(at))) put(sprintf("table_screened%s_usable%s", at$screened[i], at$usable[i]),
                                 at$Freq[i], "output/agreement_table.csv")

# ---- agreement between tiers ---------------------------------------------
ag <- rd("agreement")
for (i in seq_len(nrow(ag))) for (v in c("estimate", "lower", "upper"))
  put(sprintf("agree_%s_%s_%s", ag$group[i], ag$statistic[i], v), ag[[v]][i], "output/agreement.csv")

# ---- counts per cell-year ------------------------------------------------
cy <- rd("counts_cell_year")
for (v in c("n_obs", "n_obs_s2", "n_obs_landsat", "n_screened", "n_usable", "n_usable_shadow", "clear_per_pixel")) {
  put(paste0("cy_median_", v), stats::median(cy[[v]]), "output/counts_cell_year.csv")
  put(paste0("cy_min_", v), min(cy[[v]]), "output/counts_cell_year.csv")
  put(paste0("cy_max_", v), max(cy[[v]]), "output/counts_cell_year.csv")
}
put("cy_rows", nrow(cy), "output/counts_cell_year.csv")
per_cell <- stats::aggregate(cbind(n_obs_s2, n_obs_landsat, n_usable, n_screened) ~ cell, cy, stats::median)
for (v in c("n_obs_s2", "n_obs_landsat", "n_usable", "n_screened")) {
  put(paste0("cell_min_", v), min(per_cell[[v]]), "output/counts_cell_year.csv")
  put(paste0("cell_max_", v), max(per_cell[[v]]), "output/counts_cell_year.csv")
}
put("cells_s2_high", sum(per_cell$n_obs_s2 > 1.5 * min(per_cell$n_obs_s2)), "output/counts_cell_year.csv")
# A cell seen from one Sentinel-2 relative orbit is revisited at multiples of
# five days by the two satellites; a cell in the overlap of two adjacent orbits
# also has intervals of two and three days. Count the cells of the second kind.
area <- study_area(cfg)
qa <- as.data.frame(readRDS(file.path(data_dir, "obs_qa.rds")))
s2 <- qa[qa$sensor == "sentinel-2-msi" & qa$cell %in% area$cells &
           qa$platform %in% c("sentinel-2a", "sentinel-2b") &
           qa$date < as.Date("2024-09-05"), ]
orbits <- tapply(s2$date, s2$cell, function(d) {
  iv <- as.numeric(diff(sort(unique(d))))
  if (mean(iv %% 5 != 0) > 0.3) 2L else 1L
})
put("cells_two_orbits", sum(orbits >= 2), "data/obs_qa.rds")
high <- per_cell$cell[per_cell$n_obs_s2 > 1.5 * min(per_cell$n_obs_s2)]
put("cells_high_are_two_orbits", as.integer(setequal(high, as.integer(names(orbits)[orbits >= 2]))), "data/obs_qa.rds")
put("cy_median_ratio_usable_screened", stats::median(cy$n_usable / cy$n_screened), "output/counts_cell_year.csv")

# ---- longest gaps --------------------------------------------------------
g <- rd("gaps_cell_year")
for (t in unique(g$tier)) {
  x <- g$max_gap_days[g$tier == t]
  put(paste0("gap_median_", t), stats::median(x), "output/gaps_cell_year.csv")
  put(paste0("gap_p90_", t), q90(x), "output/gaps_cell_year.csv")
  put(paste0("gap_max_", t), max(x), "output/gaps_cell_year.csv")
  if ("critical_gaps" %in% names(g))
    put(paste0("gap_critical_median_", t), stats::median(g$critical_gaps[g$tier == t]), "output/gaps_cell_year.csv")
}

# ---- seasonality ---------------------------------------------------------
sr <- rd("seasonal_ratio")
for (i in seq_len(nrow(sr))) for (v in c("p_dormant", "p_summer", "ratio", "lower", "upper"))
  put(sprintf("season_%s_%s", sr$measure[i], v), sr[[v]][i], "output/seasonal_ratio.csv")
mon <- rd("seasonal_monthly")
for (v in c("p_screened", "p_usable")) {
  put(paste0("month_max_", v), mon$month[which.max(mon[[v]])], "output/seasonal_monthly.csv")
  put(paste0("month_min_", v), mon$month[which.min(mon[[v]])], "output/seasonal_monthly.csv")
  put(paste0("value_max_", v), max(mon[[v]]), "output/seasonal_monthly.csv")
  put(paste0("value_min_", v), min(mon[[v]]), "output/seasonal_monthly.csv")
}

# ---- persistence ---------------------------------------------------------
ps <- rd("persistence_summary")
for (i in seq_len(nrow(ps))) {
  k <- sprintf("%s_%s", ps$tier[i], if (grepl("^sentinel", ps$sensor[i])) "s2" else "ls")
  for (v in c("cells", "median_interval", "rho", "decorrelation_days", "tau_days", "tau_deseasonalised_days"))
    put(sprintf("pers_%s_%s", k, v), ps[[v]][i], "output/persistence_summary.csv")
}
sim <- rd("persistence_simulation")
for (i in seq_len(nrow(sim))) for (v in c("median", "rel_bias", "missing"))
  put(sprintf("psim_%s_%s_%s_%s", sim$estimator[i], sim$error[i], sim$tau_true[i], v), sim[[v]][i],
      "output/persistence_simulation.csv")
psd <- rd("persistence_simulation_design")
put("psim_n_dates", psd$n_dates, "output/persistence_simulation_design.csv")
put("psim_median_interval", psd$median_interval, "output/persistence_simulation_design.csv")

# ---- phenology -----------------------------------------------------------
ph <- rd("pheno_summary")
sc_key <- c("Sentinel-2" = "s2", "Landsat 8 and 9" = "l89", "Landsat 8 and Sentinel-2" = "l8s2",
            "Landsat 8, 9 and Sentinel-2" = "all")
for (i in seq_len(nrow(ph))) for (v in setdiff(names(ph), c("tier", "scenario")))
  put(sprintf("ph_%s_%s_%s", ph$tier[i], sc_key[[ph$scenario[i]]], v), ph[[v]][i], "output/pheno_summary.csv")
ref <- rd("pheno_reference")
for (v in names(ref)) put(paste0("ph_", v), ref[[v]], "output/pheno_reference.csv")
se <- rd("pheno_sensitivity")
ak <- c("start of season (day)" = "sos", "observation noise (SD)" = "noise", "cloud persistence (rho)" = "rho")
for (i in seq_len(nrow(se))) for (v in c("sos_mae", "eos_mae", "peak_mae", "failure_rate"))
  put(sprintf("sens_%s_%s_%s", ak[[se$assumption[i]]], se$value[i], v), se[[v]][i], "output/pheno_sensitivity.csv")
gp <- rd("pheno_gap_position")
for (v in c("sos_mae", "peak_mae", "eos_mae")) {
  put(paste0("gap_", v, "_max"), max(gp[[v]], na.rm = TRUE), "output/pheno_gap_position.csv")
  put(paste0("gap_", v, "_at"), gp$gap_centre[which.max(gp[[v]])], "output/pheno_gap_position.csv")
  put(paste0("gap_", v, "_min"), min(gp[[v]], na.rm = TRUE), "output/pheno_gap_position.csv")
}
put("gap_failure_max", max(gp$failure_rate), "output/pheno_gap_position.csv")

# ---- centroid containment against exact overlap --------------------------
ov <- rd("overlap_cells")
for (s in unique(ov$sensor)) {
  k <- if (grepl("^sentinel", s)) "s2" else "ls"
  d <- ov[ov$sensor == s, ]
  put(paste0("ov_mean_rel_", k), 100 * mean(d$rel_diff), "output/overlap_cells.csv")
  put(paste0("ov_min_rel_", k), 100 * min(d$rel_diff), "output/overlap_cells.csv")
  put(paste0("ov_max_rel_", k), 100 * max(d$rel_diff), "output/overlap_cells.csv")
  put(paste0("ov_total_rel_", k), 100 * (sum(d$n_centroid) / sum(d$area_weighted) - 1), "output/overlap_cells.csv")
}
op <- rd("overlap_pairs")
put("ov_pairs", nrow(op), "output/overlap_pairs.csv")
put("ov_pct_partial", 100 * mean(op$fraction < 0.999), "output/overlap_pairs.csv")

# ---- detection consistency on synthetic scenes ---------------------------
det <- rd("detection_synthetic")
for (mth in unique(det$method)) for (v in c("iou", "ece")) {
  x <- det[[v]][det$method == mth]
  put(sprintf("det_%s_%s_median", mth, v), stats::median(x), "output/detection_synthetic.csv")
  put(sprintf("det_%s_%s_min", mth, v), min(x), "output/detection_synthetic.csv")
  put(sprintf("det_%s_%s_max", mth, v), max(x), "output/detection_synthetic.csv")
}
put("det_scenes", length(unique(det$seed)), "output/detection_synthetic.csv")
hr <- rd("validation_height_recovery")
put("hr_configs", nrow(hr), "output/validation_height_recovery.csv")
put("hr_sized_success", sum(hr$sized_success), "output/validation_height_recovery.csv")
put("hr_fixed_success", sum(hr$fixed_success), "output/validation_height_recovery.csv")
put("hr_within", sum(hr$within_limit), "output/validation_height_recovery.csv")
put("hr_fixed_success_within", sum(hr$fixed_success & hr$within_limit), "output/validation_height_recovery.csv")
put("hr_fixed_success_beyond", sum(hr$fixed_success & !hr$within_limit), "output/validation_height_recovery.csv")
window_m <- 96 * 30
inside <- !hr$within_limit & hr$displacement_m < window_m
put("hr_beyond_inside_window", sum(inside), "output/validation_height_recovery.csv")
put("hr_beyond_inside_window_success", sum(inside & hr$fixed_success), "output/validation_height_recovery.csv")
put("hr_beyond_outside_window", sum(!hr$within_limit & !inside), "output/validation_height_recovery.csv")
put("hr_beyond_outside_window_success", sum(!hr$within_limit & !inside & hr$fixed_success),
    "output/validation_height_recovery.csv")
ts <- rd("test_suite")
put("test_expectations", sum(ts$nb), "output/test_suite.csv")
put("test_files", length(unique(ts$file)), "output/test_suite.csv")
put("test_failed", sum(ts$failed), "output/test_suite.csv")
put("test_skipped", sum(ts$skipped), "output/test_suite.csv")

# ---- scene example -------------------------------------------------------
sx <- rd("scene_example")
put("sx_date", as.character(sx$date[1]), "output/scene_example.csv")
put("sx_tiles", nrow(sx), "output/scene_example.csv")
put("sx_scene_min", 100 * min(sx$scene_cloud_cover), "output/scene_example.csv")
put("sx_scene_max", 100 * max(sx$scene_cloud_cover), "output/scene_example.csv")
put("sx_cell_min", 100 * sx$cell_cloud_min[1], "output/scene_example.csv")
put("sx_cell_max", 100 * sx$cell_cloud_max[1], "output/scene_example.csv")
put("sx_candidates", sx$candidates[1], "output/scene_example.csv")

# ---- settings quoted in the text -------------------------------------------
for (k in c("n_sim", "boot", "gap_reps", "gap_window", "tau_reps", "seed", "threshold", "noise", "persistence",
            "max_interval", "overpass_minutes", "grid_res", "harmonics"))
  put(paste0("cfg_", k), cfg[[k]], "analysis/config.R")

out <- do.call(rbind, num)
rownames(out) <- NULL
save_csv(out, "numbers")
message(nrow(out), " numbers written")
