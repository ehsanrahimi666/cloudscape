%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_shadow_offset}
\alias{cl_shadow_offset}
\title{Ground displacement of a cloud shadow}
\usage{
cl_shadow_offset(height, sun_zenith, sun_azimuth, view_zenith = 0,
  view_azimuth = 0, correct_parallax = TRUE)
}
\arguments{
  \item{height}{Cloud-top height above the surface, in metres.}
  \item{sun_zenith}{Solar zenith angle in degrees (0 = overhead).}
  \item{sun_azimuth}{Solar azimuth in degrees clockwise from north, giving the
  compass direction \emph{of} the sun.}
  \item{view_zenith}{Sensor viewing geometry in degrees. Defaults
  assume nadir viewing.}
  \item{view_azimuth}{Sensor viewing geometry in degrees. Defaults
  assume nadir viewing.}
  \item{correct_parallax}{Apply the viewing-geometry correction.}
}
\description{
For a cloud top at height \code{height} above the surface, illuminated with solar
zenith angle \code{sun_zenith} and solar azimuth \code{sun_azimuth}, the shadow falls
at a horizontal distance \code{height * tan(sun_zenith)} in the direction the
sunlight travels, that is, \code{sun_azimuth + 180} degrees.

A second, smaller displacement arises because the satellite does not view
the cloud from nadir: an elevated cloud is imaged away from the ground point
it actually sits above. Landsat's field of view is narrow enough that this
is often neglected, but across a Sentinel-2 swath it reaches roughly
0.19 times the cloud height and is worth correcting.
}
\value{
A matrix with columns \code{dx} (metres east) and \code{dy} (metres north),
  giving the offset from the observed cloud position to the shadow position.
}
\examples{
# Sun due south at 45 degrees zenith: a 1 km cloud casts a 1 km shadow north
cl_shadow_offset(1000, sun_zenith = 45, sun_azimuth = 180)

# Sun in the east: shadow falls to the west
cl_shadow_offset(1000, sun_zenith = 45, sun_azimuth = 90)
}
