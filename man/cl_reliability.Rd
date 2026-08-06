%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_reliability}
\alias{cl_reliability}
\title{Flag conditions where cloud masks are known to be unreliable}
\usage{
cl_reliability(bands, dem = NULL, sun_zenith = NULL, sun_azimuth = NULL, res
  = 30)
}
\arguments{
  \item{bands}{Named list of reflectance matrices.}
  \item{dem}{Optional elevation matrix, used to flag terrain shadow risk.}
  \item{sun_zenith}{Illumination geometry, for terrain shadow.}
  \item{sun_azimuth}{Illumination geometry, for terrain shadow.}
  \item{res}{Pixel size in metres.}
}
\description{
Returns a per-pixel reliability score. Low values mark surfaces on which
every published cloud mask has documented weaknesses, so that a downstream
statistic can be reported with an honest caveat rather than an unqualified
number.
}
\value{
A list with \code{reliability} in \\[0, 1\\] and named logical \code{flags}.
}
