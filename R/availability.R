# ---------------------------------------------------------------------------
# Module 7: availability and clear-observation statistics
#
# The common currency of this module is the *observation table* (`cl_obs`,
# defined in classes.R): one row per acquisition intersecting a grid cell,
# with a cloud fraction attached. Tier A
# builds it from catalogue metadata, tier B from quality layers, tier C from
# computed masks. Everything downstream is tier-agnostic, so a user can start
# with a fast global metadata answer and refine the same analysis with pixel
# evidence without changing their code.
# ---------------------------------------------------------------------------

#' Probability that a pixel in a cell is clear
#'
#' Converting a scene-level cloud fraction into a per-pixel clear probability
#' requires an assumption, and the choice of assumption matters more than most
#' users expect.
#'
#' `"independent"` sets `P(clear) = 1 - cloud_fraction`. This treats cloud as
#' spatially random within the footprint. Cloud is strongly clustered, so this
#' systematically **overestimates** the number of usable observations for a
#' specific location: a scene reported as 50 percent cloudy is far more often
#' half covered by one cloud deck than uniformly half-obscured. It is the
#' assumption implicit in any analysis that uses scene cloud percentage as a
#' usability measure, and it is why tier A results should be read as an upper
#' bound.
#'
#' `"clustered"` applies a Beta-distributed correction with concentration
#' `kappa`, reproducing the observed U-shaped distribution of pixel-level cloud
#' occurrence within partly cloudy scenes.
#'
#' `"empirical"` requires tier `"qa"` or `"mask"` data, where the fraction was
#' measured for the cell rather than inferred from the scene, and applies no
#' correction.
#'
#' @param obs A `cl_obs` table.
#' @param model One of `"independent"`, `"clustered"`, `"empirical"`.
#' @param kappa Beta concentration for `"clustered"`; lower means more
#'   clustered. Values near 0.5 match reported pixel-scale behaviour.
#' @return Numeric vector of clear probabilities, one per row of `obs`.
#' @export
cl_clear_prob <- function(obs, model = c("independent", "clustered", "empirical"),
                          kappa = 0.5) {
  model <- match.arg(model)
  f <- obs$cloud_fraction
  tier <- attr(obs, "tier") %||% "metadata"
  if (model == "empirical") {
    if (identical(tier, "metadata")) {
      cl_abort("model = \"empirical\" needs tier \"qa\" or \"mask\" data. ",
               "Scene metadata cannot distinguish where within the footprint ",
               "the cloud was.")
    }
    return(1 - f)
  }
  if (model == "independent") {
    if (identical(tier, "metadata")) {
      cl_msg("Note: tier 'metadata' with model 'independent' gives an optimistic ",
             "upper bound on clear observations. See ?cl_clear_prob.")
    }
    return(1 - f)
  }
  # Clustered: P(pixel clear) under a Beta(a, b) mixture with mean 1 - f.
  # The mean is preserved; the variance inflation reduces the effective number
  # of *usable* observations once a usability threshold is applied downstream.
  mu <- 1 - f
  a <- pmax(1e-6, mu * kappa)
  b <- pmax(1e-6, (1 - mu) * kappa)
  # Probability the pixel is more than 90 percent clear
  stats::pbeta(0.9, a, b, lower.tail = FALSE)
}

