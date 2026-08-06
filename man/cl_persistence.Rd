%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_persistence}
\alias{cl_persistence}
\title{Estimate the temporal persistence of cloud from an observation record}
\usage{
cl_persistence(obs, threshold = 0.2, max_interval = 20, min_pairs = 10, by =
  c("all", "year", "season"))
}
\arguments{
  \item{obs}{A \code{cl_obs} table.}
  \item{threshold}{Cloud fraction above which an acquisition counts as cloudy.}
  \item{max_interval}{Longest gap in days across which a transition is still
  counted. Pairs separated by more than this are dropped, because a
  transition across a three-month gap carries no information about
  persistence at the acquisition scale.}
  \item{min_pairs}{Minimum usable transitions required to report an estimate.}
  \item{by}{Period granularity, or \code{"all"} to pool the whole record.}
}
\description{
Cloud occurrence is autocorrelated in time, and that autocorrelation degrades
time-series retrievals largely independently of how much cloud there is: it
concentrates observation loss into contiguous runs that can remove an entire
seasonal transition while leaving the annual observation count almost
unchanged. Quantifying it therefore requires its own estimator.

For the two-state chain used throughout cloudscape, with marginal cloud
probability \eqn{p} and lag-1 autocorrelation \eqn{\rho},
\deqn{p_{11} = p + (1-p)\rho, \qquad p_{01} = p(1-\rho),}
so that \eqn{\rho = p_{11} - p_{01}}. The estimator is therefore the
difference between the empirical probability that a cloudy acquisition is
followed by another cloudy one and the probability that a clear acquisition
is followed by a cloudy one. This requires no model fitting and is unbiased
for a stationary chain.

Acquisitions are irregularly spaced, so transitions are counted only between
consecutive acquisitions of the same sensor and only when the interval falls
within \code{max_interval} days. The median interval actually used is returned so
that \eqn{\rho} can be interpreted per unit time rather than per
acquisition.
}
\value{
A data frame with one row per cell, sensor and period, giving
  \code{p_cloud}, \code{p11}, \code{p01}, \code{rho}, \code{median_interval_days}, \code{n_pairs} and
  \code{mean_cloudy_run}, the mean length of consecutive cloudy acquisitions.
}
\section{Attenuation}{
The estimate is a \strong{lower bound} on the persistence that matters for a
specific location. Whether an acquisition is usable at a given cell is
inferred by thresholding a scene-level cloud fraction, which is a noisy
proxy for the underlying state. Independent misclassification attenuates an
estimated autocorrelation towards zero by approximately
\eqn{(1 - \alpha - \beta)^2}, where \eqn{\alpha} and \eqn{\beta} are the
two misclassification rates. In simulation with a realistic overlap between
the cloudy and clear cloud-fraction distributions, a true \eqn{\rho} of 0.6
is recovered as approximately 0.41 and a true 0.3 as approximately 0.20.
Estimates from tier \code{"qa"} or \code{"mask"} data, where usability is measured for
the cell rather than inferred from the scene, are correspondingly less
attenuated. Reported values should therefore be read as conservative.
}
\examples{
d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
ts <- cl_simulate_series(d, p_cloud = 0.5, persistence = 0.6, seed = 1)
o <- cl_obs(1, ts$date, ts$cloud_fraction, sensor = "sentinel-2-msi")
cl_persistence(o)$rho
}
