%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_pheno_power}
\alias{cl_pheno_power}
\title{Phenological retrieval error under realistic cloud loss}
\usage{
cl_pheno_power(dates, cloud_fraction = 0.4, threshold = 0.2, curve = NULL,
  noise = 0.03, n_sim = 100L, model = c("dbl_logistic", "spline"),
  persistence = 0.35, seed = NULL)
}
\arguments{
  \item{dates}{Acquisition dates available in the year.}
  \item{cloud_fraction}{Cloud fraction for each acquisition, or a single value.}
  \item{threshold}{Maximum cloud fraction for a usable observation.}
  \item{curve}{Function of day-of-year giving the reference trajectory, or a
  list of arguments passed to \code{\link{cl_pheno_curve}}.}
  \item{noise}{Observation noise standard deviation.}
  \item{n_sim}{Number of replicates.}
  \item{model}{Fitting model passed to \code{\link{cl_pheno_fit}}.}
  \item{persistence}{Lag-1 autocorrelation of cloud loss, in \\[0, 1), using
  the same chain as \code{\link{cl_simulate_series}}. 0 gives independent loss, which
  is unrealistic and optimistic: independent loss thins the series uniformly
  and almost never removes a whole transition, whereas clustered loss
  regularly removes green-up entirely.}
  \item{seed}{Random seed.}
}
\description{
Simulates the effect of missing observations on phenological metric
retrieval. For each replicate, a reference curve is sampled at the supplied
acquisition dates, observations are dropped according to their cloud
fraction, noise is added, the curve is refitted, and the retrieval error is
recorded.

The output is directly interpretable: an expected absolute error in days for
start of season, end of season and length of season, together with the
failure rate, meaning the fraction of replicates in which the fit did not
converge at all. In heavily clouded regions the failure rate is often the
more important number, because a study there does not produce a biased
estimate, it produces no estimate.
}
\value{
A list with \code{summary} (a one-row data frame of median absolute
  errors, interquartile ranges and failure rate) and \code{replicates}.
}
\examples{
d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "10 days")
r <- cl_pheno_power(d, cloud_fraction = 0.5, n_sim = 30, seed = 1)
r$summary[, c("n_usable_median", "sos_mae", "failure_rate")]
}
