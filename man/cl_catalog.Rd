%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_catalog}
\alias{cl_catalog}
\title{Configure or inspect a catalogue backend}
\usage{
cl_catalog(backend = NULL)
}
\arguments{
  \item{backend}{One of \code{"element84"}, \code{"planetary"}, \code{"cdse"}.}
}
\description{
Configure or inspect a catalogue backend
}
\value{
A list describing the backend.
}
\examples{
cl_catalog("element84")$url
}
