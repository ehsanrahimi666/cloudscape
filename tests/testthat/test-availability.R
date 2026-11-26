make_obs <- function() {
  d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
  mk <- function(cell, pc, seed) {
    t <- cl_simulate_series(d, p_cloud = pc, persistence = 0.35, seed = seed)
    data.frame(cell = cell, date = t$date, cloud_fraction = t$cloud_fraction)
  }
  raw <- rbind(mk(1, 0.25, 1), mk(2, 0.55, 2), mk(3, 0.995, 3))
  cl_obs(raw$cell, raw$date, raw$cloud_fraction, sensor = "sentinel-2-msi")
}

test_that("cells with no usable observation are retained, not dropped", {
  o <- make_obs()
  g <- cl_gaps(o, threshold = 0.2)
  expect_setequal(unique(g$cell), unique(o$cell))
  w <- cl_stats_wide(g)
  expect_equal(w$n_clear_dates[w$cell == 3], 0)
  expect_equal(w$max_gap_days[w$cell == 3], 366)
})

test_that("gaps increase monotonically with cloudiness", {
  w <- cl_stats_wide(cl_gaps(make_obs(), threshold = 0.2))
  w <- w[order(w$cell), ]
  expect_true(all(diff(w$max_gap_days) > 0))
})

test_that("the empirical model needs fractions measured for the cell", {
  o <- make_obs()
  expect_error(cl_clear_prob(o, "empirical"), "tier")
  expect_equal(cl_clear_prob(o, "independent"), 1 - o$cloud_fraction)
  p <- cl_clear_prob(o, "clustered")
  expect_true(all(p >= 0 & p <= 1))
})

test_that("constellation synergy tracks platform commissioning", {
  s <- cl_synergy(c("landsat-8-9-oli", "sentinel-2-msi"),
                  "2014-01-01", "2025-12-31", by = "year")
  s <- s[s$sensor == "COMBINED", ]
  get <- function(y) s$combined_obs[s$period == y]
  expect_lt(get("2014"), get("2018"))
  expect_lt(get("2021"), get("2022"))
  expect_lt(get("2023"), get("2025"))
})

test_that("cl_persistence recovers the autocorrelation used to simulate", {
  # rho = p11 - p01 is exact for the two-state chain, so a simulator with a
  # known rho is a complete test of the estimator.
  d <- seq(as.Date("2015-01-01"), as.Date("2024-12-31"), by = "5 days")
  for (rho in c(0, 0.3, 0.6)) {
    est <- vapply(1:20, function(s) {
      ts <- cl_simulate_series(d, p_cloud = 0.5, persistence = rho, seed = s)
      # Feed the latent state directly: this tests the estimator itself,
      # separately from the proxy used to observe the state.
      o <- cl_obs(1, ts$date, as.numeric(ts$cloudy), sensor = "s2")
      cl_persistence(o, threshold = 0.5)$rho
    }, numeric(1))
    expect_equal(mean(est), rho, tolerance = 0.05,
                 label = sprintf("rho = %.1f", rho))
  }
})

test_that("thresholding a noisy cloud fraction attenuates rho towards zero", {
  # Documented behaviour, not a defect: scene cloud fraction is a noisy proxy
  # for whether a specific cell was usable, and independent misclassification
  # biases an estimated autocorrelation downwards. Archive-derived rho is
  # therefore a lower bound, which the paper must state.
  d <- seq(as.Date("2015-01-01"), as.Date("2024-12-31"), by = "5 days")
  f <- function(rho, use_latent) {
    mean(vapply(1:20, function(s) {
      ts <- cl_simulate_series(d, p_cloud = 0.5, persistence = rho, seed = s)
      v <- if (use_latent) as.numeric(ts$cloudy) else ts$cloud_fraction
      cl_persistence(cl_obs(1, ts$date, v, sensor = "s2"),
                     threshold = 0.5)$rho
    }, numeric(1)))
  }
  latent <- f(0.6, TRUE); proxy <- f(0.6, FALSE)
  expect_lt(proxy, latent)          # attenuated
  expect_gt(proxy, 0.5 * latent)    # but not destroyed
})

test_that("cl_persistence is not inflated by duplicate same-date footprints", {
  d <- seq(as.Date("2020-01-01"), as.Date("2023-12-31"), by = "5 days")
  ts <- cl_simulate_series(d, p_cloud = 0.5, persistence = 0.4, seed = 3)
  single <- cl_obs(1, ts$date, ts$cloud_fraction, sensor = "s2")
  # The same acquisition intersecting the cell twice via orbital side-lap
  dup <- cl_obs(rep(1, 2 * nrow(ts)), rep(ts$date, 2),
                rep(ts$cloud_fraction, 2), sensor = "s2")
  expect_equal(cl_persistence(dup, threshold = 0.5)$rho,
               cl_persistence(single, threshold = 0.5)$rho, tolerance = 1e-9)
})

