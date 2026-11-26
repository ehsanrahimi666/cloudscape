# ---------------------------------------------------------------------------
# Module 8: phenological feasibility
#
# This module exists to answer the question a phenologist actually has, which
# is not "how cloudy is it here" but "how wrong will my green-up date be".
#
# The method is deliberately simple and transparent: take a known seasonal
# trajectory, sample it only on the dates when the cell was actually usable,
# refit, and measure the retrieval error. Repeating this over the cloud
# realisations observed in the archive converts a cloud statistic into a
# quantity in days, which is the unit in which phenological conclusions are
# actually stated.
# ---------------------------------------------------------------------------

#' Double-logistic seasonal trajectory
#'
#' The standard four-phase form used across land-surface phenology.
#'
#' @param doy Day of year.
#' @param base Winter baseline value.
#' @param amplitude Seasonal amplitude.
#' @param sos,eos Start and end of season, in days.
#' @param slope_up,slope_down Transition rates.
#' @return Numeric vector of index values.
#' @export
#' @examples
#' plot_ready <- cl_pheno_curve(1:365)
#' round(range(plot_ready), 3)
cl_pheno_curve <- function(doy, base = 0.15, amplitude = 0.6,
                           sos = 120, eos = 280,
                           slope_up = 0.12, slope_down = 0.10) {
  base + amplitude * (1 / (1 + exp(-slope_up * (doy - sos))) -
                        1 / (1 + exp(-slope_down * (doy - eos))))
}

#' Fit a seasonal trajectory and extract phenological metrics
#'
#' Fits a double-logistic curve or a smoothing spline to the observations, and
#' extracts the start and end of season as the days on which the fitted curve
#' crosses `threshold` of its amplitude before and after the peak.
#'
#' For the double logistic, the position of the season is located before the
#' nonlinear fit. With the transition dates and rates held fixed, the model is
#' linear in `base` and `amplitude`, so every candidate pair of start and end
#' dates on a five-day grid has a closed-form least-squares fit. The pair with
#' the smallest residual sum of squares starts the optimiser. If that fit does
#' not converge, the best pair at a start date at least 30 days away is tried,
#' and then `sos = 110`, `eos = 290`. The first converged fit is returned.
#'
#' @param doy Day of year of each observation.
#' @param value Observed index values.
#' @param model `"dbl_logistic"` or `"spline"`.
#' @param threshold Amplitude fraction defining SOS and EOS for the threshold
#'   extraction, following common practice.
#' @param start Optional named list of starting values for the double
#'   logistic, with elements `base`, `amplitude`, `sos`, `eos`, `slope_up` and
#'   `slope_down` in any order. Values outside the parameter bounds are moved
#'   to the nearest bound. When `NULL` (the default), starting values are
#'   derived from the data, as described above.
#' @return A list with `sos`, `eos`, `los`, `peak_doy`, `peak_value`,
#'   `converged` and `fit`.
#' @export
cl_pheno_fit <- function(doy, value, model = c("dbl_logistic", "spline"),
                         threshold = 0.5, start = NULL) {
  model <- match.arg(model)
  keep <- is.finite(doy) & is.finite(value)
  doy <- doy[keep]; value <- value[keep]
  fail <- list(sos = NA_real_, eos = NA_real_, los = NA_real_,
               peak_doy = NA_real_, peak_value = NA_real_,
               converged = FALSE, fit = NULL)
  if (length(doy) < 6L) return(fail)

  # Sub-daily evaluation grid.
  #
  # An integer grid floors the retrieval error at exactly one day, so once a
  # site has enough usable observations every metric reads 1.00 and the
  # measure stops discriminating. A real worked example returned
  # sos_mae = eos_mae = los_mae = 1.00 for all 16 cells, which is the grid
  # speaking, not the data.
  grid <- seq(1, 365, by = 0.1)
  if (model == "spline") {
    if (length(unique(doy)) < 5L) return(fail)
    fit <- tryCatch(stats::smooth.spline(doy, value,
                                         df = min(8, length(unique(doy)) - 1)),
                    error = function(e) NULL)
    if (is.null(fit)) return(fail)
    pred <- stats::predict(fit, grid)$y
  } else {
    fit <- .cs_fit_dbl_logistic(doy, value, start)
    if (is.null(fit)) return(fail)
    cf <- stats::coef(fit)
    pred <- cl_pheno_curve(grid, cf[["base"]], cf[["amplitude"]], cf[["sos"]],
                           cf[["eos"]], cf[["slope_up"]], cf[["slope_down"]])
  }

  lo <- min(pred); hi <- max(pred)
  if (!is.finite(hi - lo) || (hi - lo) < 1e-6) return(fail)
  lvl <- lo + threshold * (hi - lo)
  pk <- which.max(pred)
  up <- which(pred[seq_len(pk)] <= lvl)
  dn <- which(pred[pk:length(pred)] <= lvl)
  # Indices are positions on `grid`, so convert back to day of year rather
  # than using the index itself, which is only the same thing on a unit grid.
  sos <- if (length(up) && max(up) < length(grid)) grid[max(up) + 1L] else NA_real_
  eos <- if (length(dn)) grid[min(pk + min(dn) - 1L, length(grid))] else NA_real_
  list(sos = sos, eos = eos, los = eos - sos, peak_doy = grid[pk],
       peak_value = hi, converged = TRUE, fit = fit)
}

