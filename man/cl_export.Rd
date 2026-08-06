%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_export}
\alias{cl_export}
\title{Export cloudscape objects}
\usage{
cl_export(x, file, format = c("auto", "csv", "rds", "geojson", "tif"))
}
\arguments{
  \item{x}{A \code{cl_stats}, \code{cl_maskset} or \code{cl_obs}.}
  \item{file}{Output path.}
  \item{format}{Output format; \code{"auto"} infers from the extension.}
}
\description{
Export cloudscape objects
}
\value{
The output path, invisibly.
}
