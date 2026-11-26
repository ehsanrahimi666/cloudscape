# Collects every number quoted in the article from the saved outputs, so that
# each is traceable to a file, and formats the supplementary tables. Writes
# output/numbers.csv (key, value, source) and output/tables/*.csv.
source("analysis/config.R")
rd <- function(name) utils::read.csv(file.path(out_dir, paste0(name, ".csv")), stringsAsFactors = FALSE)
rdd <- function(name) utils::read.csv(file.path(data_dir, paste0(name, ".csv")), stringsAsFactors = FALSE)
num <- list()
put <- function(key, value, source) {
  stopifnot(length(value) == 1L, !is.na(value))
  v <- if (is.numeric(value)) format(value, digits = 15, scientific = FALSE, trim = TRUE) else as.character(value)
  num[[key]] <<- data.frame(key = key, value = v, source = source, stringsAsFactors = FALSE)
}
check <- function(ok, what) if (!isTRUE(ok)) stop("Statement not supported by the outputs: ", what)
tab_dir <- file.path(out_dir, "tables")
dir.create(tab_dir, showWarnings = FALSE)
save_table <- function(x, name) utils::write.csv(x, file.path(tab_dir, paste0(name, ".csv")), row.names = FALSE)
f0 <- function(x) formatC(round_half_up(x, 0), format = "f", digits = 0, big.mark = ",")
f1 <- function(x) formatC(round_half_up(x, 1), format = "f", digits = 1, big.mark = ",")
f2 <- function(x) formatC(round_half_up(x, 2), format = "f", digits = 2)
pc <- function(x, d = 1) paste0(formatC(round_half_up(100 * x, d), format = "f", digits = d), "%")
mr <- function(x, f = f0) sprintf("%s (%s–%s)", f(stats::median(x)), f(min(x)), f(max(x)))
season_name <- c(DJF = "December–February", MAM = "March–May", JJA = "June–August",
                 SON = "September–November")

# ---- archive -----------------------------------------------------------------
qm <- rdd("query_manifest")
put("items_s2", sum(qm$n_items[qm$sensor == "sentinel-2-msi"]), "data/query_manifest.csv")
put("items_ls", sum(qm$n_items[qm$sensor == "landsat-8-9-oli"]), "data/query_manifest.csv")
put("superseded_s2", sum(qm$n_superseded[qm$sensor == "sentinel-2-msi"]), "data/query_manifest.csv")
acc <- as.Date(substr(min(qm$accessed), 1, 10))
put("accessed", sprintf("%d %s %s", as.integer(format(acc, "%d")), format(acc, "%B"), format(acc, "%Y")),
    "data/query_manifest.csv")
mv <- rd("landsat_mirror_versions")
put("mirror_other", sum(mv$status == "other version"), "output/landsat_mirror_versions.csv")
put("mirror_other_l9", sum(mv$status == "other version" & mv$platform == "landsat-9"), "output/landsat_mirror_versions.csv")
put("mirror_absent", sum(mv$status == "absent from mirror"), "output/landsat_mirror_versions.csv")
un <- rdd("qa_unread")
put("unread_s2", sum(grepl("^sentinel", un$chunk)), "data/qa_unread.csv")
put("unread_ls", sum(grepl("^landsat", un$chunk)), "data/qa_unread.csv")
put("unread_total", nrow(un), "data/qa_unread.csv")
day_month_year <- function(d) { d <- as.Date(d); sprintf("%d %s %s", as.integer(format(d, "%d")), format(d, "%B"), format(d, "%Y")) }
sat <- rd("scl_saturation")
put("meta_accessed", day_month_year(sat$accessed), "output/scl_saturation.csv")
put("lc_accessed", day_month_year(rdd("land_cover_manifest")$accessed[1]), "data/land_cover_manifest.csv")
check(sat$n_saturated_positive == 0 && sat$n_found == sat$n_scenes, "no Sentinel-2 scene reports saturated pixels")
bl <- utils::read.csv(file.path(out_dir, "s2_baselines.csv"), colClasses = "character")
put("n_baselines", nrow(bl), "output/s2_baselines.csv")
put("baseline_min", min(bl$baseline), "output/s2_baselines.csv")
put("baseline_max", max(bl$baseline), "output/s2_baselines.csv")
cov <- rd("coverage")
put("cov_n_metadata", cov$n_metadata, "output/coverage.csv")
put("cov_n_matched", cov$n_matched, "output/coverage.csv")
put("cov_n_no_qa", cov$n_metadata - cov$n_matched, "output/coverage.csv")
put("cov_n_overpasses", cov$n_overpasses_matched, "output/coverage.csv")
put("cov_n_multi_tile", cov$n_multi_tile, "output/coverage.csv")
put("cov_n_other_version", cov$n_other_version, "output/coverage.csv")
put("cov_pct_matched", 100 * cov$n_matched / cov$n_metadata, "output/coverage.csv")
put("pct_multi_tile", cov$n_multi_tile / cov$n_matched, "output/coverage.csv")
put("cells_per_overpass", cov$n_matched / cov$n_overpasses_matched, "output/coverage.csv")
m <- rd("obs_matched"); mm <- m[!is.na(m$cloud_fraction_cell), ]
check(nrow(mm) == cov$n_matched, "matched count")
put("n_obs_all", nrow(mm), "output/obs_matched.csv")
put("matched_s2", sum(mm$sensor == "sentinel-2-msi"), "output/obs_matched.csv")
put("matched_ls", sum(mm$sensor == "landsat-8-9-oli"), "output/obs_matched.csv")
mq <- rd("missing_qa")
ms <- mq[mq$variable == "sensor", ]
put("missing_s2", ms$n_missing[ms$level == "sentinel-2-msi"], "output/missing_qa.csv")
put("missing_ls", ms$n_missing[ms$level == "landsat-8-9-oli"], "output/missing_qa.csv")
put("miss_share_s2", ms$share_missing[ms$level == "sentinel-2-msi"], "output/missing_qa.csv")
put("miss_share_ls", ms$share_missing[ms$level == "landsat-8-9-oli"], "output/missing_qa.csv")
check(sum(ms$n_missing) == cov$n_metadata - cov$n_matched, "missing count")
my <- mq[mq$variable == "year", ]
put("miss_n_years", sum(my$n_missing > 0), "output/missing_qa.csv")
mse <- mq[mq$variable == "season", ]
put("miss_top_season", season_name[[mse$level[which.max(mse$n_missing)]]], "output/missing_qa.csv")
lc <- rdd("land_cover_shares")
for (k in c(tree = "Tree cover", crop = "Cropland", grass = "Grassland", built = "Built-up", water = "Permanent water"))
  put(paste0("lc_", names(which(c(tree = "Tree cover", crop = "Cropland", grass = "Grassland", built = "Built-up",
                                  water = "Permanent water") == k))), lc$share[lc$class == k], "data/land_cover_shares.csv")

