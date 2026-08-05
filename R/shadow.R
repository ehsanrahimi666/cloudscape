# ---------------------------------------------------------------------------
# Module 5: cloud shadow
#
# The geometric core of this module is shared with the simulator (module 9).
# cl_shadow_offset() maps a cloud-top height and an illumination geometry to a
# ground displacement. The detector runs it backwards, searching over plausible
# heights for the displacement that best explains observed dark pixels; the
# simulator runs it forwards, casting a physically consistent shadow from a
# synthetic cloud. One kernel, two directions, so a synthetic benchmark cannot
# accidentally reward a detector for a geometry the simulator got wrong.
#
# All core routines operate on plain numeric matrices. SpatRaster handling is a
# thin wrapper, which keeps the geometry testable without a GDAL stack.
# ---------------------------------------------------------------------------

#' Ground displacement of a cloud shadow
#'
#' For a cloud top at height `height` above the surface, illuminated with solar
#' zenith angle `sun_zenith` and solar azimuth `sun_azimuth`, the shadow falls
#' at a horizontal distance `height * tan(sun_zenith)` in the direction the
#' sunlight travels, that is, `sun_azimuth + 180` degrees.
#'
#' A second, smaller displacement arises because the satellite does not view
#' the cloud from nadir: an elevated cloud is imaged away from the ground point
#' it actually sits above. Landsat's field of view is narrow enough that this
#' is often neglected, but across a Sentinel-2 swath it reaches roughly
#' 0.19 times the cloud height and is worth correcting.
#'
#' @param height Cloud-top height above the surface, in metres.
#' @param sun_zenith Solar zenith angle in degrees (0 = overhead).
#' @param sun_azimuth Solar azimuth in degrees clockwise from north, giving the
#'   compass direction *of* the sun.
#' @param view_zenith,view_azimuth Sensor viewing geometry in degrees. Defaults
#'   assume nadir viewing.
#' @param correct_parallax Apply the viewing-geometry correction.
#'
#' @return A matrix with columns `dx` (metres east) and `dy` (metres north),
#'   giving the offset from the observed cloud position to the shadow position.
#' @export
#' @examples
#' # Sun due south at 45 degrees zenith: a 1 km cloud casts a 1 km shadow north
#' cl_shadow_offset(1000, sun_zenith = 45, sun_azimuth = 180)
#'
#' # Sun in the east: shadow falls to the west
#' cl_shadow_offset(1000, sun_zenith = 45, sun_azimuth = 90)
cl_shadow_offset <- function(height, sun_zenith, sun_azimuth,
                             view_zenith = 0, view_azimuth = 0,
                             correct_parallax = TRUE) {
  cl_assert_number(height, "height", lower = 0)
  cl_assert_number(sun_zenith, "sun_zenith", 0, 89.9)
  cl_assert_number(sun_azimuth, "sun_azimuth", -360, 360)

  d <- height * tan(deg2rad(sun_zenith))
  sa <- deg2rad(sun_azimuth)
  # Shadow travels away from the sun: azimuth + 180 degrees.
  dx <- -d * sin(sa)
  dy <- -d * cos(sa)

  if (correct_parallax && any(view_zenith != 0)) {
    # The cloud is imaged displaced away from nadir; move back to the ground
    # point beneath it before projecting the shadow.
    p <- height * tan(deg2rad(view_zenith))
    va <- deg2rad(view_azimuth)
    dx <- dx - p * sin(va)
    dy <- dy - p * cos(va)
  }
  cbind(dx = dx, dy = dy)
}

# Shift a logical/numeric matrix by an integer number of cells.
# Rows increase southwards (raster convention), columns eastwards.
.cs_shift_matrix <- function(m, dcol, drow, fill = 0) {
  nr <- nrow(m); nc <- ncol(m)
  out <- matrix(fill, nr, nc)
  dcol <- as.integer(round(dcol)); drow <- as.integer(round(drow))
  if (abs(dcol) >= nc || abs(drow) >= nr) return(out)
  src_r <- max(1L, 1L - drow):min(nr, nr - drow)
  src_c <- max(1L, 1L - dcol):min(nc, nc - dcol)
  if (!length(src_r) || !length(src_c)) return(out)
  out[src_r + drow, src_c + dcol] <- m[src_r, src_c]
  out
}

