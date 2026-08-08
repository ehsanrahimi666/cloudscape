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
  \item{include_cirrus}{Treat flagged cirrus as cloud.}
  \item{confidence}{Minimum confidence level (\code{"low"}, \code{"medium"}, \code{"high"})
  for bit-packed QA with confidence fields.}
}
\description{
Translates a bit-packed or categorical QA band into the standard class
vocabulary of \code{\link{cl_classes}}, using the sensor driver's specification.
}
\value{
A list of logical matrices: \code{cloud}, \code{shadow}, \code{snow}, \code{water},
  \code{fill}, plus \code{class} in the standard vocabulary.
}
