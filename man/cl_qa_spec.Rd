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
  \item{bits}{Named integer vector of bit positions (0-indexed) for
  \code{type = "bitmask"}. Names should include, where available, \code{cloud},
  \code{cloud_shadow}, \code{snow}, \code{cirrus}, \code{water}, \code{fill}, \code{dilated_cloud}.}
  \item{confidence}{Named list of two-bit confidence field positions, e.g.
  \code{list(cloud = c(8, 9))}, giving low/medium/high gradations.}
  \item{classes}{Named integer vector mapping class labels to codes for
  \code{type = "categorical"}.}
  \item{clear}{Character vector of class names considered clear.}
}
\description{
QA layers come in two flavours: bit-packed (Landsat \code{QA_PIXEL}) and
categorical (Sentinel-2 \code{SCL}). \code{cl_qa_spec()} describes either so that
\code{\link{cl_probability}} with \code{method = "qa"} can decode any sensor uniformly.
}
\value{
An object of class \code{cl_qa_spec}.
}
