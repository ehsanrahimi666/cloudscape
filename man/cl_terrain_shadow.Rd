%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_terrain_shadow}
\alias{cl_terrain_shadow}
\title{Cast shadow from terrain}
\usage{
cl_terrain_shadow(dem, sun_zenith, sun_azimuth, res = 30, max_distance =
  20000)
}
\arguments{
  \item{dem}{Elevation matrix in metres.}
  \item{sun_zenith}{Illumination geometry in degrees.}
  \item{sun_azimuth}{Illumination geometry in degrees.}
  \item{res}{Pixel size in metres.}
  \item{max_distance}{Maximum ray length in metres.}
}
\description{
Terrain shadow is routinely confused with cloud shadow in rugged country:
both are dark, both correlate with slope aspect, and neither Fmask,
Sen2Cor's scene classification nor single-date neural masks separate them
explicitly. Computing terrain shadow from a DEM lets \code{\link{cl_shadow}} exclude
it, and lets \code{\link{cl_reliability}} flag where the distinction is hard.

Implemented by marching along the solar ray from each pixel and testing
whether any upstream terrain rises above the ray.
}
\value{
A 0/1 matrix, 1 where terrain blocks direct illumination.
}
\examples{
dem <- matrix(0, 30, 30); dem[, 20:30] <- 500   # a ridge on the east side
ts <- cl_terrain_shadow(dem, sun_zenith = 70, sun_azimuth = 90, res = 30)
sum(ts) > 0
}