#' Project a cloud mask to candidate shadow locations
#'
#' Sweeps a range of plausible cloud-top heights, displaces the cloud mask by
#' the corresponding ground offset at each height, and returns either the
#' height that best matches a supplied darkness layer or the union of all
#' candidate positions.
#'
#' The similarity criterion follows the standard formulation: for each height,
#' score the fraction of projected pixels that are actually dark, and take the
#' height maximising that fraction. When no darkness layer is supplied the
#' function returns a conservative union mask, which is appropriate for
#' screening but will over-mask.
#'
#' @param cloud Logical or 0/1 matrix of cloud pixels.
#' @param darkness Optional numeric matrix in \[0, 1\] where high values
#'   indicate potential shadow (dark in NIR/SWIR). Required for height search.
#' @param res Pixel size in metres.
#' @param sun_zenith,sun_azimuth Illumination geometry in degrees.
#' @param view_zenith,view_azimuth Viewing geometry in degrees.
#' @param heights Candidate cloud-top heights in metres.
#' @param dark_threshold Relative darkening above which a pixel counts as
#'   shadowed when scoring a candidate height. 0.12 means the pixel is at least
#'   12 percent darker than the clear-sky reference.
#'
#' @return A list with `shadow` (0/1 matrix), `height` (best height in metres,
#'   `NA` when no darkness layer was supplied), `score` (matching fraction),
#'   `retained` (fraction of the projected shadow still inside the window at
#'   the selected height), `truncated` (logical; `TRUE` when no candidate
#'   height keeps at least half its shadow inside the window, in which case the
#'   height is not identifiable), `window_m`, `required_m`, `resolvable_m`
#'   (the largest cloud-top height this window can resolve), and `profile`
#'   (a data frame of score and retention against height).
#' @export
#' @examples
#' cloud <- matrix(0, 40, 40); cloud[18:22, 18:22] <- 1
#' dark  <- matrix(0, 40, 40); dark[8:12, 18:22] <- 1   # shadow 10 cells north
#' r <- cl_shadow_project(cloud, dark, res = 100, sun_zenith = 45,
#'                        sun_azimuth = 180, heights = seq(200, 2000, 100))
#' r$height
cl_shadow_project <- function(cloud, darkness = NULL, res = 30,
                              sun_zenith = 40, sun_azimuth = 180,
                              view_zenith = 0, view_azimuth = 0,
                              heights = seq(200, 12000, by = 200),
                              dark_threshold = 0.12) {
  cloud <- .cs_as_matrix(cloud)
  cl_assert_number(res, "res", lower = 1e-6)
  cl_assert(length(heights) >= 1L, "`heights` must contain at least one value.")
  cm <- cloud > 0
  if (!any(cm)) {
    return(list(shadow = matrix(0, nrow(cloud), ncol(cloud)),
                height = NA_real_, score = NA_real_,
                profile = data.frame(height = heights, score = NA_real_)))
  }

  off <- cl_shadow_offset(heights, sun_zenith, sun_azimuth,
                          view_zenith, view_azimuth)
  dcol <- off[, "dx"] / res
  drow <- -off[, "dy"] / res   # raster rows increase southwards

  if (is.null(darkness)) {
    acc <- matrix(0, nrow(cloud), ncol(cloud))
    for (i in seq_along(heights)) {
      acc <- acc + .cs_shift_matrix(cm * 1, dcol[i], drow[i])
    }
    return(list(shadow = (acc > 0) * 1, height = NA_real_, score = NA_real_,
                profile = data.frame(height = heights, score = NA_real_)))
  }

  darkness <- .cs_as_matrix(darkness)
  cl_assert(all(dim(darkness) == dim(cloud)),
            "`darkness` must have the same dimensions as `cloud`.")
  dk <- darkness >= dark_threshold
  n_cloud <- sum(cm)
  score <- numeric(length(heights))
  retained <- numeric(length(heights))
  for (i in seq_along(heights)) {
    proj <- .cs_shift_matrix(cm * 1, dcol[i], drow[i]) > 0
    # Fraction of the cloud whose projected shadow is still inside the window.
    # Shifting past the edge discards pixels, so a candidate height can score
    # well simply because almost nothing was left to score.
    retained[i] <- if (n_cloud == 0) 0 else sum(proj) / n_cloud
    proj <- proj & !cm            # a cloud cannot be its own shadow
    n <- sum(proj)
    score[i] <- if (n == 0) NA_real_ else sum(proj & dk) / n
  }
  # A candidate that has lost nearly all of its shadow off the edge is not
  # comparable with one that has not: a handful of surviving pixels can agree
  # with the darkness layer by chance and score 1.0. Require both a minimum
  # retained fraction and an absolute pixel floor, but keep the threshold low,
  # because at a large displacement even the correct height legitimately
  # retains only part of its shadow.
  n_proj <- retained * n_cloud
  eligible <- retained >= 0.10 & n_proj >= 25 & !is.na(score)
  best <- if (any(eligible)) {
    which.max(replace(score, !eligible, -Inf))
  } else {
    which.max(replace(score, is.na(score), -Inf))
  }
  shadow <- .cs_shift_matrix(cm * 1, dcol[best], drow[best]) > 0
  shadow <- shadow & !cm

  # Whether a height is even reachable is a deterministic property of the
  # geometry, not of the data: displacement is height * tan(zenith), so any
  # height whose shadow lands beyond the window cannot be distinguished from a
  # lower one. Reporting that a priori is more useful than inferring it from a
  # failed search, because the user can act on it before processing.
  tanz <- tan(deg2rad(sun_zenith))
  window_m <- min(nrow(cloud), ncol(cloud)) * res
  required_m <- max(heights) * tanz
  # Half the window is the practical limit: beyond it, most of the projected
  # shadow leaves the raster whatever the cloud's position.
  resolvable_m <- if (tanz > 0) 0.5 * window_m / tanz else Inf
  truncated <- max(heights) > resolvable_m
  if (truncated) {
    cl_warn("Search range exceeds what this window can resolve. At a solar ",
            "zenith of ", round(sun_zenith, 1), " degrees, a ", round(window_m),
            " m window resolves cloud tops up to about ", round(resolvable_m),
            " m; heights above that displace their shadow off the raster and ",
            "are not identifiable. Enlarge the tile or cap `heights`.")
  }
  list(shadow = shadow * 1, height = heights[best], score = score[best],
       retained = retained[best], truncated = truncated,
       window_m = window_m, required_m = required_m,
       resolvable_m = resolvable_m,
       profile = data.frame(height = heights, score = score,
                            retained = retained))
}

