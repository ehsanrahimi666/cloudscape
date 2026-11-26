# Simulated error of phenological dates for the 2024 acquisition record of
# each cell, by evidence tier and constellation, with sensitivity analyses, an
# experiment on where in the season a gap falls, and a thinning experiment
# relating the number of retained observations to the error.
source("analysis/config.R")
suppressPackageStartupMessages(library(cloudscape))
area <- study_area(cfg)
items <- readRDS(file.path(data_dir, "items.rds"))
qa <- readRDS(file.path(data_dir, "obs_qa.rds"))
meta <- bind_obs(lapply(items, function(it) suppressMessages(
  cl_items_to_obs(it, area$grid, overpass_minutes = cfg$overpass_minutes))))
# Both tiers use the cell-observations that have a metadata and a
# quality-layer record.
obs_key <- function(o) paste(o$cell, o$sensor, o$date)
qa_cells <- obs_subset(qa, qa$cell %in% area$cells)
meta_cells <- obs_subset(meta, meta$cell %in% area$cells)
tiers <- list(metadata = obs_subset(meta_cells, obs_key(meta_cells) %in% obs_key(qa_cells)),
              qa = qa_cells)
yr <- cfg$pheno_year
s2 <- grep("^sentinel-2", unique(meta$platform), value = TRUE)
scenarios <- list(
  "Sentinel-2" = s2,
  "Landsat 8 and 9" = c("landsat-8", "landsat-9"),
  "Landsat 8 and Sentinel-2" = c("landsat-8", s2),
  "Landsat 8, 9 and Sentinel-2" = c("landsat-8", "landsat-9", s2))

# Decorrelation time of cloud loss: the median deseasonalised decorrelation
# time of the study cells in the quality-layer tier, rounded up to whole days.
pers <- utils::read.csv(file.path(out_dir, "persistence_cells.csv"), stringsAsFactors = FALSE)
tau_med <- stats::median(pers$tau_deseasonalised_days[pers$tier == "qa"], na.rm = TRUE)
tau0 <- ceiling(tau_med)
save_csv(data.frame(tau_primary = tau0, tau_median = tau_med), "pheno_tau")

run_map <- function(o, ...) {
  args <- utils::modifyList(list(threshold = cfg$threshold, curve = cfg$curve,
                                 noise = cfg$noise, tau = tau0, retention = cfg$retention,
                                 tolerance = cfg$tolerance, seed = cfg$seed), list(...))
  r <- do.call(cl_pheno_map, c(list(obs = o, year = yr, n_sim = cfg$n_sim), args))
  attr(r, "details")
}
summarise <- function(d) data.frame(
  cells = nrow(d), n_acquisitions = stats::median(d$n_acquisitions),
  n_retained = stats::median(d$n_retained_median), n_expected = stats::median(d$n_retained_expected),
  sos_mae = stats::median(d$sos_mae), peak_mae = stats::median(d$peak_mae),
  eos_mae = stats::median(d$eos_mae), sos_bias = stats::median(d$sos_bias),
  peak_bias = stats::median(d$peak_bias), eos_bias = stats::median(d$eos_bias),
  failure_rate = stats::median(d$failure_rate), failure_max = max(d$failure_rate),
  p_within_sos = stats::median(d$p_within_sos), p_within_peak = stats::median(d$p_within_peak),
  p_within_eos = stats::median(d$p_within_eos), p_within_all = stats::median(d$p_within_all),
  p_within_all_min = min(d$p_within_all))

cells <- do.call(rbind, lapply(names(tiers), function(t) do.call(rbind, lapply(names(scenarios), function(s) {
  o <- tiers[[t]]
  o <- obs_subset(o, as.integer(format(o$date, "%Y")) == yr & o$platform %in% scenarios[[s]])
  d <- run_map(o)
  d$tier <- t; d$scenario <- s
  d
}))))
save_csv(cells, "pheno_cells")
summ <- do.call(rbind, lapply(split(cells, list(cells$tier, cells$scenario), drop = TRUE), function(d)
  cbind(tier = d$tier[1], scenario = d$scenario[1], summarise(d))))
save_csv(summ, "pheno_summary")

