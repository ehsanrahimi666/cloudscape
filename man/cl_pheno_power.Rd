%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_pheno_power}
\alias{cl_pheno_power}
\title{Phenological retrieval error under cloud loss}
\usage{
cl_pheno_power(dates, cloud_fraction = 0.4, threshold = 0.2, curve = NULL,
  noise = 0.03, n_sim = 100L, model = c("dbl_logistic", "spline"), tau = 1,
  valid_fraction = 1, retention = c("pixel", "cell"), tolerance = 5,
  persistence = NULL, seed = NULL)
}
\arguments{
  \item{dates}{Acquisition dates available in the year, in any order.}
  \item{cloud_fraction}{Cloud fraction for each acquisition, or a single value.}
  \item{threshold}{Usability threshold for \code{retention = "cell"}.}
  \item{curve}{Function of day-of-year giving the reference trajectory, or a
  list of arguments passed to \code{\link{cl_pheno_curve}}.}
  \item{noise}{Observation noise standard deviation.}
  \item{n_sim}{Number of replicates.}
  \item{model}{Fitting model passed to \code{\link{cl_pheno_fit}}.}
  \item{tau}{Decorrelation time of cloud loss in days; 0 gives independent
  losses.}
  \item{valid_fraction}{Valid share of the cell for each acquisition, or a
  single value.}
  \item{retention}{\code{"pixel"} or \code{"cell"}; see the section on retention.}
  \item{tolerance}{Error tolerance in days for the \code{p_within_*} outputs.}
  \item{persistence}{Deprecated. A lag-one autocorrelation between
  consecutive acquisitions; converted to \code{tau} with the median interval.}
  \item{seed}{Random seed.}
}
\description{
Simulates the effect of missing observations on the retrieval of
phenological dates. In each replicate, a reference curve is sampled at the
acquisition dates that are retained, noise is added, the curve is refitted,
and the errors of the start of season, peak and end of season are recorded.
}
\value{
A list with \code{summary} (a one-row data frame: numbers of acquisitions
  and retained observations, median absolute errors and median biases of
  start of season, peak, end of season and season length, the interquartile
  range of start of season, the failure and insufficient-data rates, and the
  \code{p_within_*} probabilities), \code{replicates}, and \code{reference}, the fit to the
  complete reference curve.
}
\section{Which observations are retained}{
With \code{retention = "pixel"} (the default) each replicate is the series of a
pixel at a random location in the cell. Acquisition \eqn{i} is observed and
clear with probability \eqn{q_i = v_i (1 - c_i)}, where \eqn{c_i} is the cloud
fraction and \eqn{v_i} the valid share of the cell (1 for scene metadata, in
which cloud is assumed to be spread evenly over the footprint). The expected
number of retained observations is therefore \eqn{\sum_i q_i}, the expected
number of clear observations of a pixel reported by \code{\link{cl_clear_obs}}.
Clear and cloudy states are drawn from a latent Gaussian process whose
correlation between two acquisitions \eqn{\Delta t} days apart is
\eqn{\exp(-\Delta t / \tau)}: acquisition \eqn{i} is clear when the latent
value is below \eqn{\Phi^{-1}(q_i)}, which keeps every marginal probability
exact while losses cluster in time according to the elapsed time between
acquisitions. \code{tau = 0} gives independent losses.

With \code{retention = "cell"}, an acquisition is retained when at least
\code{1 - threshold} of the cell was observed and cloud-free, as in
\code{\link{cl_clear_obs}}; the retained set is then the same in every replicate and
only the noise varies.
}
\section{Success and failure}{
A replicate succeeds when at least six observations are retained, the fit
converges, and the fitted curve has a start of season, a peak and an end of
season in that order. Errors are summarised over successful replicates.
Because errors conditional on success can look small when most replicates
fail, \code{p_within_*} report the probability, over all replicates, that the
replicate succeeded and the error of that date was at most \code{tolerance}
days; \code{p_within_all} requires all three dates to be within it.
}
\examples{
d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "10 days")
r <- cl_pheno_power(d, cloud_fraction = 0.5, n_sim = 30, seed = 1)
r$summary[, c("n_retained_median", "sos_mae", "failure_rate", "p_within_all")]
}