.cs_as_matrix <- function(x) {
  if (is.matrix(x)) return(x)
  if (inherits(x, "SpatRaster")) {
    cl_require("terra", reason = "Converting SpatRaster to matrix")
    return(terra::as.matrix(x, wide = TRUE))
  }
  if (is.numeric(x) || is.logical(x)) return(as.matrix(x))
  cl_abort("Expected a matrix or SpatRaster, got ", class(x)[1L], ".")
}

#' Estimate cloud-top height from thermal brightness temperature
#'
#' Uses the classical moist-adiabatic approach: the temperature difference
#' between the cloud and the surrounding clear sky, divided by an assumed lapse
#' rate, gives a height. The result is bracketed by physically plausible limits
#' because the lapse rate is an assumption, not a measurement, and because
#' thermal contrast collapses over cold surfaces.
#'
#' Sensors without a thermal band return the supplied `default_range` instead,
#' which is the honest answer: for Sentinel-2 the cloud-top height genuinely
#' cannot be retrieved from the imagery alone and must be searched over.
#'
#' @param bt Brightness temperature matrix in Kelvin, or `NULL`.
#' @param cloud Logical cloud matrix.
#' @param clear Optional logical matrix of confidently clear pixels; defaults
#'   to the complement of `cloud`.
#' @param lapse_rate Environmental lapse rate in K/m.
#' @param limits Physically plausible height range in metres.
#' @param default_range Height range returned when no thermal band exists.
#'
#' @return A list with `height` (best estimate, `NA` if unavailable) and
#'   `range` (a length-2 search interval in metres).
#' @export
cl_cloud_height <- function(bt = NULL, cloud, clear = NULL,
                            lapse_rate = 0.0065, limits = c(200, 12000),
                            default_range = c(200, 12000)) {
  cloud <- .cs_as_matrix(cloud) > 0
  if (is.null(bt) || !any(cloud)) {
    return(list(height = NA_real_, range = default_range))
  }
  bt <- .cs_as_matrix(bt)
  clear <- if (is.null(clear)) !cloud else .cs_as_matrix(clear) > 0
  if (!any(clear)) return(list(height = NA_real_, range = default_range))

  # Robust clear-sky reference: the 82.5th percentile is the usual choice, as
  # it approximates the warm end of the clear surface without chasing outliers.
  t_clear <- stats::quantile(bt[clear], 0.825, na.rm = TRUE, names = FALSE)
  t_cloud <- stats::quantile(bt[cloud], c(0.175, 0.825), na.rm = TRUE, names = FALSE)
  h <- (t_clear - t_cloud) / lapse_rate
  h <- sort(pmin(pmax(h, limits[1]), limits[2]))
  list(height = mean(h), range = c(h[1], h[2]))
}

