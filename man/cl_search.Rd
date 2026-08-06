%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_search}
\alias{cl_search}
\title{Search a catalogue for scenes}
\usage{
cl_search(aoi, sensor, start, end, max_cloud = 100, limit = 500, backend =
  NULL, retries = 5L, extra = list())
}
\arguments{
  \item{aoi}{Area of interest: a numeric bounding box \code{c(xmin, ymin, xmax,
  ymax)} in degrees, or an \code{sf} object.}
  \item{sensor}{Sensor id or alias.}
  \item{start}{Date range.}
  \item{end}{Date range.}
  \item{max_cloud}{Maximum scene cloud cover in percent.}
  \item{limit}{Maximum items to return; \code{Inf} fetches all pages.}
  \item{backend}{Catalogue backend.}
  \item{retries}{Number of attempts per HTTP request before giving up.
  Retries are applied to each page individually, with exponential backoff
  and respect for any \code{Retry-After} header. This matters more than it
  sounds: a large query spans many pages, and retrying the whole query
  after a failure on the last page discards every page already fetched and
  hits the service harder each time.}
  \item{extra}{Additional STAC query fields.}
}
\description{
Queries a STAC API and returns a normalised item table. Provider-specific
property names are translated to a common vocabulary so that downstream code
never branches on the backend.
}
\value{
A data frame of class \code{cl_items} with columns \code{id}, \code{datetime},
  \code{sensor}, \code{platform}, \code{cloud_cover}, \code{path_row} or \code{tile}, \code{geometry_bbox}
  and \code{assets}.
}
