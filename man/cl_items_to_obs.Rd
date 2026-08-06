%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_items_to_obs}
\alias{cl_items_to_obs}
\title{Convert catalogue items to an observation table}
\usage{
cl_items_to_obs(items, grid, method = "centroid")
}
\arguments{
  \item{items}{A \code{cl_items} table.}
  \item{grid}{A \code{cl_grid}.}
  \item{method}{Footprint indexing method, see \code{\link{cl_grid_index}}.}
}
\description{
Maps scene footprints onto the equal-area analysis grid and attaches the
scene-level cloud fraction to every intersecting cell. This is tier A: fast
and global, but the cloud fraction is a scene average, so the resulting
clear-observation counts should be read as an optimistic bound. See
\code{\link{cl_clear_prob}}.
}
\value{
A \code{cl_obs} table with tier \code{"metadata"}. Items whose cloud-cover
  property is missing are excluded with a warning rather than silently
  treated as clear.
}
