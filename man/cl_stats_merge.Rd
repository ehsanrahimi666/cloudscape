%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_stats_merge}
\alias{cl_stats_merge}
\title{Combine statistics tables}
\usage{
cl_stats_merge(..., grid = NULL)
}
\arguments{
  \item{...}{\code{cl_stats} tables.}
  \item{grid}{Optional \code{cl_grid} recorded on the result.}
}
\description{
Merges rows describing the same cell, period, sensor and metric, using the
combination rule declared for each metric in \code{\link{cl_metrics}}: counts add,
fractions and rates combine as sample-size-weighted means, and maximum gap
takes the maximum.

This is for combining \emph{disjoint} evidence, such as separate years, sensors
or spatial partitions. It cannot repair double counting: if the same
acquisition was aggregated into two inputs, summing the counts will inflate
them. Deduplicate at the observation level before aggregating.
}
\value{
A single \code{cl_stats} table.
}
\examples{
a <- cl_stats(1:2, "n_scenes", c(10, 12), period = "2023", n = c(10, 12))
b <- cl_stats(1:2, "n_scenes", c(5, 6), period = "2023", n = c(5, 6))
cl_stats_merge(a, b)$value
}
