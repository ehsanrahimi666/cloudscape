%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_geometry}
\alias{cl_geometry}
\title{Attach or compute scene geometry}
\usage{
cl_geometry(x, lon = NULL, lat = NULL)
}
\arguments{
  \item{x}{A \code{cl_scene}.}
  \item{lon}{Scene centre, used when metadata angles are absent.}
  \item{lat}{Scene centre, used when metadata angles are absent.}
}
\description{
Attach or compute scene geometry
}
\value{
The scene with \code{solar_geom} populated.
}