test_that("decorrelation time is lag-invariant", {
  # rho is measured at whatever the local acquisition interval happens to be,
  # and orbits converge poleward, so raw rho penalises places observed less
  # often. tau = -dt/log(rho) removes that dependence.
  d1 <- seq(as.Date("2015-01-01"), as.Date("2024-12-31"), by = "1 day")
  d5 <- seq(as.Date("2015-01-01"), as.Date("2024-12-31"), by = "5 days")
  tau <- function(dates, rho_per_step) {
    est <- vapply(1:15, function(s) {
      ts <- cl_simulate_series(dates, 0.5, rho_per_step, seed = s)
      cl_persistence(cl_obs(1, ts$date, as.numeric(ts$cloudy), sensor = "s2"),
                     threshold = 0.5, max_interval = 30)$decorrelation_days
    }, numeric(1))
    mean(est)
  }
  # Same underlying decorrelation time (~3.6 d) sampled at 1-day and 5-day lags
  t1 <- tau(d1, exp(-1 / 3.6))
  t5 <- tau(d5, exp(-5 / 3.6))
  expect_lt(abs(t1 - 3.6), 0.6)
  expect_lt(abs(t5 - 3.6), 0.9)
  expect_lt(abs(t1 - t5), 1.2)
})

# Two-state chain with relaxation time tau on a daily grid, with a cloud
# probability that may vary by day; sampling it on irregular dates mimics an
# archive in which the interval between acquisitions varies.
sim_chain <- function(n, p, tau, seed) {
  set.seed(seed)
  r <- exp(-1 / tau)
  y <- logical(n)
  y[1] <- stats::runif(1) < p[1]
  for (t in 2:n) {
    q <- if (y[t - 1]) p[t] + (1 - p[t]) * r else p[t] * (1 - r)
    y[t] <- stats::runif(1) < q
  }
  y
}

test_that("the decorrelation time is recovered from irregular intervals", {
  days <- seq(as.Date("2015-01-01"), as.Date("2024-12-31"), by = "day")
  y <- sim_chain(length(days), rep(0.5, length(days)), tau = 4, seed = 3)
  set.seed(4)
  keep <- cumsum(sample(c(2, 3, 5, 8), 2000, replace = TRUE))
  keep <- keep[keep <= length(days)]
  o <- cl_obs(1, days[keep], as.numeric(y[keep]), sensor = "sentinel-2-msi")
  pe <- cl_persistence(o, threshold = 0.5, max_interval = 20)
  expect_lt(abs(pe$tau_days - 4), 0.8)
})

test_that("the deseasonalised estimate separates weather from the seasonal cycle", {
  days <- seq(as.Date("2015-01-01"), as.Date("2024-12-31"), by = "day")
  doy <- as.numeric(format(days, "%j"))
  p <- 0.5 + 0.35 * cos(2 * pi * (doy - 200) / 365.25)
  y <- sim_chain(length(days), p, tau = 3, seed = 5)
  keep <- seq(1, length(days), by = 5)
  o <- cl_obs(1, days[keep], as.numeric(y[keep]), sensor = "sentinel-2-msi")
  pe <- cl_persistence(o, threshold = 0.5, max_interval = 20)
  expect_lt(abs(pe$tau_deseasonalised_days - 3), 0.8)
  expect_gt(pe$tau_days, pe$tau_deseasonalised_days + 1)
})

test_that("usability accounts for the observed share of the cell", {
  d <- as.Date("2024-01-01") + c(0, 10, 20, 30)
  o <- cl_obs(1, d, cloud_fraction = c(0, 0.1, 0.2, 0.1), sensor = "sentinel-2-msi",
              tier = "qa")
  o$valid_fraction <- c(1, 0.5, 1, 0.95)
  w <- cl_stats_wide(cl_clear_obs(o, by = "all"))
  # Clear shares 1, 0.45, 0.8 and 0.855: three reach 0.8
  expect_equal(w$n_clear_obs, 3)
  expect_equal(cl_stats_wide(cl_clear_obs(o, by = "all", coverage = FALSE))$n_clear_obs, 4)
  expect_equal(w$p_clear * w$n_scenes, sum(o$valid_fraction * (1 - o$cloud_fraction)))
  g <- cl_stats_wide(cl_gaps(o, by = "all", include_edges = FALSE))
  expect_equal(g$max_gap_days, 20)
})

test_that("seasons are meteorological and December opens the next winter", {
  per <- getFromNamespace(".cs_period", "cloudscape")
  bnd <- getFromNamespace(".cs_period_bounds", "cloudscape")
  d <- as.Date(c("2019-12-15", "2020-01-10", "2020-03-01", "2020-08-31", "2020-11-30"))
  expect_equal(per(d, "season"), c("2020-DJF", "2020-DJF", "2020-MAM", "2020-JJA", "2020-SON"))
  expect_equal(bnd("2020-DJF", "season"), as.Date(c("2019-12-01", "2020-02-29")))
  expect_equal(bnd("2021-DJF", "season"), as.Date(c("2020-12-01", "2021-02-28")))
  expect_equal(bnd("2020-SON", "season"), as.Date(c("2020-09-01", "2020-11-30")))
})

