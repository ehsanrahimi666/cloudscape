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
  expect_equal(w$n_clear_obs[w$cell == 3], 0)
  expect_equal(w$max_gap_days[w$cell == 3], 365)
})

test_that("gaps increase monotonically with cloudiness", {
  w <- cl_stats_wide(cl_gaps(make_obs(), threshold = 0.2))
  w <- w[order(w$cell), ]
  expect_true(all(diff(w$max_gap_days) > 0))
})

test_that("tier metadata warns that clear counts are an upper bound", {
  o <- make_obs()
  expect_error(cl_clear_prob(o, "empirical"), "tier")
  expect_message(cl_clear_prob(o, "independent"), "upper bound")
  expect_true(all(cl_clear_prob(o, "clustered") <=
                    suppressMessages(cl_clear_prob(o, "independent")) + 1e-9))
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
