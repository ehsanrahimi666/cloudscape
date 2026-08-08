%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_feasibility}
\alias{cl_feasibility}
\title{Sampling design feasibility}
\usage{
cl_feasibility(p_clear, n_acquisitions, n_required, window_days = 365,
  max_gap = NULL, n_sim = 2000)
}
\arguments{
  \item{p_clear}{Per-acquisition probability that the cell is usable.}
  \item{n_acquisitions}{Number of acquisition opportunities in the window.}
  \item{n_required}{Minimum usable observations needed.}
  \item{window_days}{Length of the window in days.}
  \item{max_gap}{Maximum tolerable gap in days, or \code{NULL} to skip.}
  \item{n_sim}{Monte Carlo replicates for the gap calculation.}
}
\description{
Given a clear-sky probability and an acquisition cadence, reports the
probability of obtaining at least \code{n_required} usable observations within a
window, and the probability that no gap exceeds \code{max_gap}.
}
\value{
A list with \code{p_sufficient}, \code{expected_obs}, and, when \code{max_gap} is
  given, \code{p_gap_ok}.
}
\examples{
cl_feasibility(p_clear = 0.35, n_acquisitions = 36, n_required = 12,
               window_days = 365, max_gap = 45)
}
