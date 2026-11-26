%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_synergy}
\alias{cl_synergy}
\title{Multi-constellation revisit synergy}
\usage{
cl_synergy(sensors, start, end, by = c("year", "month"), latitude = 0)
}
\arguments{
  \item{sensors}{Character vector of sensor ids or aliases.}
  \item{start}{Analysis period.}
  \item{end}{Analysis period.}
  \item{by}{Reporting granularity, \code{"year"} or \code{"month"}.}
  \item{latitude}{Optional latitude used to inflate the number of
  acquisitions for orbital side-lap, approximated as \code{1 / cos(latitude)}.}
}
\description{
Answers the question a study designer actually asks: if I combine these
sensors, how many observations do I get, and how does that change through
time?

Effective revisit is not a constant. Landsat 9 joined Landsat 8 in late
2021, roughly halving the Landsat interval from that point; Sentinel-2B
joined 2A in 2017 and 2C in 2024. A study spanning 2014 to the present
therefore has a non-stationary sampling density, and comparing early and
late years without accounting for it confounds acquisition capacity with
whatever is being measured.
}
\value{
A data frame with columns \code{period}, \code{sensor}, \code{days} (days of the
  period inside \code{start} to \code{end}), \code{n_platforms} (platform-years or
  platform-months in operation divided by the period length), \code{nominal_obs}
  (acquisitions of one platform at the nominal revisit), \code{combined_obs}
  and \code{effective_revisit_days} (\code{days / combined_obs}). Periods cut by
  \code{start} or \code{end} are reported for the days they contain.
}
\examples{
cl_synergy(c("landsat-8-9-oli", "sentinel-2-msi"),
           start = "2015-01-01", end = "2025-12-31", by = "year")[1:6, ]
}