#' Phenological retrieval error under cloud loss
#'
#' Simulates the effect of missing observations on the retrieval of
#' phenological dates. In each replicate, a reference curve is sampled at the
#' acquisition dates that are retained, noise is added, the curve is refitted,
#' and the errors of the start of season, peak and end of season are recorded.
#'
#' @section Which observations are retained:
#' With `retention = "pixel"` (the default) each replicate is the series of a
#' pixel at a random location in the cell. Acquisition \eqn{i} is observed and
#' clear with probability \eqn{q_i = v_i (1 - c_i)}, where \eqn{c_i} is the cloud
#' fraction and \eqn{v_i} the valid share of the cell (1 for scene metadata, in
#' which cloud is assumed to be spread evenly over the footprint). The expected
#' number of retained observations is therefore \eqn{\sum_i q_i}, the expected
#' number of clear observations of a pixel reported by [cl_clear_obs()].
#' Clear and cloudy states are drawn from a latent Gaussian process whose
#' correlation between two acquisitions \eqn{\Delta t} days apart is
#' \eqn{\exp(-\Delta t / \tau)}: acquisition \eqn{i} is clear when the latent
#' value is below \eqn{\Phi^{-1}(q_i)}, which keeps every marginal probability
#' exact while losses cluster in time according to the elapsed time between
#' acquisitions. `tau = 0` gives independent losses.
#'
#' With `retention = "cell"`, an acquisition is retained when at least
#' `1 - threshold` of the cell was observed and cloud-free, as in
#' [cl_clear_obs()]; the retained set is then the same in every replicate and
#' only the noise varies.
#'
#' @section Success and failure:
#' A replicate succeeds when at least six observations are retained, the fit
#' converges, and the fitted curve has a start of season, a peak and an end of
#' season in that order. Errors are summarised over successful replicates.
#' Because errors conditional on success can look small when most replicates
#' fail, `p_within_*` report the probability, over all replicates, that the
#' replicate succeeded and the error of that date was at most `tolerance`
#' days; `p_within_all` requires all three dates to be within it.
#'
#' @param dates Acquisition dates available in the year, in any order.
#' @param cloud_fraction Cloud fraction for each acquisition, or a single value.
#' @param threshold Usability threshold for `retention = "cell"`.
#' @param curve Function of day-of-year giving the reference trajectory, or a
#'   list of arguments passed to [cl_pheno_curve()].
#' @param noise Observation noise standard deviation.
#' @param n_sim Number of replicates.
#' @param model Fitting model passed to [cl_pheno_fit()].
#' @param tau Decorrelation time of cloud loss in days; 0 gives independent
#'   losses.
#' @param valid_fraction Valid share of the cell for each acquisition, or a
#'   single value.
#' @param retention `"pixel"` or `"cell"`; see the section on retention.
#' @param tolerance Error tolerance in days for the `p_within_*` outputs.
#' @param persistence Deprecated. A lag-one autocorrelation between
#'   consecutive acquisitions; converted to `tau` with the median interval.
#' @param seed Random seed.
#'
#' @return A list with `summary` (a one-row data frame: numbers of acquisitions
#'   and retained observations, median absolute errors and median biases of
#'   start of season, peak, end of season and season length, the interquartile
#'   range of start of season, the failure and insufficient-data rates, and the
#'   `p_within_*` probabilities), `replicates`, and `reference`, the fit to the
#'   complete reference curve.
#' @export
#' @examples
#' d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "10 days")
#' r <- cl_pheno_power(d, cloud_fraction = 0.5, n_sim = 30, seed = 1)
#' r$summary[, c("n_retained_median", "sos_mae", "failure_rate", "p_within_all")]
cl_pheno_power <- function(dates, cloud_fraction = 0.4, threshold = 0.2,
                           curve = NULL, noise = 0.03, n_sim = 100L,
                           model = c("dbl_logistic", "spline"), tau = 1,
                           valid_fraction = 1, retention = c("pixel", "cell"),
                           tolerance = 5, persistence = NULL, seed = NULL) {
  model <- match.arg(model)
  retention <- match.arg(retention)
  dates <- as.Date(dates)
  n <- length(dates)
  cl_assert(n > 0L, "`dates` is empty.")
  cf <- .cs_recycle(cloud_fraction, n, "cloud_fraction")
  vf <- .cs_recycle(valid_fraction, n, "valid_fraction")
  cl_assert_fraction(cf, "cloud_fraction")
  cl_assert_fraction(vf, "valid_fraction")
  cl_assert_fraction(threshold, "threshold")
  cl_assert_number(noise, "noise", lower = 0, len = 1L)
  cl_assert_number(tolerance, "tolerance", lower = 0, len = 1L)
  # Every attribute of an acquisition travels with its date.
  o <- order(dates)
  dates <- dates[o]; cf <- cf[o]; vf <- vf[o]
  doy <- as.integer(format(dates, "%j"))
  gap <- as.numeric(diff(dates))
  if (!is.null(persistence)) {
    cl_assert_number(persistence, "persistence", lower = 0, upper = 0.999, len = 1L)
    dt <- if (length(gap)) stats::median(gap) else 1
    tau <- if (persistence > 0) -max(dt, 1) / log(persistence) else 0
    cl_warn("`persistence` is deprecated; using tau = ", signif(tau, 3),
            " days from the median interval. Supply `tau` instead.")
  }
  cl_assert_number(tau, "tau", lower = 0, len = 1L)
  if (!is.null(seed)) set.seed(seed)

  cargs <- if (is.list(curve)) curve else list()
  cfun <- if (is.function(curve)) curve else
    function(x) do.call(cl_pheno_curve, c(list(doy = x), cargs))
  ref <- cl_pheno_fit(1:365, cfun(1:365), model = model)
  if (!ref$converged) cl_abort("The reference curve could not be fitted; check `curve`.")

  q <- vf * (1 - cf)
  cell_keep <- q >= 1 - threshold - 1e-12
  reps <- do.call(rbind, lapply(seq_len(n_sim), function(i) {
    keep <- if (retention == "cell") cell_keep else .cs_clear_run(q, gap, tau)
    d <- doy[keep]
    if (length(d) < 6L) {
      return(data.frame(rep = i, n_retained = length(d), sos = NA_real_,
                        eos = NA_real_, los = NA_real_, peak = NA_real_,
                        converged = FALSE))
    }
    v <- cfun(d) + stats::rnorm(length(d), 0, noise)
    f <- cl_pheno_fit(d, v, model = model)
    data.frame(rep = i, n_retained = length(d), sos = f$sos, eos = f$eos,
               los = f$los, peak = f$peak_doy, converged = f$converged)
  }))
  reps$success <- reps$converged & is.finite(reps$sos) & is.finite(reps$eos) &
    is.finite(reps$peak) & reps$sos < reps$peak & reps$peak < reps$eos

  ok <- reps$success
  med <- function(x) if (any(ok)) stats::median(x[ok]) else NA_real_
  within <- function(x, r) ok & abs(x - r) <= tolerance
  w_sos <- within(reps$sos, ref$sos)
  w_peak <- within(reps$peak, ref$peak_doy)
  w_eos <- within(reps$eos, ref$eos)
  summ <- data.frame(
    n_acquisitions = n,
    n_retained_median = stats::median(reps$n_retained),
    n_retained_expected = if (retention == "cell") sum(cell_keep) else sum(q),
    reference_sos = ref$sos, reference_peak = ref$peak_doy,
    reference_eos = ref$eos,
    sos_mae = med(abs(reps$sos - ref$sos)),
    sos_iqr = if (any(ok)) stats::IQR(reps$sos[ok]) else NA_real_,
    peak_mae = med(abs(reps$peak - ref$peak_doy)),
    eos_mae = med(abs(reps$eos - ref$eos)),
    los_mae = med(abs(reps$los - ref$los)),
    sos_bias = med(reps$sos - ref$sos),
    peak_bias = med(reps$peak - ref$peak_doy),
    eos_bias = med(reps$eos - ref$eos),
    failure_rate = mean(!ok),
    insufficient_rate = mean(reps$n_retained < 6L),
    p_within_sos = mean(w_sos), p_within_peak = mean(w_peak),
    p_within_eos = mean(w_eos), p_within_all = mean(w_sos & w_peak & w_eos),
    tolerance = tolerance, tau = tau, retention = retention,
    n_sim = n_sim, stringsAsFactors = FALSE
  )
  list(summary = summ, replicates = reps, reference = ref)
}

