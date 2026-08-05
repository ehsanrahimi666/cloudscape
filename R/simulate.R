# ---------------------------------------------------------------------------
# Module 9: simulation
#
# Benchmarking cloud detectors against hand-labelled scenes has a ceiling: the
# labels themselves disagree, thin cloud boundaries are ambiguous, and shadow
# annotation is the weakest class in every published dataset. Simulation gives
# a complementary axis of evidence, with exactly known truth and a controllable
# difficulty gradient.
#
# The shadow here is cast with cl_shadow_offset(), the same function the
# detector inverts, so simulated geometry and detected geometry cannot silently
# diverge.
# ---------------------------------------------------------------------------

# Value-noise fractal field on a regular lattice. Implemented directly rather
# than pulled from a dependency so that simulated benchmarks are reproducible
# across platforms from a seed alone.
.cs_fractal <- function(nrow, ncol, octaves = 5L, persistence = 0.55,
                        lacunarity = 2, base = 4L) {
  out <- matrix(0, nrow, ncol)
  amp <- 1; tot <- 0; freq <- base
  yy <- seq_len(nrow); xx <- seq_len(ncol)
  for (o in seq_len(octaves)) {
    gy <- max(2L, as.integer(round(freq)) + 1L)
    gx <- max(2L, as.integer(round(freq)) + 1L)
    g <- matrix(stats::runif(gy * gx), gy, gx)
    # Bilinear upsample with smoothstep weights
    fy <- (yy - 1) / (nrow - 1) * (gy - 1) + 1
    fx <- (xx - 1) / (ncol - 1) * (gx - 1) + 1
    i0 <- pmin(gy - 1, floor(fy)); j0 <- pmin(gx - 1, floor(fx))
    ty <- fy - i0; tx <- fx - j0
    sy <- ty * ty * (3 - 2 * ty); sx <- tx * tx * (3 - 2 * tx)
    a <- g[cbind(rep(i0, ncol), rep(j0, each = nrow))]
    b <- g[cbind(rep(i0, ncol), rep(j0 + 1, each = nrow))]
    c <- g[cbind(rep(i0 + 1, ncol), rep(j0, each = nrow))]
    d <- g[cbind(rep(i0 + 1, ncol), rep(j0 + 1, each = nrow))]
    SX <- matrix(rep(sx, each = nrow), nrow, ncol)
    SY <- matrix(rep(sy, ncol), nrow, ncol)
    top <- matrix(a, nrow, ncol) * (1 - SX) + matrix(b, nrow, ncol) * SX
    bot <- matrix(c, nrow, ncol) * (1 - SX) + matrix(d, nrow, ncol) * SX
    out <- out + amp * (top * (1 - SY) + bot * SY)
    tot <- tot + amp
    amp <- amp * persistence
    freq <- freq * lacunarity
  }
  out / tot
}

