%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_grid}
\alias{cl_grid}
\title{Define an equal-area analysis grid}
\usage{
cl_grid(res = NULL, crs = NULL, extent = "global")
}
\arguments{
  \item{res}{Cell size in metres. Common choices are 100000 for global
  overviews, 25000 for continental analysis and 5000 for regional work.}
  \item{crs}{EPSG code of the equal-area CRS. Only 6933 is supported by the
  built-in closed-form projection; other codes require \code{sf}.}
  \item{extent}{Either \code{"global"} or a numeric vector
  \code{c(xmin, ymin, xmax, ymax)} in \strong{degrees}.}
}
\description{
Define an equal-area analysis grid
}
\value{
An object of class \code{cl_grid}.
}
\examples{
g <- cl_grid(res = 100000)
g
nrow(cl_grid_cells(g)) > 0
}
