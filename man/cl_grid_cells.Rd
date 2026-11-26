%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_grid_cells}
\alias{cl_grid_cells}
\title{Cell identifiers, centroids and areas}
\usage{
cl_grid_cells(grid, cells = NULL)
}
\arguments{
  \item{grid}{A \code{cl_grid}.}
  \item{cells}{Optional integer vector of cell ids; defaults to all cells.
  Supplying ids avoids materialising a global table.}
}
\description{
Cells are numbered row-major from the top-left, matching raster convention.
Because the grid is equal-area, every cell has an area of \code{res^2} square
metres regardless of latitude. Cells of the outermost rows and columns of a
global grid can extend past the poles or the antimeridian, where the
projection has no surface; their \code{area_km2} is the part inside the
projection's domain.
}
\value{
A data frame with \code{cell}, \code{row}, \code{col}, \code{x}, \code{y}, \code{lon}, \code{lat},
  \code{area_km2}.
}