#' Map phenological retrieval error across grid cells
#'
#' Applies [cl_pheno_power()] cell by cell using the actual acquisition dates,
#' cloud fractions and, where present, valid shares recorded for each cell,
#' turning an observation table into a map of simulated phenological error.
#'
#' @param obs A `cl_obs` table.
#' @param year Year to analyse; defaults to the most frequent year present.
#' @param n_sim Replicates per cell.
#' @param ... Passed to [cl_pheno_power()].
#' @return A `cl_stats` table with metric `sos_error_days`, carrying a
#'   `details` attribute with the full per-cell summaries.
#' @export
cl_pheno_map <- function(obs, year = NULL, n_sim = 50L, ...) {
  cl_assert(inherits(obs, "cl_obs"), "`obs` must be a cl_obs table.")
  yr <- format(obs$date, "%Y")
  if (is.null(year)) year <- names(sort(table(yr), decreasing = TRUE))[1L]
  d <- obs[yr == as.character(year), , drop = FALSE]
  if (!nrow(d)) cl_abort("No observations in year ", year, ".")
  sp <- split(d, d$cell)
  det <- do.call(rbind, lapply(names(sp), function(k) {
    s <- sp[[k]]
    vf <- if (is.null(s$valid_fraction)) 1 else s$valid_fraction
    vf[is.na(vf)] <- 1
    r <- cl_pheno_power(s$date, s$cloud_fraction, valid_fraction = vf,
                        n_sim = n_sim, ...)
    cbind(cell = as.integer(k), r$summary)
  }))
  out <- cl_stats(det$cell, "sos_error_days", det$sos_mae,
                  period = as.character(year), n = det$n_acquisitions,
                  denominator = "cell-year")
  attr(out, "details") <- det
  out
}