#' Detect cloud shadows
#'
#' High-level entry point combining a darkness index, geometric projection and
#' optional thermal height constraint.
#'
#' @param cloud Logical/0-1 cloud matrix or `SpatRaster`.
#' @param nir,swir Reflectance matrices used to build the darkness index. NIR
#'   alone is workable; adding SWIR sharply reduces confusion with water.
#' @param bt Optional brightness temperature for height estimation.
#' @param water Optional logical matrix of water pixels, excluded from shadow.
#' @param res Pixel size in metres.
#' @param sun_zenith,sun_azimuth,view_zenith,view_azimuth Geometry in degrees.
#' @param method `"geometric"` searches heights against a darkness layer;
#'   `"darkness"` thresholds the darkness index alone, ignoring geometry;
#'   `"union"` returns the geometric union across all heights.
#' @param heights Candidate heights in metres.
#' @param buffer Dilate the resulting shadow by this many pixels.
#' @param dark_threshold Relative darkening counted as shadow; see
#'   [cl_shadow_project()].
#'
#' @return A `cl_maskset` with the shadow layer populated.
#' @export
cl_shadow <- function(cloud, nir = NULL, swir = NULL, bt = NULL, water = NULL,
                      res = 30, sun_zenith = 40, sun_azimuth = 180,
                      view_zenith = 0, view_azimuth = 0,
                      method = c("geometric", "darkness", "union"),
                      heights = seq(200, 12000, by = 200), buffer = 0,
                      dark_threshold = 0.12) {
  method <- match.arg(method)
  cloud <- .cs_as_matrix(cloud)
  dark <- if (is.null(nir)) NULL else .cs_darkness(nir, swir, water, cloud)

  if (method == "darkness") {
    cl_assert(!is.null(dark), "`method = \"darkness\"` requires `nir`.")
    sh <- (dark >= dark_threshold) * 1
    res_obj <- list(shadow = sh, height = NA_real_, score = NA_real_,
                    retained = NA_real_, truncated = FALSE, profile = NULL)
  } else {
    hs <- heights
    if (!is.null(bt)) {
      hh <- cl_cloud_height(bt, cloud)
      if (all(is.finite(hh$range))) {
        hs <- heights[heights >= hh$range[1] & heights <= hh$range[2]]
        if (!length(hs)) hs <- heights
      }
    }
    res_obj <- cl_shadow_project(
      cloud, if (method == "union") NULL else dark, res = res,
      sun_zenith = sun_zenith, sun_azimuth = sun_azimuth,
      view_zenith = view_zenith, view_azimuth = view_azimuth, heights = hs,
      dark_threshold = dark_threshold
    )
  }
  sh <- res_obj$shadow
  if (!is.null(water)) sh[.cs_as_matrix(water) > 0] <- 0
  if (buffer > 0) sh <- .cs_dilate(sh, buffer)

  cl_maskset(probability = sh, shadow = sh, method = paste0("shadow:", method),
             threshold = 0.5, height = res_obj$height, score = res_obj$score,
             retained = res_obj$retained, truncated = res_obj$truncated,
             profile = res_obj$profile)
}

