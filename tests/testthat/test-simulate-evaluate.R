test_that("the Markov chain preserves the marginal cloud probability", {
  d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
  for (p in c(0.3, 0.6, 0.85)) for (rho in c(0, 0.35, 0.7)) {
    m <- mean(vapply(1:200, function(s)
      mean(cl_simulate_series(d, p, rho, seed = s)$cloudy), numeric(1)))
    expect_equal(m, p, tolerance = 0.04,
                 label = sprintf("p=%.2f rho=%.2f", p, rho))
  }
})

test_that("persistence lengthens cloudy runs without changing the mean", {
  d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
  runs <- function(rho) mean(vapply(1:100, function(s) {
    r <- rle(cl_simulate_series(d, 0.6, rho, seed = s)$cloudy)
    max(c(0, r$lengths[r$values]))
  }, numeric(1)))
  expect_gt(runs(0.7), runs(0))
})

test_that("simulated coverage matches the request", {
  for (cv in c(0.1, 0.3, 0.6)) {
    expect_equal(mean(cl_simulate(128, 128, coverage = cv, opacity = 1,
                                  seed = 3)$cloud), cv, tolerance = 0.05)
  }
})

test_that("validation metrics are correct on a known confusion matrix", {
  truth <- c(rep(1, 70), rep(0, 30))
  pred  <- c(rep(1, 60), rep(0, 10), rep(1, 5), rep(0, 25))
  v <- cl_validate(pred, truth)
  i <- which(v$class == "1")
  expect_equal(v$precision[i], 60 / 65, tolerance = 1e-9)
  expect_equal(v$recall[i], 60 / 70, tolerance = 1e-9)
  expect_equal(v$iou[i], 60 / 75, tolerance = 1e-9)
  expect_equal(unname(attr(v, "overall")["overall_accuracy"]), 0.85, tolerance = 1e-9)
})

test_that("a good and a random detector are separated with significance", {
  set.seed(11)
  truth <- matrix(rbinom(2000, 1, 0.35), 40, 50)
  good <- truth; good[sample(2000, 50)] <- 1 - good[sample(2000, 50)]
  poor <- matrix(rbinom(2000, 1, 0.35), 40, 50)
  cmp <- cl_compare(list(good = good, poor = poor), truth, n_boot = 200)
  expect_equal(cmp$summary$method[1], "good")
  expect_lt(cmp$pairwise$p_value, 0.001)
  expect_lt(cmp$summary$lower[1], cmp$summary$accuracy[1])
})

test_that("ROC and calibration behave at the extremes", {
  set.seed(12); y <- rbinom(1000, 1, 0.4)
  expect_equal(attr(cl_roc(as.numeric(y), y), "auc"), 1, tolerance = 0.02)
  expect_lt(attr(cl_calibration(as.numeric(y), y), "brier"), 1e-9)
  expect_gt(attr(cl_calibration(rep(0.5, 1000), y), "brier"), 0.2)
})