#' Clear observation counts per cell and period
#'
#' @param obs A `cl_obs` table.
#' @param by Period granularity: `"year"`, `"month"`, `"season"` or `"all"`.
#' @param threshold Maximum cloud fraction for an observation to count as
#'   usable.
#' @param model Clear-probability model, see [cl_clear_prob()].
#' @param grid Optional `cl_grid` recorded on the output.
#' @return A `cl_stats` table with metrics `n_scenes`, `n_clear_obs`,
#'   `cloud_fraction` and `p_clear`.
#' @export
#' @examples
#' set.seed(1)
#' o <- cl_obs(cell = rep(1:2, each = 40),
#'             date = rep(seq(as.Date("2023-01-01"), by = "9 days", length.out = 40), 2),
#'             cloud_fraction = c(runif(40, 0, .4), runif(40, .5, 1)),
#'             sensor = "sentinel-2-msi")
#' summary(cl_clear_obs(o, by = "year"))
cl_clear_obs <- function(obs, by = c("year", "month", "season", "all"),
                         threshold = 0.2,
                         model = c("independent", "clustered", "empirical"),
                         grid = NULL) {
  by <- match.arg(by)
  model <- match.arg(model)
  cl_assert(inherits(obs, "cl_obs"), "`obs` must be a cl_obs table.")
  cl_assert_fraction(threshold, "threshold")
  if (!nrow(obs)) cl_abort("`obs` is empty.")

  obs$.period <- .cs_period(obs$date, by)
  obs$.clear <- obs$cloud_fraction <= threshold
  obs$.pclear <- cl_clear_prob(obs, model)

  key <- paste(obs$cell, obs$.period, obs$sensor, sep = "\r")
  sp <- split(seq_len(nrow(obs)), key)
  parts <- do.call(rbind, strsplit(names(sp), "\r", fixed = TRUE))

  agg <- function(fun) vapply(sp, function(i) fun(obs[i, , drop = FALSE]), numeric(1))
  n_scenes <- agg(function(d) nrow(d))
  n_clear  <- agg(function(d) sum(d$.clear, na.rm = TRUE))
  cf       <- agg(function(d) mean(d$cloud_fraction, na.rm = TRUE))
  cf_se    <- agg(function(d) stats::sd(d$cloud_fraction, na.rm = TRUE) / sqrt(max(1, nrow(d))))
  pc       <- agg(function(d) mean(d$.pclear, na.rm = TRUE))

  denom <- switch(by, year = "cell-year", month = "cell-month",
                  season = "cell-season", all = "cell")
  cells <- as.integer(parts[, 1]); per <- parts[, 2]; sen <- parts[, 3]

  out <- rbind(
    cl_stats(cells, "n_scenes", n_scenes, per, sen, n = n_scenes, denominator = denom),
    cl_stats(cells, "n_clear_obs", n_clear, per, sen, n = n_scenes, denominator = denom),
    cl_stats(cells, "cloud_fraction", cf, per, sen, n = n_scenes, se = cf_se,
             denominator = denom),
    cl_stats(cells, "p_clear", pc, per, sen, n = n_scenes, denominator = denom)
  )
  structure(out, class = c("cl_stats", "data.frame"), grid = grid,
            manifest = cl_manifest(NULL, tier = attr(obs, "tier"),
                                   clear_model = model, threshold = threshold,
                                   by = by))
}

.cs_period <- function(d, by) {
  switch(by,
    year   = format(d, "%Y"),
    month  = format(d, "%Y-%m"),
    season = paste0(format(d, "%Y"), "-S",
                    c(1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4)[as.integer(format(d, "%m"))]),
    all    = "all"
  )
}

#' Cloud-gap statistics
#'
#' Mean cloud cover is a poor summary of whether a time series is workable.
#' What breaks a phenology retrieval is not the average, it is the longest
#' stretch with no usable observation. `cl_gaps()` reports that stretch, its
#' distribution, and the return period of gaps exceeding a stated length.
#'
#' Gaps at the boundaries of the analysis window are included by default,
#' because a cell whose first clear observation arrives in April has genuinely
#' lost the spring green-up regardless of how many observations follow.
#'
#' @param obs A `cl_obs` table.
#' @param threshold Maximum cloud fraction for a usable observation.
#' @param by Period granularity for reporting.
#' @param include_edges Count the intervals from period start to first clear
#'   observation and from last clear observation to period end.
#' @param critical Gap length in days whose exceedance frequency is reported.
#' @return A `cl_stats` table with `max_gap_days` and `mean_gap_days`, carrying
#'   an attribute `exceedance` giving the fraction of periods per cell in which
#'   `critical` was exceeded.
#' @export
cl_gaps <- function(obs, threshold = 0.2, by = c("year", "all", "season"),
                    include_edges = TRUE, critical = 30) {
  by <- match.arg(by)
  cl_assert(inherits(obs, "cl_obs"), "`obs` must be a cl_obs table.")
  if (!nrow(obs)) cl_abort("`obs` is empty.")
  obs$.period <- .cs_period(obs$date, by)
  obs$.clear <- obs$cloud_fraction <= threshold

  # Enumerate every cell-period that had *any* acquisition, not only those with
  # a usable one. A cell that was never clear all year has the worst possible
  # gap statistics, so dropping it would remove exactly the cases the analysis
  # exists to identify and would bias every summary optimistically.
  key <- paste(obs$cell, obs$.period, sep = "\r")
  sp <- split(obs, key)
  parts <- do.call(rbind, strsplit(names(sp), "\r", fixed = TRUE))

  period_bounds <- function(lab) {
    if (by == "all") {
      return(c(min(obs$date), max(obs$date)))
    }
    yr <- substr(lab, 1, 4)
    if (by == "year") {
      return(c(as.Date(paste0(yr, "-01-01")), as.Date(paste0(yr, "-12-31"))))
    }
    s <- as.integer(sub(".*-S", "", lab))
    m0 <- (s - 1L) * 3L + 1L
    st <- as.Date(sprintf("%s-%02d-01", yr, m0))
    c(st, seq(st, by = "3 months", length.out = 2L)[2L] - 1L)
  }

  res <- lapply(seq_along(sp), function(k) {
    d <- sp[[k]]
    dts <- sort(unique(d$date[d$.clear]))
    bnd <- period_bounds(d$.period[1L])
    span <- as.numeric(bnd[2L] - bnd[1L]) + 1
    if (!length(dts)) {
      # No usable observation: the gap is the whole period.
      return(c(max = span, mean = span, n = 0,
               exceed = as.numeric(span > critical), n_acq = nrow(d)))
    }
    g <- if (length(dts) > 1L) as.numeric(diff(dts)) else numeric(0)
    if (include_edges) {
      g <- c(as.numeric(dts[1L] - bnd[1L]), g,
             as.numeric(bnd[2L] - dts[length(dts)]))
    }
    if (!length(g)) g <- span
    c(max = max(g), mean = mean(g), n = length(dts),
      exceed = as.numeric(max(g) > critical), n_acq = nrow(d))
  })
  m <- do.call(rbind, res)
  cells <- as.integer(parts[, 1]); per <- parts[, 2]
  sens <- vapply(sp, function(d) {
    u <- unique(d$sensor); if (length(u) == 1L) u else "MULTI"
  }, character(1), USE.NAMES = FALSE)
  denom <- switch(by, year = "cell-year", season = "cell-season", all = "cell")

  out <- rbind(
    cl_stats(cells, "max_gap_days", m[, "max"], per, sens,
             n = m[, "n_acq"], denominator = denom),
    cl_stats(cells, "mean_gap_days", m[, "mean"], per, sens,
             n = m[, "n_acq"], denominator = denom),
    cl_stats(cells, "n_clear_obs", m[, "n"], per, sens,
             n = m[, "n_acq"], denominator = denom)
  )
  exc <- tapply(m[, "exceed"], cells, mean)
  structure(out, class = c("cl_stats", "data.frame"),
            exceedance = data.frame(cell = as.integer(names(exc)),
                                    p_exceed = as.numeric(exc),
                                    critical_days = critical,
                                    stringsAsFactors = FALSE),
            manifest = cl_manifest(NULL, threshold = threshold,
                                   include_edges = include_edges,
                                   critical_days = critical))
}