# Sensitivity: one assumption varied at a time, quality-layer tier, all
# platforms, including retention of cell-usable observations only.
base <- obs_subset(tiers$qa, as.integer(format(tiers$qa$date, "%Y")) == yr)
curve_with <- function(...) utils::modifyList(cfg$curve, list(...))
sens_runs <- c(
  list(list(assumption = "retention", value = "cell", args = list(retention = "cell"))),
  lapply(cfg$sens_sos, function(v) list(assumption = "start of season (day)", value = v,
    args = list(curve = curve_with(sos = v, eos = v + cfg$curve$eos - cfg$curve$sos)))),
  lapply(cfg$sens_noise, function(v) list(assumption = "observation noise (SD)", value = v,
    args = list(noise = v))),
  lapply(cfg$sens_tau, function(v) list(assumption = "decorrelation time (days)", value = v,
    args = list(tau = v))),
  lapply(cfg$sens_amplitude, function(v) list(assumption = "amplitude", value = v,
    args = list(curve = curve_with(amplitude = v)))),
  lapply(cfg$sens_slope_factor, function(v) list(assumption = "slope factor", value = v,
    args = list(curve = curve_with(slope_up = v * cfg$curve$slope_up,
                                   slope_down = v * cfg$curve$slope_down)))))
sens <- do.call(rbind, lapply(sens_runs, function(r)
  cbind(assumption = r$assumption, value = as.character(r$value), do.call(run_map, c(list(base), r$args)))))
save_csv(sens, "pheno_sensitivity_cells")
sens_s <- do.call(rbind, lapply(split(sens, list(sens$assumption, sens$value), drop = TRUE), function(d)
  cbind(assumption = d$assumption[1], value = d$value[1], summarise(d))))
save_csv(sens_s, "pheno_sensitivity")

# Availability and error: the 2024 record of each cell thinned at random to a
# fraction of its acquisitions, quality-layer tier, all platforms.
thin <- do.call(rbind, lapply(sort(unique(base$cell)), function(k) {
  o <- base[base$cell == k, ]
  do.call(rbind, lapply(cfg$thin_fraction, function(f) {
    set.seed(cfg$seed + k %% 1000 + round(1000 * f))
    i <- sort(sample(nrow(o), max(6L, round(f * nrow(o)))))
    p <- cl_pheno_power(o$date[i], o$cloud_fraction[i], valid_fraction = o$valid_fraction[i],
                        curve = cfg$curve, noise = cfg$noise, tau = tau0, n_sim = cfg$n_sim,
                        retention = cfg$retention, tolerance = cfg$tolerance, seed = cfg$seed)$summary
    cbind(cell = k, fraction = f, p)
  }))
}))
save_csv(thin, "pheno_thinning")

# Where the gap falls: a complete five-day series without cloud, from which
# every observation within a 30-day window is removed, against the same series
# without a gap.
set.seed(cfg$seed)
doy <- seq(1, 365, by = 5)
truth <- function(x) do.call(cl_pheno_curve, c(list(doy = x), cfg$curve))
ref <- cl_pheno_fit(1:365, truth(1:365))
gap_run <- function(keep) {
  r <- t(vapply(seq_len(cfg$gap_reps), function(i) {
    v <- truth(doy[keep]) + stats::rnorm(sum(keep), 0, cfg$noise)
    f <- cl_pheno_fit(doy[keep], v)
    ok <- f$converged && is.finite(f$sos) && is.finite(f$eos) && is.finite(f$peak_doy) &&
      f$sos < f$peak_doy && f$peak_doy < f$eos
    c(sos = f$sos, eos = f$eos, peak = f$peak_doy, ok = ok)
  }, numeric(4)))
  ok <- r[, "ok"] == 1
  err <- abs(r[, c("sos", "peak", "eos")] - matrix(c(ref$sos, ref$peak_doy, ref$eos),
                                                   nrow(r), 3, byrow = TRUE))
  within <- ok & apply(err <= cfg$tolerance, 1, all)
  data.frame(sos_mae = stats::median(err[ok, "sos"]), peak_mae = stats::median(err[ok, "peak"]),
             eos_mae = stats::median(err[ok, "eos"]), failure_rate = mean(!ok),
             p_within_all = mean(within))
}
gp <- rbind(cbind(gap_centre = NA_real_, gap_run(rep(TRUE, length(doy)))),
            do.call(rbind, lapply(cfg$gap_centres, function(cen)
              cbind(gap_centre = cen, gap_run(abs(doy - cen) > cfg$gap_window / 2)))))
save_csv(gp, "pheno_gap_position")
save_csv(data.frame(reference_sos = ref$sos, reference_eos = ref$eos, reference_peak = ref$peak_doy),
         "pheno_reference")
message("phenology analysis complete")
