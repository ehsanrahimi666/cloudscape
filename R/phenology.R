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
#' @param doy Day of year of each observation.
#' @param value Observed index values.
#' @param model `"dbl_logistic"` or `"spline"`.
#' @param threshold Amplitude fraction defining SOS and EOS for the threshold
#'   extraction, following common practice.
#' @param start Optional named list of starting values.
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
    st <- start %||% list(base = stats::quantile(value, 0.1, names = FALSE),
                          amplitude = diff(stats::quantile(value, c(0.1, 0.9),
                                                           names = FALSE)),
                          sos = 110, eos = 290, slope_up = 0.1, slope_down = 0.1)
    fit <- suppressWarnings(tryCatch(
      stats::nls(value ~ cl_pheno_curve(doy, base, amplitude, sos, eos,
                                        slope_up, slope_down),
                 start = st,
                 control = stats::nls.control(maxiter = 200, warnOnly = TRUE),
                 algorithm = "port",
                 lower = c(-1, 1e-3, 1, 1, 1e-3, 1e-3),
                 upper = c(2, 3, 365, 400, 2, 2)),
      error = function(e) NULL))
    if (is.null(fit)) return(fail)
    if (!isTRUE(fit$convInfo$isConv)) return(fail)
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

#' Phenological retrieval error under realistic cloud loss
#'
#' Simulates the effect of missing observations on phenological metric
#' retrieval. For each replicate, a reference curve is sampled at the supplied
#' acquisition dates, observations are dropped according to their cloud
#' fraction, noise is added, the curve is refitted, and the retrieval error is
#' recorded.
#'
#' The output is directly interpretable: an expected absolute error in days for
#' start of season, end of season and length of season, together with the
#' failure rate, meaning the fraction of replicates in which the fit did not
#' converge at all. In heavily clouded regions the failure rate is often the
#' more important number, because a study there does not produce a biased
#' estimate, it produces no estimate.
#'
#' @param dates Acquisition dates available in the year.
#' @param cloud_fraction Cloud fraction for each acquisition, or a single value.
#' @param threshold Maximum cloud fraction for a usable observation.
#' @param curve Function of day-of-year giving the reference trajectory, or a
#'   list of arguments passed to [cl_pheno_curve()].
#' @param noise Observation noise standard deviation.
#' @param n_sim Number of replicates.
#' @param model Fitting model passed to [cl_pheno_fit()].
#' @param persistence Lag-1 autocorrelation of cloud loss, in \[0, 1), using
#'   the same chain as [cl_simulate_series()]. 0 gives independent loss, which
#'   is unrealistic and optimistic: independent loss thins the series uniformly
#'   and almost never removes a whole transition, whereas clustered loss
#'   regularly removes green-up entirely.
#' @param seed Random seed.
#'
#' @return A list with `summary` (a one-row data frame of median absolute
#'   errors, interquartile ranges and failure rate) and `replicates`.
#' @export
#' @examples
#' d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "10 days")
#' r <- cl_pheno_power(d, cloud_fraction = 0.5, n_sim = 30, seed = 1)
#' r$summary[, c("n_usable_median", "sos_mae", "failure_rate")]
cl_pheno_power <- function(dates, cloud_fraction = 0.4, threshold = 0.2,
                           curve = NULL, noise = 0.03, n_sim = 100L,
                           model = c("dbl_logistic", "spline"),
                           persistence = 0.35, seed = NULL) {
  model <- match.arg(model)
  if (!is.null(seed)) set.seed(seed)
  dates <- sort(as.Date(dates))
  doy <- as.integer(format(dates, "%j"))
  n <- length(dates)
  cf <- if (length(cloud_fraction) == 1L) rep(cloud_fraction, n) else cloud_fraction
  cl_assert(length(cf) == n, "`cloud_fraction` must be length 1 or length(dates).")

  cargs <- if (is.list(curve)) curve else list()
  cfun <- if (is.function(curve)) curve else
    function(x) do.call(cl_pheno_curve, c(list(doy = x), cargs))

  ref <- cl_pheno_fit(1:365, cfun(1:365), model = model)
  if (!ref$converged) cl_abort("The reference curve could not be fitted; check `curve`.")

  reps <- do.call(rbind, lapply(seq_len(n_sim), function(i) {
    # Cloud loss is generated as a persistent two-state chain rather than as
    # independent draws, because clustering is what actually destroys a
    # phenological retrieval: it removes contiguous stretches of the season
    # instead of thinning the series uniformly.
    usable <- .cs_usable_run(cf, threshold, persistence)
    d <- doy[usable]
    if (length(d) < 6L) {
      return(data.frame(rep = i, n_usable = length(d), sos = NA_real_,
                        eos = NA_real_, los = NA_real_, converged = FALSE))
    }
    v <- cfun(d) + stats::rnorm(length(d), 0, noise)
    f <- cl_pheno_fit(d, v, model = model)
    data.frame(rep = i, n_usable = length(d), sos = f$sos, eos = f$eos,
               los = f$los, converged = f$converged)
  }))

  err <- function(x, r) abs(x - r)
  # Also record how often the green-up transition itself was unobserved, which
  # is the mechanism behind most large errors.
  ok <- reps$converged & is.finite(reps$sos)
  summ <- data.frame(
    n_acquisitions = n,
    n_usable_median = stats::median(reps$n_usable),
    reference_sos = ref$sos, reference_eos = ref$eos,
    sos_mae = stats::median(err(reps$sos[ok], ref$sos), na.rm = TRUE),
    sos_iqr = stats::IQR(reps$sos[ok], na.rm = TRUE),
    eos_mae = stats::median(err(reps$eos[ok], ref$eos), na.rm = TRUE),
    los_mae = stats::median(err(reps$los[ok], ref$los), na.rm = TRUE),
    sos_bias = stats::median(reps$sos[ok] - ref$sos, na.rm = TRUE),
    failure_rate = mean(!ok),
    n_sim = n_sim, stringsAsFactors = FALSE
  )
  list(summary = summ, replicates = reps, reference = ref)
}

#' Map phenological retrieval error across grid cells
#'
#' Applies [cl_pheno_power()] cell by cell using the actual acquisition dates
#' and cloud fractions recorded for each cell, turning an observation table into
#' a map of expected phenological uncertainty.
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
    r <- tryCatch(cl_pheno_power(s$date, s$cloud_fraction, n_sim = n_sim, ...),
                  error = function(e) NULL)
    if (is.null(r)) return(NULL)
    cbind(cell = as.integer(k), r$summary)
  }))
  if (is.null(det)) cl_abort("No cell had enough acquisitions to simulate.")
  out <- cl_stats(det$cell, "sos_error_days", det$sos_mae,
                  period = as.character(year), n = det$n_acquisitions,
                  denominator = "cell-year")
  attr(out, "details") <- det
  out
}


# Persistent availability. Shares .cs_markov2() with cl_simulate_series() so
# that simulated and analysed cloud behave identically, and initialises from
# the stationary law rather than from an arbitrary clear start, which would
# otherwise bias short series towards the initial state.
.cs_usable_run <- function(cf, threshold, persistence = 0.35) {
  n <- length(cf)
  out <- logical(n)
  prev_cloudy <- stats::runif(1) < mean(cf)
  for (i in seq_len(n)) {
    if (cf[i] <= threshold) {
      out[i] <- TRUE
      prev_cloudy <- FALSE
      next
    }
    tp <- .cs_markov2(cf[i], persistence)
    cloudy <- stats::runif(1) < (if (prev_cloudy) tp$p11 else tp$p01)
    out[i] <- !cloudy
    prev_cloudy <- cloudy
  }
  out
}
