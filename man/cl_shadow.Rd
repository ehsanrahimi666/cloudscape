%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_shadow}
\alias{cl_shadow}
\title{Detect cloud shadows}
\usage{
cl_shadow(cloud, nir = NULL, swir = NULL, bt = NULL, water = NULL, res = 30,
  sun_zenith = 40, sun_azimuth = 180, view_zenith = 0, view_azimuth = 0,
  method = c("geometric", "darkness", "union"), heights = seq(200, 12000, by
  = 200), buffer = 0, dark_threshold = 0.12)
}
\arguments{
  \item{cloud}{Logical/0-1 cloud matrix or \code{SpatRaster}.}
  \item{nir}{Reflectance matrices used to build the darkness index. NIR
  alone is workable; adding SWIR sharply reduces confusion with water.}
  \item{swir}{Reflectance matrices used to build the darkness index. NIR
  alone is workable; adding SWIR sharply reduces confusion with water.}
  \item{bt}{Optional brightness temperature for height estimation.}
  \item{water}{Optional logical matrix of water pixels, excluded from shadow.}
  \item{res}{Pixel size in metres.}
  \item{sun_zenith}{Geometry in degrees.}
  \item{sun_azimuth}{Geometry in degrees.}
  \item{view_zenith}{Geometry in degrees.}
  \item{view_azimuth}{Geometry in degrees.}
  \item{method}{\code{"geometric"} searches heights against a darkness layer;
  \code{"darkness"} thresholds the darkness index alone, ignoring geometry;
  \code{"union"} returns the geometric union across all heights.}
  \item{heights}{Candidate heights in metres.}
  \item{buffer}{Dilate the resulting shadow by this many pixels.}
  \item{dark_threshold}{Relative darkening counted as shadow; see
  \code{\link{cl_shadow_project}}.}
}
\description{
High-level entry point combining a darkness index, geometric projection and
optional thermal height constraint.
}
\value{
A \code{cl_maskset} with the shadow layer populated.
}
