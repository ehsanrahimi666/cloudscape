%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_gaps}
\alias{cl_gaps}
\title{Cloud-gap statistics}
\usage{
cl_gaps(obs, threshold = 0.2, by = c("year", "all", "season"), include_edges
  = TRUE, critical = 30)
}
\arguments{
  \item{obs}{A \code{cl_obs} table.}
  \item{threshold}{Maximum cloud fraction for a usable observation.}
  \item{by}{Period granularity for reporting.}
  \item{include_edges}{Count the intervals from period start to first clear
  observation and from last clear observation to period end.}
  \item{critical}{Gap length in days whose exceedance frequency is reported.}
}
\description{
Mean cloud cover is a poor summary of whether a time series is workable.
What breaks a phenology retrieval is not the average, it is the longest
stretch with no usable observation. \code{cl_gaps()} reports that stretch, its
distribution, and the return period of gaps exceeding a stated length.

Gaps at the boundaries of the analysis window are included by default,
because a cell whose first clear observation arrives in April has genuinely
lost the spring green-up regardless of how many observations follow.
}
\value{
A \code{cl_stats} table with \code{max_gap_days} and \code{mean_gap_days}, carrying
  an attribute \code{exceedance} giving the fraction of periods per cell in which
  \code{critical} was exceeded.
}