ov <- rd("overlap_cells")
put("ov_n", nrow(ov), "output/overlap_cells.csv")
put("ov_n_small", sum(abs(ov$rel_diff) < 0.01), "output/overlap_cells.csv")
put("ov_max", max(abs(ov$rel_diff)), "output/overlap_cells.csv")

# ---- agreement between tiers ---------------------------------------------------
ag <- rd("agreement")
gkey <- c(all = "all", s2 = "sentinel-2-msi", ls = "landsat-8-9-oli", djf = "DJF", mam = "MAM", jja = "JJA", son = "SON")
st <- function(g, s) ag[ag$group == gkey[[g]] & ag$statistic == s, ]
for (g in c("all", "s2", "ls")) {
  for (k in c(agree = "agreement", pug = "p_usable_given_screened", psg = "p_screened_given_usable")) {
    nm <- names(which(c(agree = "agreement", pug = "p_usable_given_screened", psg = "p_screened_given_usable") == k))
    r <- st(g, k)
    put(sprintf("%s_%s", nm, g), r$estimate, "output/agreement.csv")
    put(sprintf("%s_%s_lo", nm, g), r$lower, "output/agreement.csv")
    put(sprintf("%s_%s_hi", nm, g), r$upper, "output/agreement.csv")
  }
}
put("disagree_all", 1 - st("all", "agreement")$estimate, "output/agreement.csv")
d <- st("all", "usable_minus_screened")
put("diff_all", 100 * d$estimate, "output/agreement.csv")
put("diff_all_lo", 100 * d$lower, "output/agreement.csv")
put("diff_all_hi", 100 * d$upper, "output/agreement.csv")
put("rho_all", st("all", "spearman")$estimate, "output/agreement.csv")
put("mad_all", st("all", "mean_abs_cloud_difference")$estimate, "output/agreement.csv")
for (g in c("djf", "mam", "jja", "son")) put(paste0("psg_", g), st(g, "p_screened_given_usable")$estimate, "output/agreement.csv")
put("psg_jja_lo", st("jja", "p_screened_given_usable")$lower, "output/agreement.csv")
put("psg_jja_hi", st("jja", "p_screened_given_usable")$upper, "output/agreement.csv")
put("nscr_jja", 1 - st("jja", "p_screened_given_usable")$estimate, "output/agreement.csv")
pug_s <- vapply(c("djf", "mam", "jja", "son"), function(g) st(g, "p_usable_given_screened")$estimate, numeric(1))
put("pug_season_min", min(pug_s), "output/agreement.csv")
put("pug_season_max", max(pug_s), "output/agreement.csv")
check(which.min(vapply(c("djf", "mam", "jja", "son"), function(g) st(g, "p_screened_given_usable")$estimate, numeric(1))) == 3,
      "JJA has the lowest P(screened | usable)")
at <- rd("agreement_table")
for (g in c("all", "s2", "ls")) {
  r <- at[at$group == gkey[[g]], ]
  put(sprintf("ct_%s_n", g), r$n, "output/agreement_table.csv")
  put(sprintf("ct_%s_both", g), r$both, "output/agreement_table.csv")
  put(sprintf("ct_%s_so", g), r$screened_only, "output/agreement_table.csv")
  put(sprintf("ct_%s_uo", g), r$usable_only, "output/agreement_table.csv")
  put(sprintf("ct_%s_nei", g), r$neither, "output/agreement_table.csv")
}
put("n_screened_only_all", at$screened_only[at$group == "all"], "output/agreement_table.csv")
put("n_usable_only_all", at$usable_only[at$group == "all"], "output/agreement_table.csv")

# ---- the overpass of the scene example -------------------------------------------
sx <- rd("scene_example"); xd <- as.Date(sx$date[1])
day <- mm[as.Date(mm$date) == xd & mm$sensor == "sentinel-2-msi", ]
check(nrow(day) == 16L && !any(day$screened), "no cell of the example overpass passes scene screening")
put("ex_tiles", nrow(sx), "output/scene_example.csv")
put("ex_tile_min", min(sx$scene_cloud_cover), "output/scene_example.csv")
put("ex_tile_max", max(sx$scene_cloud_cover), "output/scene_example.csv")
put("ex_meta_min", min(day$cloud_fraction_scene), "output/obs_matched.csv")
put("ex_meta_max", max(day$cloud_fraction_scene), "output/obs_matched.csv")
put("ex_cell_min", min(day$cloud_fraction_cell), "output/obs_matched.csv")
put("ex_cell_max", max(day$cloud_fraction_cell), "output/obs_matched.csv")
put("ex_usable", sum(day$usable), "output/obs_matched.csv")

