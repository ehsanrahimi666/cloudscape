%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_pheno_curve}
\alias{cl_pheno_curve}
\title{Double-logistic seasonal trajectory}
\usage{
cl_pheno_curve(doy, base = 0.15, amplitude = 0.6, sos = 120, eos = 280,
  slope_up = 0.12, slope_down = 0.10)
}
\arguments{
  \item{doy}{Day of year.}
  \item{base}{Winter baseline value.}
  \item{amplitude}{Seasonal amplitude.}
  \item{sos}{Start and end of season, in days.}
  \item{eos}{Start and end of season, in days.}
  \item{slope_up}{Transition rates.}
  \item{slope_down}{Transition rates.}
}
\description{
The standard four-phase form used across land-surface phenology.
}
\value{
Numeric vector of index values.
}
\examples{
plot_ready <- cl_pheno_curve(1:365)
round(range(plot_ready), 3)
}
