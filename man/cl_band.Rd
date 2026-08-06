%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_band}
\alias{cl_band}
\title{Extract a band by standardised name}
\usage{
cl_band(x, band, required = TRUE)
}
\arguments{
  \item{x}{A \code{cl_scene}.}
  \item{band}{Standardised band name, e.g. \code{"nir"}.}
  \item{required}{Error if the band is absent.}
}
\description{
Extract a band by standardised name
}
\value{
A \code{SpatRaster} layer, or \code{NULL}.
}