# ---- robustness ----------------------------------------------------------------
rb <- rd("robustness")
put("rob_agree_min", min(rb$agreement), "output/robustness.csv")
put("rob_agree_max", max(rb$agreement), "output/robustness.csv")
put("rob_pug_min", min(rb$p_usable_given_screened), "output/robustness.csv")
put("rob_pug_max", max(rb$p_usable_given_screened), "output/robustness.csv")
check(rb$variant[which.min(rb$p_usable_given_screened)] == "cloud shadow counted as cloud", "lowest P(usable | screened) with shadow")
check(grepl("valid share at least 0.00", rb$variant[which.max(rb$p_usable_given_screened)]), "highest P(usable | screened) without coverage")
put("rob_agree_tile", rb$agreement[rb$variant == "metadata from the tile read for the quality layer"], "output/robustness.csv")
put("rob_agree_one", rb$agreement[rb$variant == "cells covered by one tile"], "output/robustness.csv")
put("rob_agree_nov", rb$agreement[rb$variant == "without scenes of another processing version"], "output/robustness.csv")
rv <- function(v, k) rb[[k]][rb$variant == v]
put("rob_n_primary", rv("primary", "n_usable"), "output/robustness.csv")
put("rob_n_v00", rv("cloud at most 0.2, valid share at least 0.00", "n_usable"), "output/robustness.csv")
put("rob_agree_v00", rv("cloud at most 0.2, valid share at least 0.00", "agreement"), "output/robustness.csv")
put("rob_pug_v00", rv("cloud at most 0.2, valid share at least 0.00", "p_usable_given_screened"), "output/robustness.csv")
put("rob_one_n", rv("cells covered by one tile", "n_obs"), "output/robustness.csv")
ts <- rd("test_suite")
put("tests_n", sum(ts$nb), "output/test_suite.csv")
check(sum(ts$failed) == 0 && sum(ts$error) == 0, "no failing test")
me <- rd("missing_qa_effect")
put("scr_matched", me$p_screened_matched, "output/missing_qa_effect.csv")
put("scr_all", me$p_screened_all, "output/missing_qa_effect.csv")
put("gapscr_matched", me$gap_screened_matched, "output/missing_qa_effect.csv")
put("gapscr_all", me$gap_screened_all, "output/missing_qa_effect.csv")
put("ratioscr_matched", me$ratio_screened_matched, "output/missing_qa_effect.csv")
put("ratioscr_all", me$ratio_screened_all, "output/missing_qa_effect.csv")

# ---- counts per cell and year ---------------------------------------------------
cy <- rd("counts_cell_year")
check(sum(cy$n_obs) == nrow(mm), "cell-year counts cover the matched cell-observations")
put("cy_acq", stats::median(cy$n_obs), "output/counts_cell_year.csv")
put("cy_acq_min", min(cy$n_obs), "output/counts_cell_year.csv")
put("cy_acq_max", max(cy$n_obs), "output/counts_cell_year.csv")
put("cy_usable", stats::median(cy$n_usable), "output/counts_cell_year.csv")
put("cy_usable_min", min(cy$n_usable), "output/counts_cell_year.csv")
put("cy_usable_max", max(cy$n_usable), "output/counts_cell_year.csv")
put("cy_screened", stats::median(cy$n_screened), "output/counts_cell_year.csv")
put("cy_screened_min", min(cy$n_screened), "output/counts_cell_year.csv")
put("cy_screened_max", max(cy$n_screened), "output/counts_cell_year.csv")
put("cy_clear", stats::median(cy$clear_per_pixel), "output/counts_cell_year.csv")
for (y in cfg$years) {
  d <- cy[cy$year == y, ]
  put(sprintf("y%d_obs", y), sum(d$n_obs), "output/counts_cell_year.csv")
  put(sprintf("y%d_scr", y), sum(d$n_screened), "output/counts_cell_year.csv")
  put(sprintf("y%d_use", y), sum(d$n_usable), "output/counts_cell_year.csv")
  put(sprintf("y%d_acq_c", y), mr(d$n_obs), "output/counts_cell_year.csv")
  put(sprintf("y%d_scr_c", y), mr(d$n_screened), "output/counts_cell_year.csv")
  put(sprintf("y%d_use_c", y), mr(d$n_usable), "output/counts_cell_year.csv")
  put(sprintf("y%d_clear_c", y), mr(d$clear_per_pixel, f1), "output/counts_cell_year.csv")
}
put("yall_obs", sum(cy$n_obs), "output/counts_cell_year.csv")
put("yall_scr", sum(cy$n_screened), "output/counts_cell_year.csv")
put("yall_use", sum(cy$n_usable), "output/counts_cell_year.csv")
vd <- rd("variance_decomposition")
put("var_lu", vd$var_log_usable, "output/variance_decomposition.csv")
put("var_ln", vd$var_log_acquisitions, "output/variance_decomposition.csv")
put("var_lp", vd$var_log_share, "output/variance_decomposition.csv")
put("cov_lnp", vd$cov2, "output/variance_decomposition.csv")
put("share_ln", vd$var_log_acquisitions / vd$var_log_usable, "output/variance_decomposition.csv")
pcc <- rd("counts_per_cell")
put("cell_diff_med", stats::median(pcc$usable_minus_screened), "output/counts_per_cell.csv")
put("cell_diff_min", min(pcc$usable_minus_screened), "output/counts_per_cell.csv")
put("cell_diff_max", max(pcc$usable_minus_screened), "output/counts_per_cell.csv")
gy <- rd("gaps_cell_year")
gm <- function(t, e) stats::median(gy$max_gap_days[gy$tier == t & gy$include_edges == e])
put("gap_usable", gm("qa", TRUE), "output/gaps_cell_year.csv")
put("gap_screened", gm("metadata", TRUE), "output/gaps_cell_year.csv")
put("gap_usable_noedge", gm("qa", FALSE), "output/gaps_cell_year.csv")
put("gap_screened_noedge", gm("metadata", FALSE), "output/gaps_cell_year.csv")