#' Estimate the temporal persistence of cloud from an observation record
#'
#' Cloud occurrence is autocorrelated in time, and that autocorrelation degrades
#' time-series retrievals largely independently of how much cloud there is: it
#' concentrates observation loss into contiguous runs that can remove an entire
#' seasonal transition while leaving the annual observation count almost
#' unchanged. Quantifying it therefore requires its own estimator.
#'
#' For the two-state chain used throughout cloudscape, with marginal cloud
#' probability \eqn{p} and lag-1 autocorrelation \eqn{\rho},
#' \deqn{p_{11} = p + (1-p)\rho, \qquad p_{01} = p(1-\rho),}
#' so that \eqn{\rho = p_{11} - p_{01}}. The estimator is therefore the
#' difference between the empirical probability that a cloudy acquisition is
#' followed by another cloudy one and the probability that a clear acquisition
#' is followed by a cloudy one. This requires no model fitting and is
#' consistent for a stationary chain observed at a regular interval.
#'
#' Acquisitions are irregularly spaced, so transitions are counted only between
#' consecutive acquisitions of the same sensor and only when the interval falls
#' within `max_interval` days. The median interval actually used is returned so
#' that \eqn{\rho} can be interpreted per unit time rather than per
#' acquisition.
#'
#' @section Attenuation:
#' Misclassification affects the estimate. Whether an acquisition is usable at
#' a cell is inferred by thresholding a cloud fraction, and with tier
#' `"metadata"` that fraction describes the whole scene. Misclassification that
#' is independent of the true state and between acquisitions multiplies the
#' autocovariance by \eqn{(1 - \alpha - \beta)^2}, where \eqn{\alpha} and
#' \eqn{\beta} are the two misclassification rates, and so attenuates the
#' autocorrelation towards zero; in simulation a true \eqn{\rho} of 0.6 is
#' recovered as approximately 0.41. Errors that are themselves persistent or
#' seasonal, such as commission over winter snow, violate that condition and
#' can bias the estimate in either direction, so it is not a bound in general.
#' Tier `"qa"` data from [cl_qa_obs()] measure the cell directly.
#'
#' @param obs A `cl_obs` table.
#' @param threshold Cloud fraction above which an acquisition counts as cloudy.
#' @param max_interval Longest gap in days across which a transition is still
#'   counted. Pairs separated by more than this are dropped, because a
#'   transition across a three-month gap carries no information about
#'   persistence at the acquisition scale.
#' @param min_pairs Minimum usable transitions required to report an estimate.
#' @param by Period granularity, or `"all"` to pool the whole record.
#'
#' @return A data frame with one row per cell, sensor and period, giving
#'   `p_cloud`, `p11`, `p01`, `rho`, `median_interval_days`, `n_pairs`,
#'   `mean_cloudy_run` (the mean length of consecutive cloudy acquisitions),
#'   `decorrelation_days`, `tau_days` and `tau_deseasonalised_days`.
#'
#' @section Comparing rho across places:
#' `rho` is a lag-1 autocorrelation, and the lag is whatever the local
#' acquisition interval happens to be. That interval is not constant: orbits
#' converge towards the poles, so a high-latitude cell may be observed daily
#' while a tropical cell is observed every five days. Because autocorrelation
#' decays with lag, raw `rho` values from different latitudes are not
#' comparable, and the bias runs against the tropics.
#'
#' A decorrelation time removes this. Assuming exponential decay,
#' \eqn{\rho(\Delta t) = \exp(-\Delta t / \tau)}: \eqn{\tau} is the time
#' over which cloud state becomes uninformative about itself, in days,
#' independent of how often the cell is observed. `decorrelation_days`
#' converts `rho` with the median interval, \eqn{\tau = -\Delta t / \log \rho},
#' which is exact only when intervals are constant; it is `NA` where `rho` is
#' not positive. `tau_days` uses every pair at its actual lag: for a two-state
#' chain with relaxation time \eqn{\tau}, the product of the standardised
#' anomalies of two states \eqn{\Delta t} days apart has expectation
#' \eqn{\exp(-\Delta t / \tau)}, and \eqn{\tau} is fitted to the products
#' by least squares. Both treat the cloud probability as constant, so the
#' seasonal cycle, which makes consecutive states alike because they share a
#' season, is counted as persistence. `tau_deseasonalised_days` standardises
#' each state against a seasonal probability (a logistic regression on two
#' annual harmonics of day of year, fitted to all dates of the cell and sensor)
#' and measures only the persistence of weather beyond the seasonal cycle.
#'
#' Note also that `mean_cloudy_run` is not a measure of clustering. A cell that
#' is cloudy 94 percent of the time has long cloudy runs whatever its
#' autocorrelation, because the marginal alone produces them. `rho` measures
#' persistence beyond what the marginal explains; run length confounds the two.
#' @export
#' @examples
#' d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
#' ts <- cl_simulate_series(d, p_cloud = 0.5, persistence = 0.6, seed = 1)
#' o <- cl_obs(1, ts$date, ts$cloud_fraction, sensor = "sentinel-2-msi")
#' cl_persistence(o)$rho
cl_persistence <- function(obs, threshold = 0.2, max_interval = 20,
                           min_pairs = 10, by = c("all", "year", "season")) {
  by <- match.arg(by)
  cl_assert(inherits(obs, "cl_obs"), "`obs` must be a cl_obs table.")
  obs$.period <- .cs_period(obs$date, by)
  obs$.cloudy <- obs$cloud_fraction > threshold
  pseas <- .cs_seasonal_prob(obs)

  key <- paste(obs$cell, obs$sensor, obs$.period, sep = "\r")
  sp <- split(obs, key)
  parts <- do.call(rbind, strsplit(names(sp), "\r", fixed = TRUE))

  out <- do.call(rbind, lapply(seq_along(sp), function(k) {
    d <- sp[[k]]
    d <- d[order(d$date), , drop = FALSE]
    # One state per acquisition date; same-date duplicates (overlapping
    # footprints) are collapsed so that side-lap does not inflate the
    # apparent persistence.
    agg <- tapply(d$.cloudy, as.character(d$date), function(x) mean(x) > 0.5)
    dts <- as.Date(names(agg)); st <- as.logical(agg)
    o <- order(dts); dts <- dts[o]; st <- st[o]
    if (length(st) < 3L) return(NULL)
    gap <- as.numeric(diff(dts))
    ok <- gap <= max_interval
    if (sum(ok) < min_pairs) return(NULL)
    from <- st[-length(st)][ok]; to <- st[-1L][ok]
    n1 <- sum(from); n0 <- sum(!from)
    if (n1 < 3L || n0 < 3L) return(NULL)
    p11 <- sum(from & to) / n1
    p01 <- sum(!from & to) / n0
    r <- rle(st)
    ps <- pseas[[paste(parts[k, 1], parts[k, 2], sep = "\r")]](dts)
    data.frame(
      cell = as.integer(parts[k, 1]), sensor = parts[k, 2],
      period = parts[k, 3], p_cloud = mean(st),
      p11 = p11, p01 = p01, rho = p11 - p01,
      median_interval_days = stats::median(gap[ok]),
      n_pairs = sum(ok), n_acq = length(st),
      mean_cloudy_run = if (any(r$values)) mean(r$lengths[r$values]) else 0,
      decorrelation_days = {
        rr <- p11 - p01; dt <- stats::median(gap[ok])
        # Guarded rather than computed then discarded: log() of a non-positive
        # rho warns even when the value is thrown away.
        if (!is.na(rr) && is.finite(rr) && rr > 0 && rr < 1) -dt / log(rr)
        else NA_real_
      },
      tau_days = .cs_tau_lagfit(st, rep(mean(st), length(st)), gap, ok),
      tau_deseasonalised_days = .cs_tau_lagfit(st, ps, gap, ok),
      stringsAsFactors = FALSE)
  }))
  if (is.null(out)) {
    cl_warn("No cell had enough usable transitions; try lowering `min_pairs` ",
            "or raising `max_interval`.")
    return(data.frame())
  }
  rownames(out) <- NULL
  out
}