# Clear states of a pixel at irregular acquisition times. A latent Gaussian
# process with correlation exp(-gap / tau) between consecutive acquisitions is
# thresholded at the quantile of each clear probability, so every marginal is
# exact and the dependence weakens with the elapsed time between acquisitions.
.cs_clear_run <- function(q, gap, tau) {
  n <- length(q)
  z <- numeric(n)
  z[1L] <- stats::rnorm(1L)
  if (n > 1L) {
    r <- if (tau > 0) exp(-gap / tau) else rep(0, n - 1L)
    e <- stats::rnorm(n - 1L)
    for (i in 2:n) z[i] <- r[i - 1L] * z[i - 1L] + sqrt(1 - r[i - 1L]^2) * e[i - 1L]
  }
  z < stats::qnorm(q)
}

.cs_recycle <- function(x, n, name) {
  if (length(x) == 1L) return(rep(x, n))
  cl_assert(length(x) == n, "`", name, "` must have length 1 or the length of `dates`.")
  x
}


# Double-logistic fitting.
#
# nls(algorithm = "port") applies `lower` and `upper` by position, so every
# start list is put into .CS_DBL_PARS order before fitting; a list supplied in
# another order would otherwise receive another parameter's bounds.
.CS_DBL_PARS <- c("base", "amplitude", "sos", "eos", "slope_up", "slope_down")
.CS_DBL_LOWER <- c(-1, 1e-3, 1, 1, 1e-3, 1e-3)
.CS_DBL_UPPER <- c(2, 3, 365, 400, 2, 2)