# ---- seasonal availability --------------------------------------------------------
mo <- rd("seasonal_monthly")
mo$p_usable_point <- mo$n_usable / mo$n_obs
put("best_month", month.name[mo$month[which.max(mo$p_usable_point)]], "output/seasonal_monthly.csv")
put("best_month_p", max(mo$p_usable_point), "output/seasonal_monthly.csv")
put("worst_month", month.name[mo$month[which.min(mo$p_usable_point)]], "output/seasonal_monthly.csv")
put("worst_month_p", min(mo$p_usable_point), "output/seasonal_monthly.csv")
put("mon_n_min", min(mo$n_obs), "output/seasonal_monthly.csv")
put("mon_n_max", max(mo$n_obs), "output/seasonal_monthly.csv")
sr <- rd("seasonal_ratio")
for (k in c(u = "usable", s = "screened")) {
  r <- sr[sr$measure == k, ]; nm <- names(which(c(u = "usable", s = "screened") == k))
  put(paste0("ratio_", nm), r$ratio, "output/seasonal_ratio.csv")
  put(paste0("ratio_", nm, "_lo"), r$lower, "output/seasonal_ratio.csv")
  put(paste0("ratio_", nm, "_hi"), r$upper, "output/seasonal_ratio.csv")
  put(paste0("ratio_", nm, "_lo_o"), r$lower_overpass, "output/seasonal_ratio.csv")
  put(paste0("ratio_", nm, "_hi_o"), r$upper_overpass, "output/seasonal_ratio.csv")
}
ru <- sr[sr$measure == "usable", ]
put("p_djf_u", ru$p_winter, "output/seasonal_ratio.csv")
put("p_jja_u", ru$p_summer, "output/seasonal_ratio.csv")
put("n_djf", ru$n_winter, "output/seasonal_ratio.csv")
put("n_jja", ru$n_summer, "output/seasonal_ratio.csv")
days <- seq(as.Date(cfg$start), as.Date(cfg$end), by = "day")
mon <- as.integer(format(days, "%m"))
put("ratio_u_rate", (ru$p_winter * ru$n_winter / sum(mon %in% cfg$winter_months)) /
      (ru$p_summer * ru$n_summer / sum(mon %in% cfg$summer_months)), "output/seasonal_ratio.csv")
sc <- rd("seasonality_cells"); sq <- sc[sc$tier == "qa", ]
win <- sq[sq$peak_doy >= 300, ]
check(nrow(sq) == 16L && nrow(win) == 15L, "fifteen cells peak in late autumn or winter")
put("peak_min15", min(win$peak_doy), "output/seasonality_cells.csv")
put("peak_max15", max(win$peak_doy), "output/seasonality_cells.csv")
put("n_peak_winter", nrow(win), "output/seasonality_cells.csv")
put("peak_other", sq$peak_doy[sq$peak_doy < 300], "output/seasonality_cells.csv")
put("win_start_min", min(win$window_start), "output/seasonality_cells.csv")
put("win_start_max", max(win$window_start), "output/seasonality_cells.csv")

# ---- persistence --------------------------------------------------------------
ps <- rd("persistence_summary")
pq <- function(s, k) ps[[k]][ps$tier == "qa" & ps$sensor == s]
for (s in c(s2 = "sentinel-2-msi", ls = "landsat-8-9-oli")) {
  nm <- names(which(c(s2 = "sentinel-2-msi", ls = "landsat-8-9-oli") == s))
  put(paste0("tau_des_", nm), pq(s, "tau_deseasonalised_days"), "output/persistence_summary.csv")
  put(paste0("tau_", nm), pq(s, "tau_days"), "output/persistence_summary.csv")
  put(paste0("rho_", nm), pq(s, "rho"), "output/persistence_summary.csv")
  put(paste0("int_", nm), pq(s, "median_interval"), "output/persistence_summary.csv")
  put(paste0("conv_", nm), pq(s, "decorrelation_days"), "output/persistence_summary.csv")
}
pcel <- rd("persistence_cells"); pqc <- pcel[pcel$tier == "qa", ]
for (s in c(s2 = "sentinel-2-msi", ls = "landsat-8-9-oli")) {
  nm <- names(which(c(s2 = "sentinel-2-msi", ls = "landsat-8-9-oli") == s))
  x <- pqc$tau_deseasonalised_days[pqc$sensor == s]
  check(length(x) == 16L && all(is.finite(x)), "a deseasonalised estimate for every cell")
  put(paste0("tau_des_max_", nm), max(x), "output/persistence_cells.csv")
  # Estimates at or within 5% of the lower limit of the search interval (0.1 days).
  put(paste0("n_lower_", nm), sum(x <= 0.105), "output/persistence_cells.csv")
}
pmi <- rd("persistence_max_interval"); pmi <- pmi[pmi$tier == "qa", ]
ref <- stats::setNames(pmi$tau_deseasonalised_days[pmi$max_interval == cfg$max_interval],
                       pmi$sensor[pmi$max_interval == cfg$max_interval])
