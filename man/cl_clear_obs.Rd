%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_clear_obs}
\alias{cl_clear_obs}
\title{Clear observation counts per cell and period}
\usage{
cl_clear_obs(obs, by = c("year", "month", "season", "all"), threshold = 0.2,
  model = c("independent", "clustered", "empirical"), grid = NULL, coverage
  = TRUE)
}
\arguments{
  \item{obs}{A \code{cl_obs} table.}
  \item{by}{Period granularity: \code{"year"}, \code{"month"}, \code{"season"} or \code{"all"}.
  Seasons are meteorological (DJF, MAM, JJA, SON), with December counted in
  the following year's DJF.}
  \item{threshold}{Usability threshold. An observation is usable when at
  least \code{1 - threshold} of the cell was observed and cloud-free (with
  \code{coverage = TRUE}) or when its cloud fraction is at most \code{threshold}.}
  \item{model}{Clear-probability model, see \code{\link{cl_clear_prob}}.}
  \item{grid}{Optional \code{cl_grid} recorded on the output.}
  \item{coverage}{Take the valid share of the cell into account; see
  \code{\link{cl_clear_prob}}. Tables without a \code{valid_fraction} column are treated
  as fully observed.}
}
\description{
Clear observation counts per cell and period
}
\value{
A \code{cl_stats} table with metrics \code{n_scenes} (acquisitions),
  \code{n_clear_obs} (usable acquisitions), \code{cloud_fraction} and \code{p_clear}, the
  mean of \code{\link{cl_clear_prob}}. With models \code{"independent"} and \code{"empirical"},
  \code{p_clear} times \code{n_scenes} is the expected number of clear observations of
  a pixel at a random location in the cell; with \code{"clustered"} it is the
  expected number of usable acquisitions. Acquisitions without a cloud
  fraction count in \code{n_scenes} but not in the sample size of the other
  metrics.
}
\examples{
set.seed(1)
o <- cl_obs(cell = rep(1:2, each = 40),
            date = rep(seq(as.Date("2023-01-01"), by = "9 days", length.out = 40), 2),
            cloud_fraction = c(runif(40, 0, .4), runif(40, .5, 1)),
            sensor = "sentinel-2-msi")
summary(cl_clear_obs(o, by = "year"))
}
