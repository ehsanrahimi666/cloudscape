%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_clear_obs}
\alias{cl_clear_obs}
\title{Clear observation counts per cell and period}
\usage{
cl_clear_obs(obs, by = c("year", "month", "season", "all"), threshold = 0.2,
  model = c("independent", "clustered", "empirical"), grid = NULL)
}
\arguments{
  \item{obs}{A \code{cl_obs} table.}
  \item{by}{Period granularity: \code{"year"}, \code{"month"}, \code{"season"} or \code{"all"}.}
  \item{threshold}{Maximum cloud fraction for an observation to count as
  usable.}
  \item{model}{Clear-probability model, see \code{\link{cl_clear_prob}}.}
  \item{grid}{Optional \code{cl_grid} recorded on the output.}
}
\description{
Clear observation counts per cell and period
}
\value{
A \code{cl_stats} table with metrics \code{n_scenes}, \code{n_clear_obs},
  \code{cloud_fraction} and \code{p_clear}.
}
\examples{
set.seed(1)
o <- cl_obs(cell = rep(1:2, each = 40),
            date = rep(seq(as.Date("2023-01-01"), by = "9 days", length.out = 40), 2),
            cloud_fraction = c(runif(40, 0, .4), runif(40, .5, 1)),
            sensor = "sentinel-2-msi")
summary(cl_clear_obs(o, by = "year"))
}
