test_that("cl_stats rejects out-of-range values and unknown metrics", {
  expect_error(cl_stats(1:2, "cloud_fraction", c(0.3, 1.4)), "permitted range")
  expect_error(cl_stats(1:2, "images_per_pathrow", c(3, 4)), "Unknown metric")
  expect_error(cl_stats(1, "n_scenes", 5, denominator = "per-path-row"),
               "Unknown denominator")
  expect_s3_class(cl_stats(1:2, "cloud_fraction", c(0.3, 0.9)), "cl_stats")
})

test_that("the denominator is carried, not implied", {
  s <- cl_stats(1:3, "n_scenes", c(20, 21, 22), period = "2023",
                denominator = "cell-year")
  expect_true(all(s$denominator == "cell-year"))
  expect_true(all(s$unit == "count"))
})

test_that("cloud fraction given as percent is detected", {
  expect_warning(o <- cl_obs(1:3, Sys.Date(), c(20, 50, 80)), "percent")
  expect_lte(max(o$cloud_fraction), 1)
})

test_that("metrics combine by their declared rule, not by a single default", {
  # Counts add
  a <- cl_stats(1:2, "n_scenes", c(10, 12), period = "2023", n = c(10, 12))
  b <- cl_stats(1:2, "n_scenes", c(5, 6), period = "2023", n = c(5, 6))
  expect_equal(cl_stats_merge(a, b)$value, c(15, 18))

  # A maximum gap is neither additive nor averageable
  a <- cl_stats(1, "max_gap_days", 40, period = "2023", n = 10)
  b <- cl_stats(1, "max_gap_days", 90, period = "2023", n = 10)
  expect_equal(cl_stats_merge(a, b)$value, 90)

  # Fractions combine weighted by sample size, not as a mean of means
  a <- cl_stats(1, "cloud_fraction", 0.2, period = "2023", n = 90)
  b <- cl_stats(1, "cloud_fraction", 0.8, period = "2023", n = 10)
  expect_equal(cl_stats_merge(a, b)$value, 0.26, tolerance = 1e-9)
  expect_equal(cl_stats_merge(a, b)$n, 100)
})

test_that("every metric declares a combine rule", {
  m <- cl_metrics()
  expect_true(all(m$combine %in% c("sum", "wmean", "max")))
  expect_false(any(is.na(m$combine)))
})
