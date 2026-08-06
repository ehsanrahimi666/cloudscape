%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_calibration}
\alias{cl_calibration}
\title{Probability calibration}
\usage{
cl_calibration(prob, truth, bins = 10L)
}
\arguments{
  \item{prob}{Predicted probabilities.}
  \item{truth}{Binary reference.}
  \item{bins}{Number of probability bins.}
}
\description{
A detector can discriminate well and still be badly calibrated, in which case
its probabilities cannot be used to weight observations or propagate
uncertainty. This reports the reliability curve together with the Brier score
and expected calibration error.
}
\value{
A data frame with one row per bin, with \code{brier} and \code{ece} attributes.
}
