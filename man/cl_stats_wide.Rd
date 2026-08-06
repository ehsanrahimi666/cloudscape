%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_stats_wide}
\alias{cl_stats_wide}
\title{Reshape statistics from long to wide}
\usage{
cl_stats_wide(x, metrics = NULL)
}
\arguments{
  \item{x}{A \code{cl_stats}.}
  \item{metrics}{Metrics to include; defaults to all.}
}
\description{
Reshape statistics from long to wide
}
\value{
A data frame with one row per cell/period/sensor and one column per
  metric.
}
