%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_pheno_fit}
\alias{cl_pheno_fit}
\title{Fit a seasonal trajectory and extract phenological metrics}
\usage{
cl_pheno_fit(doy, value, model = c("dbl_logistic", "spline"), threshold =
  0.5, start = NULL)
}
\arguments{
  \item{doy}{Day of year of each observation.}
  \item{value}{Observed index values.}
  \item{model}{\code{"dbl_logistic"} or \code{"spline"}.}
  \item{threshold}{Amplitude fraction defining SOS and EOS for the threshold
  extraction, following common practice.}
  \item{start}{Optional named list of starting values for the double
  logistic, with elements \code{base}, \code{amplitude}, \code{sos}, \code{eos}, \code{slope_up} and
  \code{slope_down} in any order. Values outside the parameter bounds are moved
  to the nearest bound. When \code{NULL} (the default), starting values are
  derived from the data, as described above.}
}
\description{
Fits a double-logistic curve or a smoothing spline to the observations, and
extracts the start and end of season as the days on which the fitted curve
crosses \code{threshold} of its amplitude before and after the peak.

For the double logistic, the position of the season is located before the
nonlinear fit. With the transition dates and rates held fixed, the model is
linear in \code{base} and \code{amplitude}, so every candidate pair of start and end
dates on a five-day grid has a closed-form least-squares fit. The pair with
the smallest residual sum of squares starts the optimiser. If that fit does
not converge, the best pair at a start date at least 30 days away is tried,
and then \code{sos = 110}, \code{eos = 290}. The first converged fit is returned.
}
\value{
A list with \code{sos}, \code{eos}, \code{los}, \code{peak_doy}, \code{peak_value},
  \code{converged} and \code{fit}.
}
