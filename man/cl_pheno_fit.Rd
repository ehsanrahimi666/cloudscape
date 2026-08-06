%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_pheno_fit}
\alias{cl_pheno_fit}
\title{Fit a seasonal trajectory and extract phenological metrics}
\usage{
cl_pheno_fit(doy, value, model = c("dbl_logistic", "spline"), threshold =
  0.5, start = NULL)
}
\arguments{
  \item{doy}{Day of year of each observation.}
  \item{value}{Observed index values.}
  \item{model}{\code{"dbl_logistic"} or \code{"spline"}.}
  \item{threshold}{Amplitude fraction defining SOS and EOS for the threshold
  extraction, following common practice.}
  \item{start}{Optional named list of starting values.}
}
\description{
Fit a seasonal trajectory and extract phenological metrics
}
\value{
A list with \code{sos}, \code{eos}, \code{los}, \code{peak_doy}, \code{peak_value},
  \code{converged} and \code{fit}.
}
