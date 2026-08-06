%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_methods}
\alias{cl_methods}
\title{List available cloud-probability methods}
\usage{
cl_methods(sensor = NULL)
}
\arguments{
  \item{sensor}{Optional sensor id; when supplied, only methods whose required
  bands the sensor provides are returned.}
}
\description{
List available cloud-probability methods
}
\value{
A data frame of methods.
}
\examples{
cl_methods()
cl_methods(sensor = "sentinel-2-msi")   # no thermal-based methods
}
