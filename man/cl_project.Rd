%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_project}
\alias{cl_project}
\alias{cl_unproject}
\title{Project longitude/latitude to and from EASE-Grid 2.0 metres}
\usage{
cl_project(lon, lat, lat_ts = 30)
cl_unproject(x, y, lat_ts = 30)
}
\arguments{
  \item{lon}{Longitude and latitude in degrees.}
  \item{lat}{Longitude and latitude in degrees.}
  \item{x}{Projected coordinates in metres.}
  \item{y}{Projected coordinates in metres.}
  \item{lat_ts}{Standard parallel in degrees. 30 gives EPSG:6933.}
}
\description{
Closed-form cylindrical equal-area projection on the WGS84 ellipsoid. These
are provided directly rather than through PROJ so that the analysis grid,
and the tests that verify it, work without a geospatial toolchain.
}
\value{
A two-column matrix with columns \code{x}/\code{y} or \code{lon}/\code{lat}.
}
\examples{
cl_project(c(0, 90), c(0, 45))
cl_unproject(cl_project(10, 50)[, 1], cl_project(10, 50)[, 2])
}
