%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_cube}
\alias{cl_cube}
\title{Construct a lazy scene collection}
\usage{
cl_cube(scenes, template = NULL, grid = NULL, manifest = NULL)
}
\arguments{
  \item{scenes}{A list of \code{cl_scene} objects, or a data frame index with at
  least the columns \code{id}, \code{datetime}, \code{sensor} and \code{href}.}
  \item{template}{Optional \code{SpatRaster} defining target grid, extent and CRS.}
  \item{grid}{Optional \code{cl_grid} for statistical aggregation.}
  \item{manifest}{A \code{cl_manifest}.}
}
\description{
A \code{cl_cube} never holds pixels. It holds an index of scenes plus a template
describing the target geometry, and materialises blocks on demand. This is
what allows a decade of imagery to be summarised without exhausting memory.
}
\value{
An object of class \code{cl_cube}.
}
