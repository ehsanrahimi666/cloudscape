%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_persistence}
\alias{cl_persistence}
\title{Estimate the temporal persistence of cloud from an observation record}
\usage{
cl_persistence(obs, threshold = 0.2, max_interval = 20, min_pairs = 10, by =
  c("all", "year", "season"), coverage = TRUE)
}
\arguments{
  \item{obs}{A \code{cl_obs} table.}
  \item{threshold}{Usability threshold; an acquisition that is not usable
  (see \code{\link{cl_clear_obs}}) counts as cloudy.}
  \item{max_interval}{Longest gap in days across which a transition is still
  counted. Pairs separated by more than this are dropped, because a
  transition across a three-month gap carries no information about
  persistence at the acquisition scale. The fitted decay is driven by the
  shortest lags, so the estimate should be checked for sensitivity to this
  value.}
  \item{coverage}{Take the valid share of the cell into account, see
  \code{\link{cl_clear_obs}}.}
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
is followed by a cloudy one. This requires no model fitting and is
consistent for a stationary chain observed at a regular interval.

Acquisitions are irregularly spaced, so transitions are counted only between
consecutive acquisitions of the same sensor and only when the interval falls
within \code{max_interval} days. The median interval actually used is returned so
that \eqn{\rho} can be interpreted per unit time rather than per
acquisition.
}
\value{
A data frame with one row per cell, sensor and period, giving
  \code{p_cloud}, \code{p11}, \code{p01}, \code{rho}, \code{median_interval_days}, \code{n_pairs},
  \code{mean_cloudy_run} (the mean length of consecutive cloudy acquisitions),
  \code{decorrelation_days}, \code{tau_days} and \code{tau_deseasonalised_days}.
}
\section{Attenuation}{
Misclassification affects the estimate. Whether an acquisition is usable at
a cell is inferred by thresholding a cloud fraction, and with tier
\code{"metadata"} that fraction describes the whole scene. Misclassification that
is independent of the true state and between acquisitions multiplies the
autocovariance by \eqn{(1 - \alpha - \beta)^2}, where \eqn{\alpha} and
\eqn{\beta} are the two misclassification rates, and so attenuates the
autocorrelation towards zero; in simulation a true \eqn{\rho} of 0.6 is
recovered as approximately 0.41. Errors that are themselves persistent or
seasonal, such as commission over winter snow, violate that condition and
can bias the estimate in either direction, so it is not a bound in general.
Tier \code{"qa"} data from \code{\link{cl_qa_obs}} measure the cell directly.
}
\section{Comparing rho across places}{
\code{rho} is a lag-1 autocorrelation, and the lag is whatever the local
acquisition interval happens to be. That interval is not constant: orbits
converge towards the poles, so a high-latitude cell may be observed daily
while a tropical cell is observed every five days. Because autocorrelation
decays with lag, raw \code{rho} values from different latitudes are not
comparable, and the bias runs against the tropics.

A decorrelation time removes this. Assuming exponential decay,
\eqn{\rho(\Delta t) = \exp(-\Delta t / \tau)}: \eqn{\tau} is the time
over which cloud state becomes uninformative about itself, in days,
independent of how often the cell is observed. \code{decorrelation_days}
converts \code{rho} with the median interval, \eqn{\tau = -\Delta t / \log \rho},
which is exact only when intervals are constant; it is \code{NA} where \code{rho} is
not positive. \code{tau_days} uses every pair at its actual lag: for a two-state
chain with relaxation time \eqn{\tau}, the product of the standardised
anomalies of two states \eqn{\Delta t} days apart has expectation
\eqn{\exp(-\Delta t / \tau)}, and \eqn{\tau} is fitted to the products
by least squares. Both treat the cloud probability as constant, so the
seasonal cycle, which makes consecutive states alike because they share a
season, is counted as persistence. \code{tau_deseasonalised_days} standardises
each state against a seasonal probability (a logistic regression on two
annual harmonics of day of year, fitted to all dates of the cell and sensor)
and measures only the persistence of weather beyond the seasonal cycle.

Note also that \code{mean_cloudy_run} is not a measure of clustering. A cell that
is cloudy 94 percent of the time has long cloudy runs whatever its
autocorrelation, because the marginal alone produces them. \code{rho} measures
persistence beyond what the marginal explains; run length confounds the two.
}
\examples{
d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
ts <- cl_simulate_series(d, p_cloud = 0.5, persistence = 0.6, seed = 1)
o <- cl_obs(1, ts$date, ts$cloud_fraction, sensor = "sentinel-2-msi")
cl_persistence(o)$rho
}
