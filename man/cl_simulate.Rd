%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_simulate}
\alias{cl_simulate}
\title{Simulate clouds and cloud shadows}
\usage{
cl_simulate(nrow = 256, ncol = 256, background = NULL, coverage = 0.25, size
  = 0.15, opacity = c(0.3, 1), edge_softness = 3, height = 2000, res = 30,
  sun_zenith = 40, sun_azimuth = 150, view_zenith = 0, view_azimuth = 0,
  shadow_darkening = 0.45, cloud_reflectance = 0.8, noise = 0.005, seed =
  NULL)
}
\arguments{
  \item{nrow}{Scene dimensions in pixels. Ignored if \code{background} is given.}
  \item{ncol}{Scene dimensions in pixels. Ignored if \code{background} is given.}
  \item{background}{Optional named list or 3-D array of clear reflectance
  bands to composite onto. Band names should be standardised.}
  \item{coverage}{Target cloud fraction in \[0, 1\].}
  \item{size}{Characteristic cloud size as a fraction of scene width; smaller
  values give more, smaller clouds.}
  \item{opacity}{Cloud opacity in \[0, 1\]; 1 is fully opaque. May be a length-2
  vector giving a range, sampled per cloud object.}
  \item{edge_softness}{Width of the semi-transparent cloud edge, in pixels.}
  \item{height}{Cloud-top height in metres.}
  \item{res}{Pixel size in metres.}
  \item{sun_zenith}{Geometry in degrees.}
  \item{sun_azimuth}{Geometry in degrees.}
  \item{view_zenith}{Geometry in degrees.}
  \item{view_azimuth}{Geometry in degrees.}
  \item{shadow_darkening}{Multiplicative reflectance factor inside shadow.}
  \item{cloud_reflectance}{Reflectance of fully opaque cloud.}
  \item{noise}{Standard deviation of additive Gaussian sensor noise.}
  \item{seed}{Random seed.}
}
\description{
Generates a synthetic cloud field with controllable coverage, size, edge
softness and opacity, casts a geometrically consistent shadow, and optionally
composites both onto a background reflectance scene.

Opacity is the key difficulty control. Fully opaque cloud is easy for every
method; the discrimination between algorithms happens between roughly 0.2 and
0.6 opacity, which is where thin cirrus and cloud edges live and where
published masks disagree most.
}
\value{
A list with \code{cloud} (0/1 truth), \code{opacity} (continuous), \code{shadow}
  (0/1 truth), \code{truth} (class codes from \code{\link{cl_classes}}), \code{bands} (list of
  contaminated reflectance matrices, when \code{background} was supplied) and
  \code{params}.
}
\examples{
s <- cl_simulate(120, 120, coverage = 0.3, opacity = c(0.4, 1), seed = 42)
round(mean(s$cloud), 2)
sum(s$shadow) > 0
}
