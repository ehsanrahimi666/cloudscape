%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_grid_index}
\alias{cl_grid_index}
\title{Index sensor footprints onto the analysis grid}
\usage{
cl_grid_index(footprint, grid, method = c("centroid", "area"))
}
\arguments{
  \item{footprint}{Either a two-column matrix or data frame of polygon vertex
  longitudes and latitudes, or an \code{sf} object.}
  \item{grid}{A \code{cl_grid}.}
  \item{method}{\code{"centroid"} or \code{"area"}.}
}
\description{
Converts a scene or tile footprint into a set of grid cells with weights.
Two methods are available. \code{"centroid"} assigns a cell to a footprint when
the cell centroid falls inside it; it is unbiased in expectation, needs no
geospatial dependencies, and is accurate when cells are much smaller than
footprints (the usual case: 25 km cells against 180 km Landsat scenes).
\code{"area"} computes exact fractional overlap and requires \code{sf}; use it when
cell size approaches footprint size.
}
\value{
A data frame with columns \code{cell} and \code{weight}, where \code{weight} is the
  fraction of the cell covered by the footprint (always 1 for
  \code{method = "centroid"}).
}
\examples{
g <- cl_grid(res = 100000)
poly <- cbind(lon = c(0, 2, 2, 0, 0), lat = c(50, 50, 52, 52, 50))
head(cl_grid_index(poly, g))
}