put("pmax_change", max(abs(pmi$tau_deseasonalised_days - ref[pmi$sensor])), "output/persistence_max_interval.csv")
check(max(abs(pmi$tau_deseasonalised_days - ref[pmi$sensor])) < 0.001, "pair limit changes the estimates by less than 0.001 days")
sim <- rd("persistence_simulation"); des <- rd("persistence_simulation_design")
put("psim_min_interval_s2", des$min_interval[des$sensor == "sentinel-2-msi"], "output/persistence_simulation_design.csv")
check(max(ps$tau_deseasonalised_days[ps$tier == "qa"]) < des$min_interval[des$sensor == "sentinel-2-msi"],
      "median deseasonalised estimates below the shortest interval")
sv <- function(e, k, s = NULL, t = NULL) {
  d <- sim[sim$error == e & sim$estimator == k, ]
  if (!is.null(s)) d <- d[d$sensor == s, ]
  if (!is.null(t)) d <- d[d$tau_true %in% t, ]
  d
}
t18 <- c(1, 2, 4, 8)
put("psim_deseas_relbias_max_1to8", max(abs(sv("none", "tau_deseasonalised_days", t = t18)$rel_bias)), "output/persistence_simulation.csv")
cs2 <- sv("none", "tau_days", "sentinel-2-msi", t18); vs2 <- sv("none", "decorrelation_days", "sentinel-2-msi", t18)
check(all(cs2$rel_bias > 0) && all(vs2$rel_bias > 0), "constant-probability and conversion estimators overestimate")
put("psim_const_relbias_min_s2", min(cs2$rel_bias), "output/persistence_simulation.csv")
put("psim_const_relbias_max_s2", max(cs2$rel_bias), "output/persistence_simulation.csv")
put("psim_conv_relbias_min_s2", min(vs2$rel_bias), "output/persistence_simulation.csv")
put("psim_conv_relbias_max_s2", max(vs2$rel_bias), "output/persistence_simulation.csv")
d05 <- sv("none", "tau_deseasonalised_days", "sentinel-2-msi", 0.5); d1 <- sv("none", "tau_deseasonalised_days", "sentinel-2-msi", 1)
put("psim_deseas_med_05_s2", d05$median, "output/persistence_simulation.csv")
put("psim_deseas_q25_05_s2", d05$q25, "output/persistence_simulation.csv")
put("psim_deseas_q75_05_s2", d05$q75, "output/persistence_simulation.csv")
put("psim_deseas_q25_1_s2", d1$q25, "output/persistence_simulation.csv")
put("psim_deseas_q75_1_s2", d1$q75, "output/persistence_simulation.csv")
ind <- sv("independent", "tau_deseasonalised_days", t = t18); sea <- sv("seasonal", "tau_deseasonalised_days", t = t18)
put("psim_deseas_indep_min", min(ind$rel_bias), "output/persistence_simulation.csv")
put("psim_deseas_indep_max", max(ind$rel_bias), "output/persistence_simulation.csv")
put("psim_deseas_seas_min", min(sea$rel_bias), "output/persistence_simulation.csv")
put("psim_deseas_seas_max", max(sea$rel_bias), "output/persistence_simulation.csv")

