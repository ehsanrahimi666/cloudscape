%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_maskset}
\alias{cl_maskset}
\title{Construct a cloud/shadow mask set}
\usage{
cl_maskset(probability, class = NULL, shadow = NULL, method = NA_character_,
  threshold = NA_real_, manifest = NULL, ...)
}
\arguments{
  \item{probability}{\code{SpatRaster} or numeric matrix of cloud probability in
  \\[0, 1\\].}
  \item{class}{Optional integer \code{SpatRaster}/matrix of class codes. See
  \code{\link{cl_classes}} for the coding.}
  \item{shadow}{Optional shadow probability layer.}
  \item{method}{Name of the generating algorithm.}
  \item{threshold}{Probability threshold used to derive \code{class}.}
  \item{manifest}{A \code{cl_manifest}.}
  \item{...}{Additional algorithm parameters, recorded verbatim.}
}
\description{
Keeping probability and class in one object with the threshold and method
recorded means a mask can always be re-thresholded without recomputation,
and that comparisons between methods carry their own provenance.
}
\value{
An object of class \code{cl_maskset}.
}
