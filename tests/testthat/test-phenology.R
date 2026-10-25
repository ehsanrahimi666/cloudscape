test_that("phenological error grows and fits fail as cloud increases", {
  d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
  res <- lapply(c(0.2, 0.6, 0.9), function(p)
    cl_pheno_power(d, cloud_fraction = p, n_sim = 150, seed = 4)$summary)
  expect_true(all(diff(vapply(res, function(r) r$n_usable_median, numeric(1))) < 0))
  expect_true(all(diff(vapply(res, function(r) r$failure_rate, numeric(1))) > 0))
})

test_that("clustering harms retrieval at a fixed number of observations", {
  d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
  f <- function(rho) cl_pheno_power(d, 0.7, n_sim = 300, persistence = rho,
                                    seed = 9)$summary
  a <- f(0); b <- f(0.7)
  expect_lte(abs(a$n_usable_median - b$n_usable_median), 5)
  expect_gt(b$failure_rate, a$failure_rate)
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