# ---- conditional retrieval error ---------------------------------------------
put("tau0", rd("pheno_tau")$tau_primary, "output/pheno_tau.csv")
sm <- rd("pheno_summary"); pcs <- rd("pheno_cells")
scen <- c(all = "Landsat 8, 9 and Sentinel-2", s2 = "Sentinel-2", ls = "Landsat 8 and 9", l8s2 = "Landsat 8 and Sentinel-2")
row_of <- function(t, s) sm[sm$tier == t & sm$scenario == scen[[s]], ]
for (t in c(pq = "qa", pm = "metadata")) for (s in names(scen)) {
  pre <- names(which(c(pq = "qa", pm = "metadata") == t)); r <- row_of(t, s)
  put(sprintf("%s_%s_acq", pre, s), r$n_acquisitions, "output/pheno_summary.csv")
  put(sprintf("%s_%s_ret", pre, s), r$n_retained, "output/pheno_summary.csv")
  put(sprintf("%s_%s_sos", pre, s), r$sos_mae, "output/pheno_summary.csv")
  put(sprintf("%s_%s_peak", pre, s), r$peak_mae, "output/pheno_summary.csv")
  put(sprintf("%s_%s_eos", pre, s), r$eos_mae, "output/pheno_summary.csv")
  put(sprintf("%s_%s_fail", pre, s), sprintf("%s (%s)", pc(r$failure_rate), pc(r$failure_max)), "output/pheno_summary.csv")
  put(sprintf("%s_%s_p", pre, s), sprintf("%s (%s)", pc(r$p_within_all, 0), pc(r$p_within_all_min, 0)), "output/pheno_summary.csv")
}
qa_all <- row_of("qa", "all")
put("ph_acq", qa_all$n_acquisitions, "output/pheno_summary.csv")
put("ph_ret", qa_all$n_retained, "output/pheno_summary.csv")
put("ph_sos", qa_all$sos_mae, "output/pheno_summary.csv")
put("ph_peak", qa_all$peak_mae, "output/pheno_summary.csv")
put("ph_eos", qa_all$eos_mae, "output/pheno_summary.csv")
check(qa_all$failure_max == 0, "no replicate failed with all platforms")
put("ph_p", qa_all$p_within_all, "output/pheno_summary.csv")
put("ph_pmin", qa_all$p_within_all_min, "output/pheno_summary.csv")
ca <- pcs[pcs$tier == "qa" & pcs$scenario == scen[["all"]], ]
put("ph_pmax", max(ca$p_within_all), "output/pheno_cells.csv")
put("ph_ret_min", min(ca$n_retained_expected), "output/pheno_cells.csv")
put("ph_ret_max", max(ca$n_retained_expected), "output/pheno_cells.csv")
put("ph_p_s2", row_of("qa", "s2")$p_within_all, "output/pheno_summary.csv")
put("ph_p_ls", row_of("qa", "ls")$p_within_all, "output/pheno_summary.csv")
put("ph_p_l8s2", row_of("qa", "l8s2")$p_within_all, "output/pheno_summary.csv")
put("ph_fail_ls", row_of("qa", "ls")$failure_max, "output/pheno_summary.csv")
put("phm_ret", row_of("metadata", "all")$n_retained, "output/pheno_summary.csv")
put("phm_p", row_of("metadata", "all")$p_within_all, "output/pheno_summary.csv")
se <- rd("pheno_sensitivity")
sv2 <- function(a, v, k = "p_within_all") se[[k]][se$assumption == a & se$value == v]
put("sn_n01", sv2("observation noise (SD)", "0.01"), "output/pheno_sensitivity.csv")
put("sn_n05", sv2("observation noise (SD)", "0.05"), "output/pheno_sensitivity.csv")
put("sn_a03", sv2("amplitude", "0.3"), "output/pheno_sensitivity.csv")
put("sn_a075", sv2("amplitude", "0.75"), "output/pheno_sensitivity.csv")
put("sn_s05", sv2("slope factor", "0.5"), "output/pheno_sensitivity.csv")
put("sn_s2", sv2("slope factor", "2"), "output/pheno_sensitivity.csv")
put("sn_s2_peak", sv2("slope factor", "2", "peak_mae"), "output/pheno_sensitivity.csv")
put("sn_t0", sv2("decorrelation time (days)", "0"), "output/pheno_sensitivity.csv")
put("sn_t4", sv2("decorrelation time (days)", "4"), "output/pheno_sensitivity.csv")
put("sn_t16", sv2("decorrelation time (days)", "16"), "output/pheno_sensitivity.csv")
put("sn_sos90", sv2("start of season (day)", "90"), "output/pheno_sensitivity.csv")
put("sn_sos150", sv2("start of season (day)", "150"), "output/pheno_sensitivity.csv")
put("sn_cell_ret", sv2("retention", "cell", "n_retained"), "output/pheno_sensitivity.csv")
put("sn_cell_p", sv2("retention", "cell"), "output/pheno_sensitivity.csv")
check(sv2("slope factor", "2", "sos_mae") < qa_all$sos_mae && sv2("slope factor", "2", "eos_mae") < qa_all$eos_mae,
      "doubled slopes reduce start and end errors")
gp <- rd("pheno_gap_position"); base <- gp[is.na(gp$gap_centre), ]; gp <- gp[!is.na(gp$gap_centre), ]
put("gap_base_p", base$p_within_all, "output/pheno_gap_position.csv")
put("gap_base_peak", base$peak_mae, "output/pheno_gap_position.csv")
w <- gp[which.min(gp$p_within_all), ]
put("gap_worst_c", w$gap_centre, "output/pheno_gap_position.csv")
put("gap_worst_p", w$p_within_all, "output/pheno_gap_position.csv")
put("gap_worst_peak", w$peak_mae, "output/pheno_gap_position.csv")
refd <- rd("pheno_reference")
near <- function(d) abs(gp$gap_centre - d) <= 30
zone <- ifelse(near(refd$reference_sos), "sos", ifelse(near(refd$reference_eos), "eos", "other"))
for (z in c("sos", "eos", "other")) {
  put(sprintf("gap_%s_min", z), min(gp$p_within_all[zone == z]), "output/pheno_gap_position.csv")
  put(sprintf("gap_%s_max", z), max(gp$p_within_all[zone == z]), "output/pheno_gap_position.csv")
}
check(zone[which.min(gp$p_within_all)] == "sos", "the largest reduction is near the start of season")
# Twice the binomial standard error of a probability estimated from the
# replicates of one window position.
put("gap_mc", 2 * sqrt(base$p_within_all * (1 - base$p_within_all) / cfg$gap_reps), "output/pheno_gap_position.csv")
th <- rd("pheno_thinning")
ths <- stats::aggregate(cbind(n_acquisitions, n_retained_median, n_retained_expected, sos_mae, peak_mae, eos_mae,
                              failure_rate, p_within_all) ~ fraction, th, stats::median)
tf <- function(f, k) ths[[k]][abs(ths$fraction - f) < 1e-9]
for (f in c(10, 20, 100)) {
  put(sprintf("th%d_ret", f), tf(f / 100, "n_retained_median"), "output/pheno_thinning.csv")
  put(sprintf("th%d_fail", f), tf(f / 100, "failure_rate"), "output/pheno_thinning.csv")
  put(sprintf("th%d_sos", f), tf(f / 100, "sos_mae"), "output/pheno_thinning.csv")
  put(sprintf("th%d_eos", f), tf(f / 100, "eos_mae"), "output/pheno_thinning.csv")
  put(sprintf("th%d_peak", f), tf(f / 100, "peak_mae"), "output/pheno_thinning.csv")
  put(sprintf("th%d_p", f), tf(f / 100, "p_within_all"), "output/pheno_thinning.csv")
}
put("th_rho", stats::cor(th$n_retained_expected, th$p_within_all, method = "spearman"), "output/pheno_thinning.csv")