# Darkness index, expressed as *relative darkening against the clear-sky
# reference* rather than as a scene-wide contrast stretch.
#
# A stretch over the whole scene fails whenever bright cloud is present: cloud
# occupies the top of the range, which pushes ordinary clear land towards the
# dark end and makes almost every non-cloud pixel score as shadow. Referencing
# the median of non-cloud pixels instead gives a quantity with a physical
# meaning - the fractional reflectance loss - that is comparable across scenes
# and sensors, and that is near zero over clear land by construction.
.cs_darkness <- function(nir, swir = NULL, water = NULL, cloud = NULL) {
  nir <- .cs_as_matrix(nir)
  keep <- if (is.null(cloud)) rep(TRUE, length(nir)) else .cs_as_matrix(cloud) == 0
  if (!any(keep)) keep <- rep(TRUE, length(nir))
  ref <- stats::quantile(nir[keep], 0.5, na.rm = TRUE, names = FALSE)
  d <- if (!is.finite(ref) || ref <= 0) array(0, dim(nir)) else
    .cs_clamp((ref - nir) / ref)
  if (!is.null(swir)) {
    sw <- .cs_as_matrix(swir)
    refs <- stats::quantile(sw[keep], 0.5, na.rm = TRUE, names = FALSE)
    if (is.finite(refs) && refs > 0) {
      # A shadow darkens both NIR and SWIR; requiring both suppresses water,
      # which is dark in NIR but not necessarily relative to its own SWIR.
      d <- pmin(d, .cs_clamp((refs - sw) / refs))
    }
  }
  if (!is.null(water)) d[.cs_as_matrix(water) > 0] <- 0
  d
}

.cs_stretch <- function(x, probs = c(0.02, 0.98)) {
  q <- stats::quantile(x, probs, na.rm = TRUE, names = FALSE)
  if (!is.finite(q[2] - q[1]) || q[2] <= q[1]) return(array(0, dim(x)))
  out <- (x - q[1]) / (q[2] - q[1])
  .cs_clamp(out)
}

# Square-structuring-element dilation, implemented as a separable maximum
# filter so that cost is linear rather than quadratic in the radius.
.cs_dilate <- function(m, radius) {
  radius <- as.integer(round(radius))
  if (radius <= 0) return(m)
  out <- m
  for (d in seq_len(radius)) {
    out <- pmax(out,
                .cs_shift_matrix(out, 1, 0), .cs_shift_matrix(out, -1, 0),
                .cs_shift_matrix(out, 0, 1), .cs_shift_matrix(out, 0, -1))
  }
  out
}

.cs_erode <- function(m, radius) 1 - .cs_dilate(1 - m, radius)

#' Cast shadow from terrain
#'
#' Terrain shadow is routinely confused with cloud shadow in rugged country:
#' both are dark, both correlate with slope aspect, and neither Fmask,
#' Sen2Cor's scene classification nor single-date neural masks separate them
#' explicitly. Computing terrain shadow from a DEM lets [cl_shadow()] exclude
#' it, and lets [cl_reliability()] flag where the distinction is hard.
#'
#' Implemented by marching along the solar ray from each pixel and testing
#' whether any upstream terrain rises above the ray.
#'
#' @param dem Elevation matrix in metres.
#' @param sun_zenith,sun_azimuth Illumination geometry in degrees.
#' @param res Pixel size in metres.
#' @param max_distance Maximum ray length in metres.
#'
#' @return A 0/1 matrix, 1 where terrain blocks direct illumination.
#' @export
#' @examples
#' dem <- matrix(0, 30, 30); dem[, 20:30] <- 500   # a ridge on the east side
#' ts <- cl_terrain_shadow(dem, sun_zenith = 70, sun_azimuth = 90, res = 30)
#' sum(ts) > 0
cl_terrain_shadow <- function(dem, sun_zenith, sun_azimuth, res = 30,
                              max_distance = 20000) {
  dem <- .cs_as_matrix(dem)
  cl_assert_number(sun_zenith, "sun_zenith", 0, 89.9)
  nr <- nrow(dem); nc <- ncol(dem)
  # Step towards the sun
  sa <- deg2rad(sun_azimuth)
  step_col <- sin(sa)
  step_row <- -cos(sa)
  tanalt <- 1 / tan(deg2rad(sun_zenith))   # rise per unit horizontal distance
  nsteps <- max(1L, as.integer(round(max_distance / res)))
  shadow <- matrix(0, nr, nc)
  for (k in seq_len(nsteps)) {
    dcol <- step_col * k
    drow <- step_row * k
    if (abs(dcol) >= nc && abs(drow) >= nr) break
    # Elevation of terrain at the sampled point, brought back into place
    sampled <- .cs_shift_matrix(dem, -round(dcol), -round(drow), fill = NA_real_)
    ray <- dem + k * res * tanalt
    blocked <- !is.na(sampled) & sampled > ray
    shadow[blocked] <- 1
  }
  shadow
}
