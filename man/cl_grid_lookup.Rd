%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_grid_lookup}
\alias{cl_grid_lookup}
\title{Locate cells from coordinates}
\usage{
cl_grid_lookup(grid, lon, lat)
}
\arguments{
  \item{grid}{A \code{cl_grid}.}
  \item{lon}{Coordinates in degrees.}
  \item{lat}{Coordinates in degrees.}
}
\description{
Locate cells from coordinates
}
\value{
Integer vector of cell ids, \code{NA} outside the grid.
}
