%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_cloud_height}
\alias{cl_cloud_height}
\title{Estimate cloud-top height from thermal brightness temperature}
\usage{
cl_cloud_height(bt = NULL, cloud, clear = NULL, lapse_rate = 0.0065, limits
  = c(200, 12000), default_range = c(200, 12000))
}
\arguments{
  \item{bt}{Brightness temperature matrix in Kelvin, or \code{NULL}.}
  \item{cloud}{Logical cloud matrix.}
  \item{clear}{Optional logical matrix of confidently clear pixels; defaults
  to the complement of \code{cloud}.}
  \item{lapse_rate}{Environmental lapse rate in K/m.}
  \item{limits}{Physically plausible height range in metres.}
  \item{default_range}{Height range returned when no thermal band exists.}
}
\description{
Uses the classical moist-adiabatic approach: the temperature difference
between the cloud and the surrounding clear sky, divided by an assumed lapse
rate, gives a height. The result is bracketed by physically plausible limits
because the lapse rate is an assumption, not a measurement, and because
thermal contrast collapses over cold surfaces.

Sensors without a thermal band return the supplied \code{default_range} instead,
which is the honest answer: for Sentinel-2 the cloud-top height genuinely
cannot be retrieved from the imagery alone and must be searched over.
}
\value{
A list with \code{height} (best estimate, \code{NA} if unavailable) and
  \code{range} (a length-2 search interval in metres).
}