.cs_fit_dbl_logistic <- function(doy, value, start = NULL) {
  starts <- if (is.null(start)) .cs_dbl_starts(doy, value) else list(start)
  for (st in starts) {
    fit <- .cs_nls_dbl(doy, value, st)
    if (!is.null(fit)) return(fit)
  }
  NULL
}

.cs_nls_dbl <- function(doy, value, start) {
  start <- as.list(start)
  miss <- setdiff(.CS_DBL_PARS, names(start))
  cl_assert(!length(miss), "`start` lacks ", paste(miss, collapse = ", "), ".")
  st <- unlist(start[.CS_DBL_PARS])
  cl_assert(is.numeric(st) && length(st) == length(.CS_DBL_PARS) &&
              all(is.finite(st)),
            "`start` must hold one finite number per parameter.")
  st <- as.list(pmin(pmax(st, .CS_DBL_LOWER), .CS_DBL_UPPER))
  fit <- suppressWarnings(tryCatch(
    stats::nls(value ~ cl_pheno_curve(doy, base, amplitude, sos, eos,
                                      slope_up, slope_down),
               start = st,
               control = stats::nls.control(maxiter = 200, warnOnly = TRUE),
               algorithm = "port", lower = .CS_DBL_LOWER, upper = .CS_DBL_UPPER),
    error = function(e) NULL))
  if (is.null(fit) || !isTRUE(fit$convInfo$isConv)) return(NULL)
  fit
}

# Candidate starting values, best first. For fixed transition dates and rates
# the double logistic is linear in base and amplitude, so each (sos, eos) pair
# on the grid has a closed-form least-squares fit, and the reduction in the
# residual sum of squares it achieves is s_gy^2 / s_gg, computed for all pairs
# at once from centred cross-products.
.cs_dbl_starts <- function(doy, value, slope = 0.1, step = 5, min_los = 20,
                           separation = 30) {
  q <- stats::quantile(value, c(0.1, 0.9), names = FALSE)
  fixed <- list(base = q[1], amplitude = q[2] - q[1], sos = 110, eos = 290,
                slope_up = slope, slope_down = slope)
  sos_c <- seq(1, 365, by = step)
  eos_c <- seq(1, 400, by = step)
  logistic <- function(x) 1 / (1 + exp(-x))
  u <- logistic(slope * outer(doy, sos_c, "-"))
  d <- logistic(slope * outer(doy, eos_c, "-"))
  mu_u <- colMeans(u)
  mu_d <- colMeans(d)
  u <- sweep(u, 2L, mu_u)
  d <- sweep(d, 2L, mu_d)
  yc <- value - mean(value)
  s_gy <- outer(drop(crossprod(u, yc)), drop(crossprod(d, yc)), "-")
  s_gg <- outer(colSums(u^2), colSums(d^2), "+") - 2 * crossprod(u, d)
  ok <- outer(sos_c, eos_c, function(s, e) e - s >= min_los) &
    s_gg > 1e-12 & s_gy > 0
  if (!any(ok)) return(list(fixed))
  gain <- ifelse(ok, s_gy^2 / s_gg, -Inf)
  candidate <- function(i) {
    j <- (i - 1L) %% length(sos_c) + 1L
    k <- (i - 1L) %/% length(sos_c) + 1L
    amp <- s_gy[i] / s_gg[i]
    list(base = mean(value) - amp * (mu_u[j] - mu_d[k]), amplitude = amp,
         sos = sos_c[j], eos = eos_c[k], slope_up = slope, slope_down = slope)
  }
  best <- candidate(which.max(gain))
  far <- matrix(abs(sos_c - best$sos) >= separation,
                length(sos_c), length(eos_c))
  out <- list(best)
  if (any(ok & far)) {
    out <- c(out, list(candidate(which.max(ifelse(far, gain, -Inf)))))
  }
  c(out, list(fixed))
}
