%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_manifest}
\alias{cl_manifest}
\title{Create or extract a provenance manifest}
\usage{
cl_manifest(x = NULL, ...)
}
\arguments{
  \item{x}{An object with a manifest, or \code{NULL} to build a fresh one.}
  \item{...}{Named fields to record.}
}
\description{
Satellite archives are reprocessed. Collection 2 changed Landsat cloud
masking relative to Collection 1, and successive Sen2Cor baselines changed
the Sentinel-2 scene classification layer. A statistic computed today may
therefore differ from the same statistic computed on the same nominal data
next year. Every cloudscape object carries a manifest recording exactly what
was queried, when, and with which algorithm, so results remain auditable.
}
\value{
An object of class \code{cl_manifest}: a named list.
}
\examples{
m <- cl_manifest(NULL, source = "element84", collection = "sentinel-2-l2a")
m$collection
}