#' Seasonal clear-sky model
#'
#' Fits a harmonic logistic model of clear-sky probability against day of year
#' for each cell, and reports the phase of the clear-sky maximum. The practical
#' output is a best-acquisition-window map: the contiguous stretch of the year
#' during which a cell is most likely to be observable.
#'
#' @param obs A `cl_obs` table.
#' @param threshold Maximum cloud fraction for a usable observation.
#' @param harmonics Number of annual harmonics (1 or 2).
#' @param window_days Length of the reported best window.
#' @param min_obs Minimum observations per cell required to attempt a fit.
#' @return A data frame with one row per cell: `amplitude`, `peak_doy`,
#'   `p_clear_peak`, `p_clear_trough`, `window_start`, `window_end`,
#'   `n`, and `converged`.
#' @export
cl_seasonality <- function(obs, threshold = 0.2, harmonics = 1L,
                           window_days = 60, min_obs = 12) {
  cl_assert(inherits(obs, "cl_obs"), "`obs` must be a cl_obs table.")
  cl_assert(harmonics %in% c(1L, 2L), "`harmonics` must be 1 or 2.")
  obs$.clear <- as.integer(obs$cloud_fraction <= threshold)
  doy <- as.integer(format(obs$date, "%j"))
  obs$.t <- 2 * pi * doy / 365.25

  sp <- split(obs, obs$cell)
  out <- lapply(names(sp), function(k) {
    d <- sp[[k]]
    if (nrow(d) < min_obs || length(unique(d$.clear)) < 2L) {
      return(data.frame(cell = as.integer(k), amplitude = NA_real_,
                        peak_doy = NA_integer_, p_clear_peak = NA_real_,
                        p_clear_trough = NA_real_, window_start = NA_integer_,
                        window_end = NA_integer_, n = nrow(d), converged = FALSE,
                        stringsAsFactors = FALSE))
    }
    X <- data.frame(y = d$.clear, c1 = cos(d$.t), s1 = sin(d$.t))
    form <- y ~ c1 + s1
    if (harmonics == 2L) {
      X$c2 <- cos(2 * d$.t); X$s2 <- sin(2 * d$.t)
      form <- y ~ c1 + s1 + c2 + s2
    }
    fit <- tryCatch(stats::glm(form, data = X, family = stats::binomial()),
                    error = function(e) NULL, warning = function(w) NULL)
    if (is.null(fit)) {
      return(data.frame(cell = as.integer(k), amplitude = NA_real_,
                        peak_doy = NA_integer_, p_clear_peak = NA_real_,
                        p_clear_trough = NA_real_, window_start = NA_integer_,
                        window_end = NA_integer_, n = nrow(d), converged = FALSE,
                        stringsAsFactors = FALSE))
    }
    dd <- 1:365
    tt <- 2 * pi * dd / 365.25
    nd <- data.frame(c1 = cos(tt), s1 = sin(tt))
    if (harmonics == 2L) { nd$c2 <- cos(2 * tt); nd$s2 <- sin(2 * tt) }
    p <- stats::predict(fit, newdata = nd, type = "response")
    # Best contiguous window by circular rolling mean
    w <- min(window_days, 365)
    ext <- c(p, p[seq_len(w)])
    roll <- stats::filter(ext, rep(1 / w, w), sides = 1)
    roll <- roll[w:(w + 364)]
    ws <- which.max(roll)
    data.frame(cell = as.integer(k),
               amplitude = (max(p) - min(p)) / 2,
               peak_doy = which.max(p),
               p_clear_peak = max(p), p_clear_trough = min(p),
               window_start = ws,
               window_end = ((ws + w - 2L) %% 365L) + 1L,
               n = nrow(d), converged = TRUE, stringsAsFactors = FALSE)
  })
  do.call(rbind, out)
}

