%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_sensor_driver}
\alias{cl_sensor_driver}
\title{Construct a sensor driver}
\usage{
cl_sensor_driver(id, name, bands, resolution = NULL, platforms = NULL,
  footprint = "none", revisit = NA_real_, qa = NULL, scale = 1, offset = 0,
  collections = list(), cloud_property = "eo:cloud_cover", has_thermal =
  FALSE, has_cirrus = FALSE, notes = NULL)
}
\arguments{
  \item{id}{Short identifier, e.g. \code{"landsat-8-9-oli"}.}
  \item{name}{Human-readable name.}
  \item{bands}{Named character vector mapping standardised band names to the
  asset or layer names used by this sensor.}
  \item{resolution}{Named numeric vector of native resolutions in metres,
  using the same standardised band names.}
  \item{platforms}{\code{data.frame} with columns \code{platform}, \code{start}, \code{end}
  giving the operational period of each satellite in the constellation.
  \code{end} may be \code{NA} for currently active platforms. Used by \code{\link{cl_synergy}}
  to compute time-varying revisit.}
  \item{footprint}{Footprint geometry type: \code{"wrs2"}, \code{"mgrs"}, \code{"sinusoidal"},
  \code{"scene"} or \code{"none"}.}
  \item{revisit}{Nominal revisit interval in days for a single platform.}
  \item{qa}{Optional QA specification created by \code{\link{cl_qa_spec}}.}
  \item{scale}{Linear rescaling from stored integers to reflectance.}
  \item{offset}{Linear rescaling from stored integers to reflectance.}
  \item{collections}{Named list mapping catalogue backends to collection ids.}
  \item{cloud_property}{Name of the scene-level cloud-cover property in
  catalogue metadata.}
  \item{has_thermal}{Logical capability flags. Algorithms that
  require these bands check the flags and degrade gracefully.}
  \item{has_cirrus}{Logical capability flags. Algorithms that
  require these bands check the flags and degrade gracefully.}
  \item{notes}{Free text recorded in manifests.}
}
\description{
A sensor driver is the single point of sensor-specific knowledge in
cloudscape. Algorithms address bands by standardised names (\code{blue}, \code{nir},
\code{swir16}, \code{cirrus}, \code{tir1}, ...) and the driver translates those into the
asset names a particular catalogue uses. Everything downstream is therefore
sensor-agnostic.
}
\value{
An object of class \code{cl_sensor}.
}
\examples{
drv <- cl_sensor("landsat-8-9-oli")
drv$bands[["cirrus"]]
}
