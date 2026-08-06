%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_scale}
\alias{cl_scale}
\title{Rescale stored integers to reflectance}
\usage{
cl_scale(x, sensor = NULL, clamp = c(0, 1.6))
}
\arguments{
  \item{x}{A \code{cl_scene} or named list of matrices.}
  \item{sensor}{Sensor id, when \code{x} is a list.}
  \item{clamp}{Clip to a physically plausible range.}
}
\description{
Rescale stored integers to reflectance
}
\value{
The rescaled object.
}
