%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_qa_obs}
\alias{cl_qa_obs}
\title{Build a quality-layer observation table}
\usage{
cl_qa_obs(items, grid, cells, include_cirrus = TRUE, confidence = "medium",
  overpass_minutes = 20, workers = 1L)
}
\arguments{
  \item{items}{Scenes from \code{\link{cl_search}}.}
  \item{grid}{A grid from \code{\link{cl_grid}}.}
  \item{cells}{Cell identifiers to evaluate.}
  \item{include_cirrus}{Passed to \code{\link{cl_qa_decode}}.}
  \item{confidence}{Passed to \code{\link{cl_qa_decode}}.}
  \item{overpass_minutes}{Tiles acquired within this many minutes are one
  overpass.}
  \item{workers}{Scenes read in parallel by forked processes; forced to 1 on
  Windows.}
}
\description{
Reads each scene's producer quality layer (Landsat \code{QA_PIXEL}, Sentinel-2
\code{SCL}) over the requested grid cells and records, for every
cell-observation, the share of valid pixels flagged as cloud, cloud shadow
and snow. Scene-level cloud cover is an average over a footprint of 10,000
km2 or more and says little about a particular cell; this table measures the
cell itself. It is the \code{"qa"} evidence tier and can be passed to every
function that accepts a \code{cl_obs} table.

A scene contributes to the cells whose centroid lies within its footprint,
as in \code{\link{cl_items_to_obs}}. Pixels are classified with \code{\link{cl_qa_decode}};
a pixel flagged as both cloud and shadow counts as cloud. Tiles acquired
within \code{overpass_minutes} of each other are one observation of a cell, and
the tile with the most valid pixels in the cell is kept. Landsat assets that
the catalogue lists in the requester-pays USGS bucket are read from the
Planetary Computer mirror with an anonymous access token.
}
\value{
A \code{cl_obs} table of tier \code{"qa"}. \code{cloud_fraction},
  \code{shadow_fraction} and \code{snow_fraction} are shares of the valid pixels in the
  cell; \code{valid_fraction} is the share of the cell with valid data, \code{n_valid}
  the number of valid pixels and \code{id} the scene kept. Cell-observations
  without valid pixels are dropped. Attribute \code{"failed"} holds the
  identifiers of scenes that could not be read.
}