test_that("gaps are closed by virtual observations outside the period", {
  o <- cl_obs(1, as.Date(c("2023-01-01", "2023-12-31")), c(0, 0), sensor = "x")
  w <- cl_stats_wide(cl_gaps(o, by = "year"))
  expect_equal(w$max_gap_days, 364)
  expect_equal(w$mean_gap_days, 366 / 3)
  none <- cl_obs(1, as.Date("2023-07-01"), 1, sensor = "x")
  expect_equal(cl_stats_wide(cl_gaps(none, by = "year"))$max_gap_days, 366)
  twice <- cl_obs(1, as.Date(c("2023-06-01", "2023-06-01", "2023-06-11")), 0, sensor = "x")
  expect_equal(cl_stats_wide(cl_gaps(twice, by = "year"))$n_clear_dates, 2)
  expect_equal(cl_stats_wide(cl_clear_obs(twice, by = "year"))$n_clear_obs, 3)
})

test_that("usability thresholds outside [0, 1] are rejected", {
  o <- cl_obs(1, seq(as.Date("2023-01-01"), by = "5 days", length.out = 40),
              rep(c(0.1, 0.9), 20), sensor = "x")
  expect_error(cl_gaps(o, threshold = 20))
  expect_error(cl_persistence(o, threshold = 20))
  expect_error(cl_seasonality(o, threshold = 20))
  expect_error(cl_clear_prob(o, "clustered", threshold = 20))
})

test_that("acquisitions without a cloud fraction are left out of persistence", {
  d <- seq(as.Date("2023-01-01"), by = "5 days", length.out = 60)
  cf <- rep(c(0, 1, 1, 0, 1, 0), 10); cf[7] <- NA
  r <- cl_persistence(cl_obs(1, d, cf, sensor = "x"))
  expect_true(is.finite(r$rho))
})

test_that("strongly seasonal cells are fitted and flagged, not dropped", {
  d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
  cf <- ifelse(as.integer(format(d, "%m")) %in% 5:9, 0.9, 0.05)
  s <- cl_seasonality(cl_obs(1, d, cf, sensor = "x"))
  expect_true(is.finite(s$amplitude))
  expect_true(s$separated)
  expect_true(s$peak_doy < 120 || s$peak_doy > 273)
})

test_that("effective revisit uses the days of each period", {
  s <- cl_synergy("landsat-8-9-oli", "2015-01-01", "2015-06-30", by = "year")
  r <- s[s$sensor == "landsat-8-9-oli", ]
  expect_equal(r$days, 181)
  expect_equal(r$effective_revisit_days, 16, tolerance = 1e-9)
})

test_that("the clustered model gives the probability of a usable observation", {
  o <- cl_obs(1:3, as.Date("2023-06-01"), c(0.1, 0.5, 0.9), sensor = "x")
  p20 <- cl_clear_prob(o, "clustered", threshold = 0.2)
  p50 <- cl_clear_prob(o, "clustered", threshold = 0.5)
  expect_true(all(p20 >= 0 & p20 <= 1))
  expect_true(all(p50 >= p20))
  expect_true(all(diff(p20) < 0))
  q <- o; q$valid_fraction <- 0.5
  attr(q, "tier") <- "qa"
  expect_equal(cl_clear_prob(q, "clustered", threshold = 0.2), c(0, 0, 0))
})

test_that("extra observation columns stay aligned after sorting", {
  o <- cl_obs(c(2, 1, 1), as.Date(c("2023-01-01", "2023-03-01", "2023-02-01")),
              c(0.2, 0.3, 0.4), id = c("a", "b", "c"))
  expect_equal(o$id, c("c", "b", "a"))
  expect_equal(o$cloud_fraction, c(0.4, 0.3, 0.2))
  p <- cl_obs(1:3, as.Date("2023-01-01"), c(0, 0.5, 1), percent = TRUE)
  expect_equal(p$cloud_fraction, c(0, 0.005, 0.01))
  expect_error(cl_obs(1, as.Date("2023-01-01"), 0.1, "x", "p", "metadata", NA, NA, 5))
})

test_that("merging summaries with missing values or sample sizes gives NA", {
  a <- cl_stats(1, "cloud_fraction", 0.5, period = "2023", n = 10)
  b <- cl_stats(1, "cloud_fraction", NA, period = "2023", n = 10)
  expect_warning(m <- cl_stats_merge(a, b), "Missing values")
  expect_true(is.na(m$value))
  c3 <- cl_stats(1, "n_scenes", NA, period = "2023", n = 10)
  d3 <- cl_stats(1, "n_scenes", 4, period = "2023", n = 4)
  expect_warning(m2 <- cl_stats_merge(c3, d3), "Missing values")
  expect_true(is.na(m2$value))
})
