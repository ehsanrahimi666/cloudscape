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
  expect_equal(a$n_usable_median, b$n_usable_median, tolerance = 5)
  expect_gt(b$failure_rate, a$failure_rate)
})

test_that("the reference curve is recovered from complete data", {
  f <- cl_pheno_fit(1:365, cl_pheno_curve(1:365, sos = 120, eos = 280))
  expect_true(f$converged)
  expect_equal(f$sos, 120, tolerance = 5)
  expect_equal(f$eos, 280, tolerance = 5)
})
