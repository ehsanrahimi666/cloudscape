%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_probability}
\alias{cl_probability}
\title{Compute cloud probability}
\usage{
cl_probability(x, method = "threshold", sensor = NULL, geom = NULL,
  threshold = 0.5, buffer = 0, ...)
}
\arguments{
  \item{x}{A \code{cl_scene}, or a named list of reflectance matrices.}
  \item{method}{Method name; see \code{\link{cl_methods}}.}
  \item{sensor}{Sensor id, required when \code{x} is a plain list.}
  \item{geom}{Optional list with \code{sun_zenith}, \code{sun_azimuth}, \code{view_zenith},
  \code{view_azimuth}.}
  \item{threshold}{Probability threshold used to derive the class layer.}
  \item{buffer}{Dilate the resulting cloud mask by this many pixels. Cloud
  masks systematically under-detect at edges, so a small buffer is standard
  practice; the default of 0 leaves that decision explicit.}
  \item{...}{Passed to the method.}
}
\description{
Compute cloud probability
}
\value{
A \code{cl_maskset}.
}
\examples{
s <- cl_simulate(64, 64, coverage = 0.3, seed = 1,
                 background = list(blue = matrix(0.08, 64, 64),
                                   green = matrix(0.09, 64, 64),
                                   red = matrix(0.07, 64, 64),
                                   nir = matrix(0.35, 64, 64),
                                   swir16 = matrix(0.22, 64, 64)))
m <- cl_probability(s$bands, method = "threshold", sensor = "sentinel-2-msi")
round(mean(m$class), 2)
}
