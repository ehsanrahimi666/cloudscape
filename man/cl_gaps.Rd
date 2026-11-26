%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_gaps}
\alias{cl_gaps}
\title{Cloud-gap statistics}
\usage{
cl_gaps(obs, threshold = 0.2, by = c("year", "all", "season"), include_edges
  = TRUE, critical = 30, coverage = TRUE)
}
\arguments{
  \item{obs}{A \code{cl_obs} table.}
  \item{threshold}{Usability threshold, see \code{\link{cl_clear_obs}}.}
  \item{by}{Period granularity for reporting. Seasons are meteorological
  (DJF, MAM, JJA, SON), with December counted in the following year's DJF.}
  \item{include_edges}{Close the record at the period boundaries (see
  Details). Without edges only intervals between usable observations count,
  and a period with fewer than two usable dates has a single gap of its
  length plus one day.}
  \item{coverage}{Take the valid share of the cell into account, see
  \code{\link{cl_clear_obs}}.}
  \item{critical}{Gap length in days whose exceedance frequency is reported.}
}
\description{
Mean cloud cover is a poor summary of whether a time series is workable.
What breaks a phenology retrieval is not the average, it is the longest
stretch with no usable observation. \code{cl_gaps()} reports that stretch, its
distribution, and the return period of gaps exceeding a stated length.

Gaps at the boundaries of the analysis window are included by default,
because a cell whose first clear observation arrives in April has lost the
spring green-up regardless of how many observations follow. A gap is the
number of days from one usable observation to the next, so observations on
consecutive days are one day apart. At the period boundaries the record is
closed by virtual observations on the day before the period starts and the
day after it ends, so that a usable observation on the first day of the
period leaves a gap of one day, and a period without a usable observation
has a single gap of its length plus one day.

Gap statistics are computed from the observations of one period and are not
combined across periods or inputs afterwards: a gap can span the boundary
between two periods, and adding observations from another input shortens
gaps, so neither the maximum nor the mean of separately computed gaps is the
gap of the combined record. Compute them on the combined observation table
instead.
}
\value{
A \code{cl_stats} table with \code{max_gap_days}, \code{mean_gap_days} and
  \code{n_clear_dates}, the number of distinct dates with a usable observation,
  carrying an attribute \code{exceedance} giving the fraction of periods per cell
  in which \code{critical} was exceeded. Acquisitions without a cloud fraction
  are not usable.
}
