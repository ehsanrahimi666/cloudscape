%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_seasonality}
\alias{cl_seasonality}
\title{Seasonal clear-sky model}
\usage{
cl_seasonality(obs, threshold = 0.2, harmonics = 1L, window_days = 60,
  min_obs = 12)
}
\arguments{
  \item{obs}{A \code{cl_obs} table.}
  \item{threshold}{Maximum cloud fraction for a usable observation.}
  \item{harmonics}{Number of annual harmonics (1 or 2).}
  \item{window_days}{Length of the reported best window.}
  \item{min_obs}{Minimum observations per cell required to attempt a fit.}
}
\description{
Fits a harmonic logistic model of clear-sky probability against day of year
for each cell, and reports the phase of the clear-sky maximum. The practical
output is a best-acquisition-window map: the contiguous stretch of the year
during which a cell is most likely to be observable.
}
\value{
A data frame with one row per cell: \code{amplitude}, \code{peak_doy},
  \code{p_clear_peak}, \code{p_clear_trough}, \code{window_start}, \code{window_end},
  \code{n}, and \code{converged}.
}
