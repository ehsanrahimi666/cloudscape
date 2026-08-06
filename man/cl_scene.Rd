%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_scene}
\alias{cl_scene}
\title{Construct a scene}
\usage{
cl_scene(reflectance = NULL, sensor, datetime = NULL, solar_geom = NULL,
  view_geom = NULL, dem = NULL, qa = NULL, masks = list(), footprint = NULL,
  id = NULL, manifest = NULL, ...)
}
\arguments{
  \item{reflectance}{A \code{SpatRaster} with layers named using standardised band
  names, or \code{NULL}.}
  \item{sensor}{Sensor id or \code{cl_sensor} driver.}
  \item{datetime}{Acquisition time (\code{POSIXct} or something coercible).}
  \item{solar_geom}{List with \code{zenith} and \code{azimuth} in degrees; either scalars
  (scene-mean) or \code{SpatRaster} layers (per-pixel).}
  \item{view_geom}{List with \code{zenith} and \code{azimuth} in degrees.}
  \item{dem}{Optional elevation \code{SpatRaster} aligned to \code{reflectance}.}
  \item{qa}{Optional QA \code{SpatRaster}.}
  \item{masks}{Named list of \code{cl_maskset} objects.}
  \item{footprint}{Optional lon/lat vertex matrix or \code{sf} geometry.}
  \item{id}{Scene identifier.}
  \item{manifest}{A \code{cl_manifest}.}
  \item{...}{Additional metadata stored verbatim.}
}
\description{
A \code{cl_scene} bundles everything an algorithm needs for one acquisition.
Reflectance is held as a \code{terra::SpatRaster}, which is itself lazy: pixels
stay on disk until a computation forces them into memory. Attaching a DEM,
solar geometry or QA layer never triggers a read.
}
\value{
An object of class \code{cl_scene}.
}
