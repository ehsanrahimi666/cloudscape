test_that("phenological error grows and fits fail as cloud increases", {
  d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
  res <- lapply(c(0.2, 0.6, 0.9), function(p)
    cl_pheno_power(d, cloud_fraction = p, n_sim = 150, seed = 4)$summary)
  expect_true(all(diff(vapply(res, function(r) r$n_retained_median, numeric(1))) < 0))
  expect_true(all(diff(vapply(res, function(r) r$failure_rate, numeric(1))) > 0))
})

test_that("clustering harms retrieval at a fixed number of observations", {
  d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
  f <- function(tau) cl_pheno_power(d, 0.7, n_sim = 300, tau = tau,
                                    seed = 9)$summary
  a <- f(0); b <- f(30)
  expect_lte(abs(a$n_retained_median - b$n_retained_median), 5)
  expect_gt(b$failure_rate, a$failure_rate)
  expect_lt(b$p_within_all, a$p_within_all)
})

test_that("cloud fractions stay attached to their dates", {
  d <- seq(as.Date("2024-01-01"), as.Date("2024-12-31"), by = "4 days")
  cf <- ifelse(as.integer(format(d, "%m")) %in% 5:7, 0.9, 0.05)
  o <- c(seq(2, length(d), by = 2), seq(1, length(d), by = 2))
  a <- cl_pheno_power(d, cf, n_sim = 40, seed = 3)$summary
  b <- cl_pheno_power(d[o], cf[o], n_sim = 40, seed = 3)$summary
  expect_equal(a, b)
})

test_that("pixel retention keeps every acquisition at its clear probability", {
  d <- seq(as.Date("2024-01-01"), by = "3 days", length.out = 120)
  q <- seq(0.05, 0.95, length.out = 120)
  run <- getFromNamespace(".cs_clear_run", "cloudscape")
  set.seed(1)
  for (tau in c(0, 6)) {
    k <- replicate(3000, run(q, as.numeric(diff(d)), tau))
    expect_lt(max(abs(rowMeans(k) - q)), 0.04)
  }
  # Dependence between consecutive acquisitions weakens with elapsed time
  lag_cor <- function(gap) {
    k <- replicate(4000, run(c(0.5, 0.5), gap, tau = 5))
    stats::cor(k[1, ], k[2, ])
  }
  expect_gt(lag_cor(1), lag_cor(10))
  expect_lt(abs(lag_cor(1e6)), 0.05)
})

test_that("retention, coverage and tolerance outputs are consistent", {
  d <- seq(as.Date("2024-01-01"), as.Date("2024-12-31"), by = "5 days")
  cf <- rep(c(0.1, 0.5), length.out = length(d))
  vf <- rep(c(1, 0.7), length.out = length(d))
  p <- cl_pheno_power(d, cf, valid_fraction = vf, n_sim = 60, seed = 4)$summary
  expect_equal(p$n_retained_expected, sum(vf * (1 - cf)))
  c1 <- cl_pheno_power(d, cf, valid_fraction = vf, retention = "cell",
                       n_sim = 20, seed = 4)
  expect_equal(c1$summary$n_retained_expected, sum(vf * (1 - cf) >= 0.8))
  expect_true(all(c1$replicates$n_retained == sum(vf * (1 - cf) >= 0.8)))
  with(p, {
    expect_true(all(c(p_within_sos, p_within_peak, p_within_eos) <= 1 - failure_rate + 1e-12))
    expect_lte(p_within_all, min(p_within_sos, p_within_peak, p_within_eos))
  })
  expect_warning(cl_pheno_power(d, 0.3, persistence = 0.4, n_sim = 5, seed = 1),
                 "deprecated")
})

test_that("the reference curve is recovered from complete data", {
  f <- cl_pheno_fit(1:365, cl_pheno_curve(1:365, sos = 120, eos = 280))
  expect_true(f$converged)
  expect_lt(abs(f$sos - 120), 1)
  expect_lt(abs(f$eos - 280), 1)
})

test_that("double-logistic fits converge wherever the season falls", {
  for (s in c(20, 40, 120, 200)) {
    f <- cl_pheno_fit(1:365, cl_pheno_curve(1:365, sos = s, eos = s + 160))
    expect_true(f$converged)
    expect_lt(abs(f$sos - s), 1)
    expect_lt(abs(f$eos - (s + 160)), 1)
  }
})

test_that("early seasons under cloud loss rarely fail to converge", {
  d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "8 days")
  r <- cl_pheno_power(d, cloud_fraction = 0.4, curve = list(sos = 40, eos = 140),
                      n_sim = 200, seed = 11)$summary
  expect_lt(r$failure_rate, 0.10)
  expect_lte(r$insufficient_rate, r$failure_rate)
})

test_that("starting values are matched to parameters by name", {
  y <- cl_pheno_curve(1:365, sos = 40, eos = 200)
  st <- list(sos = 40, eos = 200, base = 0.15, amplitude = 0.6,
             slope_up = 0.12, slope_down = 0.10)
  f <- cl_pheno_fit(1:365, y, start = st)
  expect_true(f$converged)
  expect_lt(abs(f$sos - 40), 1)
  expect_error(cl_pheno_fit(1:365, y, start = list(sos = 40)), "lacks")
})

test_that("errors are reported for the end and the peak of the season", {
  d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
  r <- cl_pheno_power(d, cloud_fraction = 0, n_sim = 30, seed = 2)$summary
  expect_true(all(c("eos_bias", "peak_mae", "peak_bias") %in% names(r)))
  expect_true(is.finite(r$peak_mae))
  expect_lt(r$eos_mae, 3)
})
