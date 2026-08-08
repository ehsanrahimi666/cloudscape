%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_solar_position}
\alias{cl_solar_position}
\title{Solar position for a location and time}
\usage{
cl_solar_position(datetime, lon, lat)
}
\arguments{
  \item{datetime}{\code{POSIXct} in UTC.}
  \item{lon}{Coordinates in degrees.}
  \item{lat}{Coordinates in degrees.}
}
\description{
A compact solar position algorithm, accurate to a few hundredths of a degree
over the satellite era, used when a scene lacks per-pixel angle grids.
}
\value{
A data frame with \code{zenith} and \code{azimuth} in degrees.
}
\examples{
cl_solar_position(as.POSIXct("2023-06-21 12:00:00", tz = "UTC"), 0, 51.5)
}
