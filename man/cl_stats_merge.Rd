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
combination rule declared for each metric in \code{\link{cl_metrics}}: counts add and
fractions and probabilities combine as means weighted by the number of
observations behind each value (\code{n}). Gap statistics, counts of distinct
usable dates and errors of phenological dates (rule \code{"none"}) cannot be
recovered from summaries: a gap can span the boundary between two inputs,
observations from another input shorten it, and two inputs can share a
date. Rows of these metrics that would have to be combined are returned as
\code{NA} with a warning; compute them from the combined observation table
instead. A combined value is also \code{NA}, with a warning, when one of its
parts is missing or, for weighted means, has no sample size.

The rules are valid for \emph{disjoint} evidence with denominators counted in
the same unit, such as separate sensors or separate sets of acquisitions of
one cell and period. They cannot repair double counting: if the same
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
