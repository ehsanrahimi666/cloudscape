# ---------------------------------------------------------------------------
# Module 3: preprocessing and geometry
# ---------------------------------------------------------------------------

#' Rescale stored integers to reflectance
#'
#' @param x A `cl_scene` or named list of matrices.
#' @param sensor Sensor id, when `x` is a list.
#' @param clamp Clip to a physically plausible range.
#' @return The rescaled object.
#' @export
cl_scale <- function(x, sensor = NULL, clamp = c(0, 1.6)) {
  drv <- if (inherits(x, "cl_scene")) x$sensor else cl_sensor(sensor)
  f <- function(m) {
    v <- .cs_as_matrix(m) * drv$scale + drv$offset
    pmin(pmax(v, clamp[1]), clamp[2])
  }
  if (inherits(x, "cl_scene")) {
    x$reflectance <- if (is.null(x$reflectance)) NULL else f(x$reflectance)
    x$manifest <- cl_manifest(x$manifest, scaled = TRUE)
    return(x)
  }
  lapply(x, f)
}

#' Solar position for a location and time
#'
#' A compact solar position algorithm, accurate to a few hundredths of a degree
#' over the satellite era, used when a scene lacks per-pixel angle grids.
#'
#' @param datetime `POSIXct` in UTC.
#' @param lon,lat Coordinates in degrees.
#' @return A data frame with `zenith` and `azimuth` in degrees.
#' @export
#' @examples
#' cl_solar_position(as.POSIXct("2023-06-21 12:00:00", tz = "UTC"), 0, 51.5)
cl_solar_position <- function(datetime, lon, lat) {
  d <- as.numeric(difftime(datetime, as.POSIXct("2000-01-01 12:00:00", tz = "UTC"),
                           units = "days"))
  L <- (280.460 + 0.9856474 * d) %% 360               # mean longitude
  g <- deg2rad((357.528 + 0.9856003 * d) %% 360)      # mean anomaly
  lambda <- deg2rad(L + 1.915 * sin(g) + 0.020 * sin(2 * g))
  eps <- deg2rad(23.439 - 0.0000004 * d)
  ra <- atan2(cos(eps) * sin(lambda), cos(lambda))
  dec <- asin(sin(eps) * sin(lambda))
  gmst <- (18.697374558 + 24.06570982441908 * d) %% 24
  lst <- deg2rad((gmst * 15 + lon) %% 360)
  H <- lst - ra
  phi <- deg2rad(lat)
  alt <- asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(H))
  az <- atan2(-sin(H), tan(dec) * cos(phi) - sin(phi) * cos(H))
  data.frame(zenith = 90 - rad2deg(alt), azimuth = (rad2deg(az) + 360) %% 360)
}

#' Attach or compute scene geometry
#'
#' @param x A `cl_scene`.
#' @param lon,lat Scene centre, used when metadata angles are absent.
#' @return The scene with `solar_geom` populated.
#' @export
cl_geometry <- function(x, lon = NULL, lat = NULL) {
  cl_assert(inherits(x, "cl_scene"), "`x` must be a cl_scene.")
  if (is.null(x$solar_geom) && !is.null(x$datetime) && !is.null(lon)) {
    sp <- cl_solar_position(x$datetime, lon, lat)
    x$solar_geom <- list(zenith = sp$zenith, azimuth = sp$azimuth,
                         source = "computed")
  }
  x
}

#' Common spectral indices
#'
#' @param bands Named list of reflectance matrices.
#' @param which Indices to compute.
#' @return A named list of matrices.
#' @export
#' @examples
#' b <- list(green = matrix(.1,4,4), red = matrix(.08,4,4),
#'           nir = matrix(.35,4,4), swir16 = matrix(.2,4,4), blue = matrix(.09,4,4))
#' names(cl_indices(b))
cl_indices <- function(bands, which = c("ndvi", "ndsi", "ndwi", "whiteness", "hot")) {
  eps <- 1e-6
  B <- lapply(bands, .cs_as_matrix)
  nd <- function(a, b) (a - b) / pmax(a + b, eps)
  out <- list()
  if ("ndvi" %in% which && all(c("nir", "red") %in% names(B))) out$ndvi <- nd(B$nir, B$red)
  if ("ndsi" %in% which && all(c("green", "swir16") %in% names(B))) out$ndsi <- nd(B$green, B$swir16)
  if ("ndwi" %in% which && all(c("green", "nir") %in% names(B))) out$ndwi <- nd(B$green, B$nir)
  if ("whiteness" %in% which && all(c("blue", "green", "red") %in% names(B))) {
    vis <- (B$blue + B$green + B$red) / 3
    out$whiteness <- (abs(B$blue - vis) + abs(B$green - vis) + abs(B$red - vis)) / pmax(vis, eps)
  }
  if ("hot" %in% which && all(c("blue", "red") %in% names(B))) {
    out$hot <- B$blue - 0.5 * B$red - 0.08
  }
  out
}
