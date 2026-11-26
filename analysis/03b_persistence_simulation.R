# Recovery of the decorrelation time under the Andong acquisition schedules:
# known persistence, from below the shortest acquisition interval to several
# times it, the seasonal cloud probability observed at Andong, and three kinds
# of misclassification of the cloud state, for the Sentinel-2 and the Landsat
# acquisition dates of the cell with the median number of acquisitions.
source("analysis/config.R")
suppressPackageStartupMessages(library(cloudscape))
area <- study_area(cfg)
qa <- readRDS(file.path(data_dir, "obs_qa.rds"))
qa <- obs_subset(qa, qa$cell %in% area$cells)
days <- seq(as.Date(cfg$start), as.Date(cfg$end), by = "day")
wd <- 2 * pi * as.numeric(format(days, "%j")) / 365.25

# Two-state chain with daily time step, seasonal marginal p and lag-one
# correlation exp(-1 / tau) per day.
sim_chain <- function(p, tau) {
  r <- exp(-1 / tau); y <- logical(length(p))
  y[1] <- stats::runif(1) < p[1]
  u <- stats::runif(length(p))
  for (t in 2:length(p)) y[t] <- u[t] < (if (y[t - 1]) p[t] + (1 - p[t]) * r else p[t] * (1 - r))
  y
}

design <- list()
res <- do.call(rbind, lapply(cfg$sensors, function(sen) {
  o_s <- obs_subset(qa, qa$sensor == sen)
  n_cell <- table(o_s$cell)
  cell <- as.integer(names(n_cell)[which.min(abs(n_cell - stats::median(n_cell)))])
  o <- obs_subset(o_s, o_s$cell == cell)
  o <- o[order(o$date), ]
  dates <- sort(unique(o$date))
  idx <- match(dates, days)
  usable <- getFromNamespace(".cs_usable", "cloudscape")(o, cfg$threshold, cfg$coverage)
  w <- 2 * pi * as.numeric(format(o$date, "%j")) / 365.25
  fit <- stats::glm(!usable ~ sin(w) + cos(w) + sin(2 * w) + cos(2 * w), family = stats::binomial())
  p_day <- stats::predict(fit, newdata = data.frame(w = wd), type = "response")
  winter <- as.integer(format(dates, "%m")) %in% cfg$winter_months
  errors <- list(
    none = function(y) y,
    independent = function(y) xor(y, stats::runif(length(y)) < 0.1),
    seasonal = function(y) y | (winter & stats::runif(length(y)) < 0.3))
  design[[sen]] <<- data.frame(sensor = sen, cell = cell, n_dates = length(dates),
                               median_interval = stats::median(diff(as.numeric(dates))),
                               min_interval = min(diff(as.numeric(dates))))
  set.seed(cfg$seed)
  do.call(rbind, lapply(cfg$tau_true, function(tau) do.call(rbind, lapply(names(errors), function(e) {
    est <- t(vapply(seq_len(cfg$tau_reps), function(i) {
      y <- errors[[e]](sim_chain(p_day, tau)[idx])
      pe <- cl_persistence(cl_obs(cell, dates, as.numeric(y), sensor = sen),
                           threshold = 0.5, max_interval = cfg$max_interval)
      c(pe$decorrelation_days, pe$tau_days, pe$tau_deseasonalised_days)
    }, numeric(3)))
    colnames(est) <- c("decorrelation_days", "tau_days", "tau_deseasonalised_days")
    do.call(rbind, lapply(colnames(est), function(k) data.frame(
      sensor = sen, tau_true = tau, error = e, estimator = k,
      median = stats::median(est[, k], na.rm = TRUE),
      q25 = unname(stats::quantile(est[, k], 0.25, na.rm = TRUE)),
      q75 = unname(stats::quantile(est[, k], 0.75, na.rm = TRUE)),
      rel_bias = stats::median(est[, k], na.rm = TRUE) / tau - 1,
      missing = mean(is.na(est[, k])))))
  }))))
}))
save_csv(res, "persistence_simulation")
save_csv(do.call(rbind, design), "persistence_simulation_design")
message("persistence simulation complete")
