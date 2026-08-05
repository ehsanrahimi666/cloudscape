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
