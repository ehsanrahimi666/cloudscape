%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_qa_decode}
\alias{cl_qa_decode}
\title{Decode a producer quality layer}
\usage{
cl_qa_decode(qa, sensor, include_cirrus = TRUE, confidence = "medium")
}
\arguments{
  \item{qa}{QA matrix or \code{SpatRaster}.}
  \item{sensor}{Sensor id or driver.}
  \item{include_cirrus}{Treat flagged cirrus as cloud. Ignored for sensors
  whose QA has no cirrus flag.}
  \item{confidence}{Minimum cloud confidence (\code{"medium"} or \code{"high"}) for
  bit-packed QA with confidence fields. Pixels at or above it are cloud, in
  addition to those with the cloud bit set. The lowest level is not offered
  because the Landsat Collection 2 algorithm assigns it to almost all clear
  pixels.}
}
\description{
Translates a bit-packed or categorical QA band into the standard class
vocabulary of \code{\link{cl_classes}}, using the sensor driver's specification.

For bit-packed layers, each flag is either a single bit or a field of
several bits with the values that raise it (see \code{\link{cl_qa_spec}}); flags the
specification does not define are never raised. For categorical layers,
pixels whose code is neither a cloud, cloud-shadow or snow class nor listed
in the specification's \code{clear} set are invalid and reported as \code{fill}. For
Sentinel-2 \code{SCL} this marks no-data and saturated or defective pixels
(classes 0 and 1) as invalid, and counts topographic cast shadow (class 2),
vegetation, bare soil, water and unclassified pixels (classes 4 to 7) as
valid and cloud-free. Missing values are invalid for both types.
}
\value{
A list of logical matrices: \code{cloud}, \code{shadow}, \code{snow}, \code{water},
  \code{fill}, plus \code{class} in the standard vocabulary.
}