#' Simulate clouds and cloud shadows
#'
#' Generates a synthetic cloud field with controllable coverage, size, edge
#' softness and opacity, casts a geometrically consistent shadow, and optionally
#' composites both onto a background reflectance scene.
#'
#' Opacity is the key difficulty control. Fully opaque cloud is easy for every
#' method; the discrimination between algorithms happens between roughly 0.2 and
#' 0.6 opacity, which is where thin cirrus and cloud edges live and where
#' published masks disagree most.
#'
#' @param nrow,ncol Scene dimensions in pixels. Ignored if `background` is given.
#' @param background Optional named list or 3-D array of clear reflectance
#'   bands to composite onto. Band names should be standardised.
#' @param coverage Target cloud fraction in \[0, 1\].
#' @param size Characteristic cloud size as a fraction of scene width; smaller
#'   values give more, smaller clouds.
#' @param opacity Cloud opacity in \[0, 1\]; 1 is fully opaque. May be a length-2
#'   vector giving a range, sampled per cloud object.
#' @param edge_softness Width of the semi-transparent cloud edge, in pixels.
#' @param height Cloud-top height in metres.
#' @param res Pixel size in metres.
#' @param sun_zenith,sun_azimuth,view_zenith,view_azimuth Geometry in degrees.
#' @param shadow_darkening Multiplicative reflectance factor inside shadow.
#' @param cloud_reflectance Reflectance of fully opaque cloud.
#' @param noise Standard deviation of additive Gaussian sensor noise.
#' @param seed Random seed.
#'
#' @return A list with `cloud` (0/1 truth), `opacity` (continuous), `shadow`
#'   (0/1 truth), `truth` (class codes from [cl_classes()]), `bands` (list of
#'   contaminated reflectance matrices, when `background` was supplied) and
#'   `params`.
#' @export
#' @examples
#' s <- cl_simulate(120, 120, coverage = 0.3, opacity = c(0.4, 1), seed = 42)
#' round(mean(s$cloud), 2)
#' sum(s$shadow) > 0
cl_simulate <- function(nrow = 256, ncol = 256, background = NULL,
                        coverage = 0.25, size = 0.15, opacity = c(0.3, 1),
                        edge_softness = 3, height = 2000, res = 30,
                        sun_zenith = 40, sun_azimuth = 150,
                        view_zenith = 0, view_azimuth = 0,
                        shadow_darkening = 0.45, cloud_reflectance = 0.8,
                        noise = 0.005, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  cl_assert_fraction(coverage, "coverage")
  cl_assert_number(size, "size", lower = 1e-3, upper = 1)
  cl_assert(length(opacity) %in% 1:2, "`opacity` must have length 1 or 2.")
  cl_assert_fraction(opacity, "opacity")

  if (!is.null(background)) {
    bg <- if (is.list(background)) background else list(band = background)
    d <- dim(.cs_as_matrix(bg[[1L]]))
    nrow <- d[1L]; ncol <- d[2L]
  } else bg <- NULL

  # Fractal field thresholded to the requested coverage
  base_freq <- max(2L, as.integer(round(1 / size)))
  f <- .cs_fractal(nrow, ncol, base = base_freq)
  thr <- stats::quantile(f, 1 - coverage, names = FALSE)
  core <- f > thr

  # Soft edges: distance-weighted ramp built from repeated erosion, which keeps
  # the transition monotone and avoids a distance-transform dependency.
  ramp <- core * 1
  if (edge_softness > 0) {
    acc <- core * 1
    cur <- core * 1
    for (k in seq_len(as.integer(round(edge_softness)))) {
      cur <- .cs_erode(cur, 1)
      acc <- acc + cur
    }
    ramp <- acc / (as.integer(round(edge_softness)) + 1)
  }

  op <- if (length(opacity) == 1L) opacity else
    stats::runif(1, opacity[1], opacity[2])
  op_field <- ramp * op
  op_field[!core] <- 0
  cloud <- (op_field > 0.02) * 1

  # Shadow: cast with the same kernel the detector inverts
  off <- cl_shadow_offset(height, sun_zenith, sun_azimuth,
                          view_zenith, view_azimuth)
  dcol <- off[1, "dx"] / res
  drow <- -off[1, "dy"] / res
  shadow_op <- .cs_shift_matrix(op_field, dcol, drow)
  shadow <- (shadow_op > 0.02) * 1
  shadow[cloud > 0] <- 0

  cls <- cl_classes()
  truth <- matrix(cls[["clear_land"]], nrow, ncol)
  truth[shadow > 0] <- cls[["cloud_shadow"]]
  truth[cloud > 0 & op_field < 0.5] <- cls[["cloud_thin"]]
  truth[cloud > 0 & op_field >= 0.5] <- cls[["cloud_thick"]]

  bands <- NULL
  if (!is.null(bg)) {
    bands <- lapply(bg, function(b) {
      b <- .cs_as_matrix(b)
      # Shadow attenuates, then cloud mixes towards cloud reflectance
      out <- b * (1 - shadow_op * (1 - shadow_darkening))
      out <- out * (1 - op_field) + cloud_reflectance * op_field
      if (noise > 0) out <- out + stats::rnorm(length(out), 0, noise)
      .cs_clamp(out, 0, 1.5)
    })
    names(bands) <- names(bg)
  }

  list(cloud = cloud, opacity = op_field, shadow = shadow, truth = truth,
       bands = bands,
       params = list(coverage = coverage, realised_coverage = mean(cloud),
                     size = size, opacity = opacity, applied_opacity = op,
                     height = height, res = res, sun_zenith = sun_zenith,
                     sun_azimuth = sun_azimuth, shadow_offset = off,
                     noise = noise, seed = seed))
}

#' Simulate a contaminated time series
#'
#' Cloud occurrence is temporally autocorrelated: a cloudy day is followed by a
#' cloudy day more often than chance. Benchmarks built on independent draws
#' therefore flatter any gap-filling or compositing method, because independent
#' cloud almost never produces the long runs that break real time series. This
#' function generates cloud occurrence from a two-state Markov chain whose
#' persistence is set explicitly.
#'
#' @param dates Acquisition dates.
#' @param p_cloud Marginal probability of a cloudy acquisition.
#' @param persistence Lag-1 autocorrelation of the cloudy/clear sequence, in
#'   \[0, 1). 0 gives independent draws; 0.35 is a reasonable default for
#'   acquisitions spaced a few days apart. Parameterising by correlation rather
#'   than by a transition multiplier keeps the marginal probability exact at
#'   every value, which a multiplier does not: multipliers must be clamped at
#'   high cloud fractions, and the clamped chain then mixes so slowly that a
#'   one-year series never leaves its initial state.
#' @param seed Random seed.
#' @return A data frame with `date`, `cloudy` and `cloud_fraction`.
#' @export
#' @examples
#' d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
#' ts <- cl_simulate_series(d, p_cloud = 0.6, persistence = 1.4, seed = 1)
#' mean(ts$cloudy)
cl_simulate_series <- function(dates, p_cloud = 0.5, persistence = 0.35,
                               seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  cl_assert_fraction(p_cloud, "p_cloud")
  cl_assert_number(persistence, "persistence", lower = 0, upper = 0.999)
  dates <- sort(as.Date(dates))
  n <- length(dates)
  tp <- .cs_markov2(p_cloud, persistence)
  state <- logical(n)
  state[1] <- stats::runif(1) < p_cloud   # start from the stationary law
  for (i in seq_len(n - 1L)) {
    state[i + 1L] <- stats::runif(1) < (if (state[i]) tp$p11 else tp$p01)
  }
  cf <- ifelse(state, stats::rbeta(n, 3, 1.2), stats::rbeta(n, 1.2, 6))
  data.frame(date = dates, cloudy = state, cloud_fraction = cf,
             stringsAsFactors = FALSE)
}


# Two-state chain with exact marginal `p` and lag-1 autocorrelation `rho`.
#   p11 = p + (1 - p) * rho    p01 = p * (1 - rho)
# The stationary probability is p01 / (p01 + 1 - p11) = p for every rho in
# [0, 1), so the marginal never needs clamping and the chain always mixes.
.cs_markov2 <- function(p, rho) {
  rho <- min(max(rho, 0), 0.999)
  list(p11 = p + (1 - p) * rho, p01 = p * (1 - rho))
}
