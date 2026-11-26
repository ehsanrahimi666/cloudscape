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

test_that("the Matthews correlation does not overflow on large masks", {
  set.seed(1)
  truth <- matrix(rbinom(512 * 512, 1, 0.5), 512, 512)
  pred <- truth
  flip <- sample(length(truth), 0.1 * length(truth)); pred[flip] <- 1 - pred[flip]
  v <- cl_validate(pred, truth)
  tab <- attr(v, "confusion")
  tp <- tab[2, 2]; tn <- tab[1, 1]; fp <- tab[2, 1]; fn <- tab[1, 2]
  mcc <- (tp * tn - fp * fn) / sqrt((tp + fp) * (tp + fn) * (tn + fp) * (tn + fn))
  expect_equal(attr(v, "overall")[["mcc"]], mcc)
  expect_gt(mcc, 0.7)
})

test_that("the AUC is exact for binary and saturating predictions", {
  set.seed(4)
  y <- rbinom(2000, 1, 0.5)
  p <- y; j <- sample(2000, 400); p[j] <- 1 - p[j]
  tpr <- mean(p[y == 1] == 1); fpr <- mean(p[y == 0] == 1)
  expect_equal(attr(cl_roc(p, y), "auc"), (1 + tpr - fpr) / 2)
  s <- pmin(1, 0.6 * y + runif(2000) * 0.6)
  exact <- mean(outer(s[y == 1], s[y == 0], ">") + 0.5 * outer(s[y == 1], s[y == 0], "=="))
  expect_equal(attr(cl_roc(s, y), "auc"), exact)
})

test_that("bootstrap intervals account for resampling with replacement", {
  set.seed(2)
  n <- 10000
  truth <- rbinom(n, 1, 0.4)
  a <- truth; i <- sample(n, 1000); a[i] <- 1 - a[i]
  cmp <- cl_compare(list(a = a), truth, n_boot = 1000)
  width <- cmp$summary$upper - cmp$summary$lower
  binom <- 2 * qnorm(0.975) * sqrt(0.9 * 0.1 / n)
  expect_lt(abs(width / binom - 1), 0.15)
  blocks <- rep(seq_len(100), each = 100)
  cmb <- cl_compare(list(a = a), truth, n_boot = 1000, block = blocks)
  expect_lt(abs((cmb$summary$upper - cmb$summary$lower) / binom - 1), 0.35)
})

test_that("logical masks are compared with 0/1 references", {
  tab <- cl_confusion(c(TRUE, FALSE, TRUE, TRUE), c(1, 0, 1, 0))
  expect_equal(sum(tab), 4)
  expect_equal(unname(tab["1", "0"]), 1)
})

test_that("probability-only masksets are thresholded at their own threshold", {
  ma <- cl_maskset(probability = matrix(c(0.01, 0.05, 0.2, 0.95), 2),
                   method = "user", threshold = 0.5)
  mb <- matrix(c(0, 0, 0, 1), 2)
  expect_equal(cl_agreement(list(a = ma, b = mb))$agreement, matrix(c(0, 0, 0, 1), 2))
  d <- cl_disagreement(list(a = matrix(c(1, 0, 1, 0), 2), b = matrix(c(1, 1, 0, 0), 2)),
                       strata = matrix(c(1, 1, 2, NA), 2))
  expect_equal(d$by_stratum$n, c(2, 1))
  expect_false(anyNA(d$by_stratum$mean_agreement))
})