#' Multi-constellation revisit synergy
#'
#' Answers the question a study designer actually asks: if I combine these
#' sensors, how many observations do I get, and how does that change through
#' time?
#'
#' Effective revisit is not a constant. Landsat 9 joined Landsat 8 in late
#' 2021, roughly halving the Landsat interval from that point; Sentinel-2B
#' joined 2A in 2017 and 2C in 2024. A study spanning 2014 to the present
#' therefore has a non-stationary sampling density, and comparing early and
#' late years without accounting for it confounds acquisition capacity with
#' whatever is being measured.
#'
#' @param sensors Character vector of sensor ids or aliases.
#' @param start,end Analysis period.
#' @param by Reporting granularity, `"year"` or `"month"`.
#' @param latitude Optional latitude used to inflate revisit for orbital
#'   side-lap, which increases towards the poles.
#' @return A data frame with columns `period`, `sensor`, `n_platforms`,
#'   `nominal_obs`, `combined_obs` and `effective_revisit_days`.
#' @export
#' @examples
#' cl_synergy(c("landsat-8-9-oli", "sentinel-2-msi"),
#'            start = "2015-01-01", end = "2025-12-31", by = "year")[1:6, ]
cl_synergy <- function(sensors, start, end, by = c("year", "month"),
                       latitude = 0) {
  by <- match.arg(by)
  start <- as.Date(start); end <- as.Date(end)
  cl_assert(end > start, "`end` must be after `start`.")
  drvs <- lapply(sensors, cl_sensor)

  brk <- seq(start, end, by = if (by == "year") "year" else "month")
  brk <- c(brk, end + 1)
  periods <- format(brk[-length(brk)], if (by == "year") "%Y" else "%Y-%m")

  # Side-lap gain: WRS-2/MGRS swaths overlap increasingly towards the poles,
  # so a fixed location is imaged on more orbits than the nominal revisit says.
  lat_gain <- 1 / max(0.15, cos(deg2rad(min(abs(latitude), 81))))

  rows <- list()
  for (i in seq_along(periods)) {
    p0 <- brk[i]; p1 <- brk[i + 1] - 1
    ndays <- as.numeric(p1 - p0) + 1
    for (d in drvs) {
      if (is.null(d$platforms)) next
      act <- sum(vapply(seq_len(nrow(d$platforms)), function(j) {
        s <- d$platforms$start[j]
        e <- d$platforms$end[j]; if (is.na(e)) e <- as.Date("2999-12-31")
        as.numeric(max(0, as.numeric(min(p1, e) - max(p0, s)) + 1)) / ndays
      }, numeric(1)))
      nominal <- ndays / d$revisit
      rows[[length(rows) + 1L]] <- data.frame(
        period = periods[i], sensor = d$id,
        n_platforms = act,
        nominal_obs = nominal,
        combined_obs = nominal * act * lat_gain,
        stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows)
  tot <- tapply(out$combined_obs, out$period, sum)
  comb <- data.frame(
    period = names(tot), sensor = "COMBINED",
    n_platforms = as.numeric(tapply(out$n_platforms, out$period, sum)),
    nominal_obs = as.numeric(tapply(out$nominal_obs, out$period, sum)),
    combined_obs = as.numeric(tot), stringsAsFactors = FALSE
  )
  out <- rbind(out, comb)
  period_days <- if (by == "year") 365.25 else 30.44
  out$effective_revisit_days <- ifelse(out$combined_obs > 0,
                                       period_days / out$combined_obs, NA_real_)
  rownames(out) <- NULL
  out[order(out$period, out$sensor), ]
}

#' Sampling design feasibility
#'
#' Given a clear-sky probability and an acquisition cadence, reports the
#' probability of obtaining at least `n_required` usable observations within a
#' window, and the probability that no gap exceeds `max_gap`.
#'
#' @param p_clear Per-acquisition probability that the cell is usable.
#' @param n_acquisitions Number of acquisition opportunities in the window.
#' @param n_required Minimum usable observations needed.
#' @param window_days Length of the window in days.
#' @param max_gap Maximum tolerable gap in days, or `NULL` to skip.
#' @param n_sim Monte Carlo replicates for the gap calculation.
#' @return A list with `p_sufficient`, `expected_obs`, and, when `max_gap` is
#'   given, `p_gap_ok`.
#' @export
#' @examples
#' cl_feasibility(p_clear = 0.35, n_acquisitions = 36, n_required = 12,
#'                window_days = 365, max_gap = 45)
cl_feasibility <- function(p_clear, n_acquisitions, n_required,
                           window_days = 365, max_gap = NULL, n_sim = 2000) {
  cl_assert_fraction(p_clear, "p_clear")
  cl_assert_number(n_acquisitions, "n_acquisitions", lower = 1)
  out <- list(
    expected_obs = n_acquisitions * p_clear,
    p_sufficient = stats::pbinom(n_required - 1, size = round(n_acquisitions),
                                 prob = p_clear, lower.tail = FALSE)
  )
  if (!is.null(max_gap)) {
    step <- window_days / n_acquisitions
    ok <- vapply(seq_len(n_sim), function(i) {
      hit <- stats::runif(round(n_acquisitions)) < p_clear
      if (!any(hit)) return(FALSE)
      t <- which(hit) * step
      g <- c(t[1], diff(t), window_days - t[length(t)])
      max(g) <= max_gap
    }, logical(1))
    out$p_gap_ok <- mean(ok)
    out$n_sim <- n_sim
  }
  out
}


#' Build a quality-layer observation table
#'
#' Reads each scene's producer quality layer (Landsat `QA_PIXEL`, Sentinel-2
#' `SCL`) over the requested grid cells and records, for every
#' cell-observation, the share of valid pixels flagged as cloud, cloud shadow
#' and snow. Scene-level cloud cover is an average over a footprint of 10,000
#' km2 or more and says little about a particular cell; this table measures the
#' cell itself. It is the `"qa"` evidence tier and can be passed to every
#' function that accepts a `cl_obs` table.
#'
#' A scene contributes to the cells whose centroid lies within its footprint,
#' as in [cl_items_to_obs()]. Pixels are classified with [cl_qa_decode()];
#' a pixel flagged as both cloud and shadow counts as cloud. Tiles acquired
#' within `overpass_minutes` of each other are one observation of a cell, and
#' the tile with the most valid pixels in the cell is kept. Landsat assets that
#' the catalogue lists in the requester-pays USGS bucket are read from the
#' Planetary Computer mirror with an anonymous access token.
#'
#' @param items Scenes from [cl_search()].
#' @param grid A grid from [cl_grid()].
#' @param cells Cell identifiers to evaluate.
#' @param include_cirrus,confidence Passed to [cl_qa_decode()].
#' @param overpass_minutes Tiles acquired within this many minutes are one
#'   overpass.
#' @param workers Scenes read in parallel by forked processes; forced to 1 on
#'   Windows.
#' @return A `cl_obs` table of tier `"qa"`. `cloud_fraction`,
#'   `shadow_fraction` and `snow_fraction` are shares of the valid pixels in the
#'   cell; `valid_fraction` is the share of the cell with valid data, `n_valid`
#'   the number of valid pixels and `id` the scene kept. Cell-observations
#'   without valid pixels are dropped. Attribute `"failed"` holds the
#'   identifiers of scenes that could not be read.
#' @export
cl_qa_obs <- function(items, grid, cells, include_cirrus = TRUE,
                      confidence = "medium", overpass_minutes = 20,
                      workers = 1L) {
  cl_assert(inherits(items, "cl_items"), "`items` must come from cl_search().")
  cl_assert(inherits(grid, "cl_grid"), "`grid` must be a cl_grid.")
  cl_require("terra", "Reading quality layers")
  cells <- unique(as.integer(cells))
  cc <- cl_grid_cells(grid, cells)
  half <- grid$res / 2
  geoms <- attr(items, "geometry")
  assets <- attr(items, "assets")
  gdal_opts <- c(GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR",
                 GDAL_HTTP_MAX_RETRY = "4", GDAL_HTTP_RETRY_DELAY = "2")
  unset <- names(gdal_opts)[!nzchar(Sys.getenv(names(gdal_opts)))]
  if (length(unset)) {
    do.call(Sys.setenv, as.list(gdal_opts[unset]))
    on.exit(Sys.unsetenv(unset), add = TRUE)
  }

  read_item <- function(i) {
    spec <- cl_sensor(items$sensor[i])$qa
    href <- assets[[i]][[spec$asset]]$href
    if (is.null(href)) return(NULL)
    hit <- unique(unlist(lapply(.cs_geom_rings(geoms[[i]]), function(m)
      cl_grid_index(m, grid, method = "centroid")$cell)))
    hit <- intersect(hit, cells)
    if (!length(hit)) return(NULL)
    src <- .cs_readable_href(href)
    if (grepl("^https?://", src)) src <- paste0("/vsicurl/", src)
    r <- tryCatch(terra::rast(src), error = function(e) {
      # The Planetary Computer mirror can hold another processing version of
      # a Landsat scene than the USGS bucket lists; its own record names it.
      if (!grepl("^s3://usgs-landsat/", href)) stop(e)
      alt <- .cs_pc_landsat_href(items$id[i], spec$asset)
      if (grepl("^https?://", alt)) alt <- paste0("/vsicurl/", alt)
      terra::rast(alt)
    })
    fill <- if (spec$type == "bitmask") bitwShiftL(1L, spec$bits[["fill"]])
            else spec$classes[["no_data"]]
    do.call(rbind, lapply(hit, function(k) {
      j <- match(k, cc$cell)
      xy <- cbind(cc$x[j] + c(-half, half, half, -half, -half),
                  cc$y[j] + c(-half, -half, half, half, -half))
      poly <- terra::densify(terra::vect(xy, type = "polygons", crs = "EPSG:6933"),
                             interval = grid$res / 25)
      poly <- terra::project(poly, terra::crs(r))
      if (is.null(terra::intersect(terra::ext(r), terra::ext(poly)))) return(NULL)
      v <- terra::mask(terra::crop(r, poly, snap = "out"), poly)
      q <- terra::as.matrix(v, wide = TRUE)
      q[is.na(q)] <- fill
      dec <- cl_qa_decode(q, items$sensor[i], include_cirrus = include_cirrus,
                          confidence = confidence)
      valid <- !dec$fill
      n_valid <- sum(valid)
      if (n_valid == 0L) return(NULL)
      cloud <- valid & dec$cloud
      shadow <- valid & dec$shadow & !dec$cloud
      snow <- valid & dec$snow & !dec$cloud & !dec$shadow
      data.frame(cell = k, datetime = items$datetime[i], id = items$id[i],
                 sensor = items$sensor[i], platform = items$platform[i],
                 n_valid = n_valid,
                 cloud_fraction = sum(cloud) / n_valid,
                 shadow_fraction = sum(shadow) / n_valid,
                 snow_fraction = sum(snow) / n_valid,
                 valid_fraction = min(1, n_valid / (grid$res^2 / prod(terra::res(r)))),
                 stringsAsFactors = FALSE)
    }))
  }
  safe <- function(i) tryCatch(read_item(i), error = function(e) structure(
    list(message = conditionMessage(e)), class = "cs_read_error"))
  idx <- seq_len(nrow(items))
  n_workers <- if (.Platform$OS.type == "windows") 1L else max(1L, as.integer(workers))
  res <- if (n_workers > 1L) {
    parallel::mclapply(idx, safe, mc.cores = n_workers, mc.preschedule = FALSE)
  } else lapply(idx, safe)
  bad <- vapply(res, function(x) inherits(x, "cs_read_error") ||
                  inherits(x, "try-error"), logical(1))
  if (any(bad)) res[bad] <- lapply(idx[bad], safe)
  bad <- vapply(res, function(x) inherits(x, "cs_read_error") ||
                  inherits(x, "try-error"), logical(1))
  if (any(bad)) {
    cl_warn(sum(bad), " of ", nrow(items), " scenes could not be read and are ",
            "absent from the table; their identifiers are in attr(x, \"failed\").")
  }
  d <- do.call(rbind, res[!bad])
  if (is.null(d) || !nrow(d)) cl_abort("No quality-layer pixels fell in the requested cells.")
  d <- .cs_collapse_qa(d, overpass_minutes)
  out <- cl_obs(d$cell, as.Date(d$datetime), d$cloud_fraction, d$sensor,
                d$platform, tier = "qa", shadow_fraction = d$shadow_fraction,
                snow_fraction = d$snow_fraction)
  out$datetime <- d$datetime
  out$valid_fraction <- d$valid_fraction
  out$n_valid <- d$n_valid
  out$id <- d$id
  attr(out, "failed") <- items$id[bad]
  out
}

# Keeps, for each cell and overpass, the tile with the most valid pixels.
.cs_collapse_qa <- function(d, minutes = 20) {
  d <- d[order(d$cell, d$sensor, d$datetime), , drop = FALSE]
  n <- nrow(d)
  if (n < 2L) return(d)
  gap <- as.numeric(difftime(d$datetime[-1], d$datetime[-n], units = "mins"))
  grp <- cumsum(c(TRUE, d$cell[-1] != d$cell[-n] | d$sensor[-1] != d$sensor[-n] |
                    gap > minutes))
  keep <- unlist(lapply(split(seq_len(n), grp), function(r) r[which.max(d$n_valid[r])]))
  out <- d[keep, , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Seasonal cloud probability for each cell and sensor: a logistic regression
# on two annual harmonics of day of year, fitted to all dates on record. With
# fewer than 24 dates or a single state it falls back to the overall mean.
.cs_seasonal_prob <- function(obs) {
  key <- paste(obs$cell, obs$sensor, sep = "\r")
  lapply(split(obs, key), function(d) {
    agg <- tapply(d$.cloudy, as.character(d$date), function(x) mean(x) > 0.5)
    y <- as.numeric(agg)
    w <- 2 * pi * as.numeric(format(as.Date(names(agg)), "%j")) / 365.25
    flat <- function(dates) rep(mean(y), length(dates))
    if (length(y) < 24L || length(unique(y)) < 2L) return(flat)
    fit <- tryCatch(suppressWarnings(stats::glm(
      y ~ sin(w) + cos(w) + sin(2 * w) + cos(2 * w), family = stats::binomial())),
      error = function(e) NULL)
    if (is.null(fit)) return(flat)
    cf <- stats::coef(fit)
    function(dates) {
      v <- 2 * pi * as.numeric(format(dates, "%j")) / 365.25
      stats::plogis(cf[1] + cf[2] * sin(v) + cf[3] * cos(v) +
                      cf[4] * sin(2 * v) + cf[5] * cos(2 * v))
    }
  })
}

# Decorrelation time from consecutive pairs at their actual lags. For a
# two-state chain with relaxation time tau, the product of standardised
# anomalies of two states lag days apart has expectation exp(-lag / tau), so
# tau is fitted by least squares to the products of all pairs rather than by
# converting a lag-1 correlation with a single representative interval.
.cs_tau_lagfit <- function(state, p, gap, ok) {
  p <- pmin(pmax(p, 0.01), 0.99)
  a <- (as.numeric(state) - p) / sqrt(p * (1 - p))
  prod <- (a[-length(a)] * a[-1L])[ok]
  lag <- gap[ok]
  if (length(prod) < 10L) return(NA_real_)
  f <- function(lt) sum((prod - exp(-lag / exp(lt)))^2)
  tau <- exp(stats::optimize(f, c(log(0.1), log(365)))$minimum)
  if (tau > 360) NA_real_ else tau
}
