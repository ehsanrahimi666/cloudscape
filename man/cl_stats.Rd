%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_stats}
\alias{cl_stats}
\title{Construct a grid statistics table}
\usage{
cl_stats(cell, metric, value, period = NA_character_, sensor =
  NA_character_, n = NA_integer_, se = NA_real_, denominator = "cell-year",
  grid = NULL, manifest = NULL)
}
\arguments{
  \item{cell}{Integer grid cell ids.}
  \item{metric}{Metric name; see \code{\link{cl_metrics}}.}
  \item{value}{Numeric values.}
  \item{period}{Character period labels, e.g. \code{"2023"} or \code{"2023-06"}.}
  \item{sensor}{Sensor ids.}
  \item{n}{Sample size behind each value.}
  \item{se}{Optional standard errors.}
  \item{denominator}{What the value is expressed per: one of \code{"cell"},
  \code{"cell-year"}, \code{"cell-month"}, \code{"scene"}, \code{"pixel"}.}
  \item{grid}{Optional \code{cl_grid} the cells refer to.}
  \item{manifest}{A \code{cl_manifest}.}
}
\description{
\code{cl_stats} is a long-format table: one row per cell, period, sensor and
metric. Every row must declare its \code{unit}, its sample size \code{n}, and the
\code{denominator} the value is expressed per. The constructor validates these
against a controlled vocabulary and refuses out-of-range values.

This strictness is deliberate. A count of images summed over ten years and
then divided by ten is a mean \emph{per year}, not a mean \emph{per scene footprint};
presenting one as the other produces values that are physically impossible
for the stated denominator. Encoding the denominator in the data structure
makes that class of error a validation failure rather than a published
table.
}
\value{
An object of class \code{cl_stats}, which inherits from \code{data.frame}.
}
\examples{
s <- cl_stats(cell = 1:3, metric = "cloud_fraction", value = c(.2, .5, .9),
              period = "2023", sensor = "sentinel-2-msi", n = c(40, 38, 41),
              denominator = "cell-year")
summary(s)
}