# ---- cell size --------------------------------------------------------------------
ss <- rd("scale_summary"); chk <- rd("scale_check"); se_ <- rd("scale_example")
for (r in c(`6` = 6.25, `12` = 12.5, `25` = 25)) {
  k <- names(which(c(`6` = 6.25, `12` = 12.5, `25` = 25) == r))
  put(paste0("sc_p_", k), ss$p_usable[ss$res_km == r], "output/scale_summary.csv")
  put(paste0("sc_n_", k), ss$n_usable[ss$res_km == r], "output/scale_summary.csv")
}
put("sc_check_mad", chk$mean_abs_cloud_diff, "output/scale_check.csv")
put("sc_check_cor", chk$cor_cloud, "output/scale_check.csv")
put("ex25_share", se_$share_usable[se_$cell_size_km == 25], "output/scale_example.csv")
put("ex1_share", se_$share_usable[se_$cell_size_km == 1], "output/scale_example.csv")
put("ex25_clear", se_$share_clear_area_in_usable[se_$cell_size_km == 25], "output/scale_example.csv")
put("ex1_clear", se_$share_clear_area_in_usable[se_$cell_size_km == 1], "output/scale_example.csv")
check(se_$usable_cells[se_$cell_size_km == 25] == sum(day$usable), "scene example counts agree")

# ---- verification ---------------------------------------------------------------
vs <- rd("validation_summary"); va <- vs[vs$scope == "availability", ]
for (i in seq_len(nrow(va))) {
  put(sprintf("ver%d_component", i), va$component[i], "output/validation_summary.csv")
  put(sprintf("ver%d_type", i), va$type[i], "output/validation_summary.csv")
  put(sprintf("ver%d_against", i), va$verified_against[i], "output/validation_summary.csv")
  put(sprintf("ver%d_result", i), va$result[i], "output/validation_summary.csv")
}
put("r_version", paste(R.version$major, R.version$minor, sep = "."), "R session")
put("terra_version", as.character(utils::packageVersion("terra")), "R session")
put("sf_version", as.character(utils::packageVersion("sf")), "R session")
put("gdal_version", sf::sf_extSoftVersion()[["GDAL"]], "R session")

out <- do.call(rbind, num)
utils::write.csv(out, file.path(out_dir, "numbers.csv"), row.names = FALSE)

# ---- supplementary tables ---------------------------------------------------------
vd_ <- vs[vs$scope == "detection", ]
save_table(data.frame(Component = vd_$component, `Type of check` = vd_$type, `Verified against` = vd_$verified_against,
                      Result = vd_$result, check.names = FALSE), "tableS_detection_checks")
lim <- rd("identifiability_limit")
lw <- stats::reshape(lim, idvar = "window_km", timevar = "sun_zenith", direction = "wide")
names(lw) <- c("Window (km)", paste0(sub("max_resolvable_height_m.", "", names(lw)[-1]), "°"))
for (j in 2:ncol(lw)) lw[[j]] <- f0(lw[[j]])
save_table(lw, "tableS_height")
hr <- rd("validation_height_recovery")
yn <- function(x) ifelse(x, "Yes", "No")
save_table(data.frame(`Height (m)` = f0(hr$true_height), `Zenith (°)` = hr$sun_zenith, `Azimuth (°)` = hr$sun_azimuth,
                      `Displacement (m)` = f0(hr$displacement_m), `Within limit` = yn(hr$within_limit),
                      `Recovered, sized window (m)` = f0(hr$sized_recovered_m),
                      `Recovered, 2.9 km window (m)` = f0(hr$fixed_recovered_m),
                      `Success, 2.9 km window` = yn(hr$fixed_success), check.names = FALSE), "tableS_height_recovery")
vlab <- c(primary = "Primary", "cloud at most 0.2, valid share at least 0.00" = "Cloud fraction at most 0.2, valid share at least 0",
          "cloud at most 0.2, valid share at least 0.50" = "Cloud fraction at most 0.2, valid share at least 0.5",
          "cloud at most 0.2, valid share at least 0.75" = "Cloud fraction at most 0.2, valid share at least 0.75",
          "cloud at most 0.2, valid share at least 0.90" = "Cloud fraction at most 0.2, valid share at least 0.9",
          "cloud shadow counted as cloud" = "Cloud shadow counted as cloud",
          "metadata from the tile read for the quality layer" = "Scene cloud cover of the tile read for the quality layer",
          "cells covered by one tile" = "Cell-observations covered by one tile",
          "cells covered by one tile, same tile" = "Covered by one tile, scene cloud cover of that tile",
          "without scenes of another processing version" = "Without scenes read in another processing version")
check(all(rb$variant %in% names(vlab)), "robustness labels")
# With a single tile, the tile read for the quality layer is the only tile, so
# that variant repeats the one before it and is not tabulated.
check(isTRUE(all.equal(rb[rb$variant == "cells covered by one tile", -1],
                       rb[rb$variant == "cells covered by one tile, same tile", -1], check.attributes = FALSE)),
      "single-tile variants coincide")
