%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_qa_spec}
\alias{cl_qa_spec}
\title{Describe a quality-assessment band}
\usage{
cl_qa_spec(type, asset, bits = NULL, confidence = NULL, classes = NULL,
  clear = NULL)
}
\arguments{
  \item{type}{\code{"bitmask"} or \code{"categorical"}.}
  \item{asset}{Asset name of the QA layer.}
  \item{bits}{Bit positions (0-indexed) of the flags for \code{type = "bitmask"}:
  a named integer vector of single bits, or a named list whose elements are
  single bits or, for fields of several bits, \code{list(bits = c(lo, hi),
  values = ...)}, the field values that raise the flag. Names should
  include, where available, \code{cloud}, \code{cloud_shadow}, \code{snow}, \code{cirrus},
  \code{water}, \code{fill}, \code{dilated_cloud}.}
  \item{confidence}{Named list of two-bit confidence field positions, e.g.
  \code{list(cloud = c(8, 9))}, giving low/medium/high gradations.}
  \item{classes}{Named integer vector mapping class labels to codes for
  \code{type = "categorical"}.}
  \item{clear}{Character vector of the class names of valid, cloud-free
  pixels for \code{type = "categorical"}. Classes that are neither in \code{clear} nor
  cloud, cloud-shadow or snow classes are treated as invalid. With \code{NULL},
  every class except \code{no_data} is valid.}
}
\description{
QA layers come in two flavours: bit-packed (Landsat \code{QA_PIXEL}) and
categorical (Sentinel-2 \code{SCL}). \code{cl_qa_spec()} describes either so that
\code{\link{cl_probability}} with \code{method = "qa"} can decode any sensor uniformly.
}
\value{
An object of class \code{cl_qa_spec}.
}
