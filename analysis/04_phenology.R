# Phenological retrieval error for the 2024 acquisition record of each cell,
# by evidence tier and constellation, with sensitivity analyses and an
# experiment on where in the season a gap falls.
source("analysis/config.R")
suppressPackageStartupMessages(library(cloudscape))
area <- study_area(cfg)
items <- readRDS(file.path(data_dir, "items.rds"))
qa <- readRDS(file.path(data_dir, "obs_qa.rds"))
meta <- bind_obs(lapply(items, function(it) suppressMessages(
  cl_items_to_obs(it, area$grid, overpass_minutes = cfg$overpass_minutes))))
tiers <- list(metadata = obs_subset(meta, meta$cell %in% area$cells),
              qa = obs_subset(qa, qa$cell %in% area$cells))
yr <- cfg$pheno_year
s2 <- grep("^sentinel-2", unique(meta$platform), value = TRUE)
scenarios <- list(
  "Sentinel-2" = s2,
  "Landsat 8 and 9" = c("landsat-8", "landsat-9"),
  "Landsat 8 and Sentinel-2" = c("landsat-8", s2),
  "Landsat 8, 9 and Sentinel-2" = c("landsat-8", "landsat-9", s2))

run_map <- function(o, ...) {
  args <- utils::modifyList(list(threshold = cfg$threshold, curve = cfg$curve,
                                 noise = cfg$noise, persistence = cfg$persistence,
                                 seed = cfg$seed), list(...))
  r <- do.call(cl_pheno_map, c(list(obs = o, year = yr, n_sim = cfg$n_sim), args))
  attr(r, "details")
}

cells <- do.call(rbind, lapply(names(tiers), function(t) do.call(rbind, lapply(names(scenarios), function(s) {
  o <- tiers[[t]]
  o <- obs_subset(o, as.integer(format(o$date, "%Y")) == yr & o$platform %in% scenarios[[s]])
  d <- run_map(o)
  d$tier <- t; d$scenario <- s
  d
}))))
save_csv(cells, "pheno_cells")
summ <- do.call(rbind, lapply(split(cells, list(cells$tier, cells$scenario), drop = TRUE), function(d)
  data.frame(tier = d$tier[1], scenario = d$scenario[1], cells = nrow(d),
             n_acquisitions = stats::median(d$n_acquisitions),
             n_usable = stats::median(d$n_usable_median),
             sos_mae = stats::median(d$sos_mae), eos_mae = stats::median(d$eos_mae),
             peak_mae = stats::median(d$peak_mae), sos_bias = stats::median(d$sos_bias),
             eos_bias = stats::median(d$eos_bias), failure_rate = stats::median(d$failure_rate),
             failure_max = max(d$failure_rate))))
save_csv(summ, "pheno_summary")

# Sensitivity: one assumption varied at a time, quality-layer tier, all sensors.
base <- obs_subset(tiers$qa, as.integer(format(tiers$qa$date, "%Y")) == yr)
sens <- rbind(
  do.call(rbind, lapply(cfg$sens_sos, function(v) {
    cv <- utils::modifyList(cfg$curve, list(sos = v, eos = v + cfg$curve$eos - cfg$curve$sos))
    cbind(assumption = "start of season (day)", value = v, run_map(base, curve = cv))
  })),
  do.call(rbind, lapply(cfg$sens_noise, function(v)
    cbind(assumption = "observation noise (SD)", value = v, run_map(base, noise = v)))),
  do.call(rbind, lapply(cfg$sens_persistence, function(v)
    cbind(assumption = "cloud persistence (rho)", value = v, run_map(base, persistence = v)))))
save_csv(sens, "pheno_sensitivity_cells")
sens_s <- do.call(rbind, lapply(split(sens, list(sens$assumption, sens$value), drop = TRUE), function(d)
  data.frame(assumption = d$assumption[1], value = d$value[1],
             sos_mae = stats::median(d$sos_mae), eos_mae = stats::median(d$eos_mae),
             peak_mae = stats::median(d$peak_mae), failure_rate = stats::median(d$failure_rate))))
save_csv(sens_s, "pheno_sensitivity")

# Where the gap falls: a complete five-day series without cloud, from which
# every observation within a 30-day window is removed.
set.seed(cfg$seed)
doy <- seq(1, 365, by = 5)
truth <- function(x) do.call(cl_pheno_curve, c(list(doy = x), cfg$curve))
ref <- cl_pheno_fit(1:365, truth(1:365))
gp <- do.call(rbind, lapply(cfg$gap_centres, function(cen) {
  keep <- abs(doy - cen) > cfg$gap_window / 2
  r <- t(vapply(seq_len(cfg$gap_reps), function(i) {
    v <- truth(doy[keep]) + stats::rnorm(sum(keep), 0, cfg$noise)
    f <- cl_pheno_fit(doy[keep], v)
    c(sos = f$sos, eos = f$eos, peak = f$peak_doy, ok = f$converged && is.finite(f$sos))
  }, numeric(4)))
  ok <- r[, "ok"] == 1
  data.frame(gap_centre = cen, sos_mae = stats::median(abs(r[ok, "sos"] - ref$sos)),
             eos_mae = stats::median(abs(r[ok, "eos"] - ref$eos), na.rm = TRUE),
             peak_mae = stats::median(abs(r[ok, "peak"] - ref$peak_doy)),
             failure_rate = mean(!ok))
}))
gp_ref <- data.frame(reference_sos = ref$sos, reference_eos = ref$eos, reference_peak = ref$peak_doy)
save_csv(gp, "pheno_gap_position")
save_csv(gp_ref, "pheno_reference")
message("phenology analysis complete")