rb <- rb[rb$variant != "cells covered by one tile, same tile", ]
save_table(data.frame(Definition = unname(vlab[rb$variant]), `Cell-observations` = f0(rb$n_obs),
                      `Cell-usable` = f0(rb$n_usable), `Scene-screened` = f0(rb$n_screened),
                      Agreement = pc(rb$agreement), `P(usable | screened)` = pc(rb$p_usable_given_screened),
                      `P(screened | usable)` = pc(rb$p_screened_given_usable),
                      `Longest gap, usable (days)` = f1(rb$gap_usable), `Longest gap, screened (days)` = f1(rb$gap_screened),
                      `DJF/JJA ratio, usable` = f2(rb$ratio_usable), check.names = FALSE), "tableS_robustness")
lvl <- ifelse(mq$variable == "sensor", c("sentinel-2-msi" = "Sentinel-2", "landsat-8-9-oli" = "Landsat 8–9")[mq$level],
              ifelse(mq$variable == "season", season_name[mq$level], mq$level))
save_table(data.frame(Group = c(sensor = "Sensor", season = "Season", year = "Year")[mq$variable], Level = unname(lvl),
                      `Cell-observations` = f0(mq$n_all), `Without quality layer` = f0(mq$n_missing),
                      `Share without` = pc(mq$share_missing), `Scene-screened, all` = pc(mq$screened_all),
                      `Scene-screened, without quality layer` = ifelse(is.na(mq$screened_missing), "–", pc(mq$screened_missing)),
                      check.names = FALSE), "tableS_missing")
slab <- c("sentinel-2-msi" = "Sentinel-2", "landsat-8-9-oli" = "Landsat 8–9")
p1 <- data.frame(Rows = ifelse(ps$tier == "qa", "Quality layer", "Scene metadata"), Sensor = unname(slab[ps$sensor]),
                 `Pair limit (days)` = cfg$max_interval, `Median interval (days)` = f0(ps$median_interval),
                 `Lag-one autocorrelation` = f2(ps$rho), `Median-interval conversion (days)` = f2(ps$decorrelation_days),
                 `Lag-aware, constant probability (days)` = f2(ps$tau_days),
                 `Lag-aware, deseasonalised (days)` = f2(ps$tau_deseasonalised_days), check.names = FALSE)
p2 <- data.frame(Rows = "Quality layer", Sensor = unname(slab[pmi$sensor]), `Pair limit (days)` = pmi$max_interval,
                 `Median interval (days)` = f0(pmi$median_interval), `Lag-one autocorrelation` = f2(pmi$rho),
                 `Median-interval conversion (days)` = f2(pmi$decorrelation_days),
                 `Lag-aware, constant probability (days)` = f2(pmi$tau_days),
                 `Lag-aware, deseasonalised (days)` = f2(pmi$tau_deseasonalised_days), check.names = FALSE)
names(p1)[1] <- names(p2)[1] <- "Evidence tier"
save_table(rbind(p1, p2[order(p2$Sensor, p2$`Pair limit (days)`), ]), "tableS_persistence")
alab <- c("decorrelation time (days)" = "Decorrelation time (days)", "observation noise (SD)" = "Noise standard deviation",
          "amplitude" = "Amplitude", "slope factor" = "Slopes, multiple of primary", "start of season (day)" = "Start of season (day)",
          "retention" = "Retention")
se$value_l <- ifelse(se$value == "cell", "Cell-usable only", se$value)
se <- se[order(match(se$assumption, names(alab)), suppressWarnings(as.numeric(se$value))), ]
save_table(data.frame(Assumption = unname(alab[se$assumption]), Value = se$value_l, Retained = f1(se$n_retained),
                      `SOS (days)` = f2(se$sos_mae), `Peak (days)` = f2(se$peak_mae), `EOS (days)` = f2(se$eos_mae),
                      Failure = pc(se$failure_rate), `P(all ≤ 5 d)` = sprintf("%s (%s)", pc(se$p_within_all, 0), pc(se$p_within_all_min, 0)),
                      check.names = FALSE), "tableS_pheno_sensitivity")
save_table(data.frame(`Fraction of acquisitions` = pc(ths$fraction, 0), Acquisitions = f1(ths$n_acquisitions),
                      Retained = f1(ths$n_retained_median), `SOS (days)` = f2(ths$sos_mae), `Peak (days)` = f2(ths$peak_mae),
                      `EOS (days)` = f2(ths$eos_mae), Failure = pc(ths$failure_rate), `P(all ≤ 5 d)` = pc(ths$p_within_all, 0),
                      check.names = FALSE), "tableS_thinning")
s1 <- data.frame(Source = "Quality layers, 2024", `Cell size (km)` = f2(ss$res_km), Cells = f0(ss$cells),
                 `Cell-observations per cell` = f1(ss$n_obs), `Usable per cell` = sprintf("%s (%s–%s)", f1(ss$n_usable), f1(ss$n_usable_q25), f1(ss$n_usable_q75)),
                 `Share usable` = pc(ss$p_usable), `Clear area in usable cells` = "–", check.names = FALSE)
s2 <- data.frame(Source = "Overpass of 12 June 2024", `Cell size (km)` = f2(se_$cell_size_km), Cells = f0(se_$cells),
                 `Cell-observations per cell` = "1", `Usable per cell` = "–", `Share usable` = pc(se_$share_usable),
                 `Clear area in usable cells` = pc(se_$share_clear_area_in_usable), check.names = FALSE)
save_table(rbind(s1, s2), "tableS_scale")
message("numbers: ", nrow(out), " values written")
