%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_items_to_obs}
\alias{cl_items_to_obs}
\title{Convert catalogue items to an observation table}
\usage{
cl_items_to_obs(items, grid, method = "centroid", overpass_minutes = 20)
}
\arguments{
  \item{items}{A \code{cl_items} table.}
  \item{grid}{A \code{cl_grid}.}
  \item{method}{Footprint indexing method, see \code{\link{cl_grid_index}}.}
  \item{overpass_minutes}{Scenes covering the same cell within this many
  minutes are treated as one observation. A sensor tiles a single overpass
  into several products - Sentinel-2 into MGRS tiles, Landsat into
  consecutive WRS-2 rows - and every tile covering a cell would otherwise be
  counted as a separate observation of it. In a 100 x 100 km test area this
  inflated Sentinel-2 counts by a factor of 4.6 to 7.9 and Landsat by 1.8,
  which in turn made cloud gaps look shorter and time-series retrieval look
  far easier than it is. Separate orbits on the same day are hours apart and
  remain distinct.}
}
\description{
Maps scene footprints onto the equal-area analysis grid and attaches the
scene-level cloud fraction to every intersecting cell. This is tier A: fast
and global, but the cloud fraction is a scene average, so the resulting
clear-observation counts should be read as an optimistic bound. See
\code{\link{cl_clear_prob}}.
}
\value{
A \code{cl_obs} table with tier \code{"metadata"}, one row per cell per
  overpass. Items whose cloud-cover property is missing are excluded with a
  warning rather than silently treated as clear.
}
