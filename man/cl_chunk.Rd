%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_chunk}
\alias{cl_chunk}
\title{Plan chunked processing of a large raster}
\usage{
cl_chunk(nrow, ncol, n_layers = 1L, budget = NULL)
}
\arguments{
  \item{nrow}{Raster dimensions.}
  \item{ncol}{Raster dimensions.}
  \item{n_layers}{Number of layers held simultaneously.}
  \item{budget}{Target pixels in memory at once.}
}
\description{
Returns row blocks sized to the configured pixel budget. Working in blocks is
what allows continental analysis on ordinary hardware; the block size is
exposed rather than hidden so that it can be tuned to available memory.
}
\value{
A data frame with \code{block}, \code{row_start}, \code{n_rows}.
}
\examples{
cl_chunk(10000, 10000, n_layers = 8)
}
