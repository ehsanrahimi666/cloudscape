%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_seasonality}
\alias{cl_seasonality}
\title{Seasonal clear-sky model}
\usage{
cl_seasonality(obs, threshold = 0.2, harmonics = 1L, window_days = 60,
  min_obs = 12, coverage = TRUE)
}
\arguments{
  \item{obs}{A \code{cl_obs} table.}
  \item{threshold}{Usability threshold, see \code{\link{cl_clear_obs}}.}
  \item{harmonics}{Number of annual harmonics (1 or 2).}
  \item{window_days}{Length of the reported best window.}
  \item{min_obs}{Minimum observations per cell required to attempt a fit.}
  \item{coverage}{Take the valid share of the cell into account, see
  \code{\link{cl_clear_obs}}.
When usable and unusable acquisitions are separated, or nearly so, by day
of year, the maximum-likelihood estimates diverge and the fitted
probabilities approach 0 and 1. Such fits are reported, flagged with
\code{separated = TRUE}, rather than dropped, because they belong to the most
seasonal cells. Their fitted probabilities overstate how certain the
seasonal switch is, but their peak and window remain informative.}
}
\description{
Fits a harmonic logistic model of clear-sky probability against day of year
for each cell, and reports the phase of the clear-sky maximum. The practical
output is a best-acquisition-window map: the contiguous stretch of the year
during which a cell is most likely to be observable.
}
\value{
A data frame with one row per cell: \code{amplitude}, \code{peak_doy},
  \code{p_clear_peak}, \code{p_clear_trough}, \code{window_start}, \code{window_end}, \code{n},
  \code{converged} and \code{separated}. Cells with fewer than \code{min_obs}
  acquisitions, or with only usable or only unusable ones, have \code{NA}
  estimates.
}
