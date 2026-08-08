%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_indices}
\alias{cl_indices}
\title{Common spectral indices}
\usage{
cl_indices(bands, which = c("ndvi", "ndsi", "ndwi", "whiteness", "hot"))
}
\arguments{
  \item{bands}{Named list of reflectance matrices.}
  \item{which}{Indices to compute.}
}
\description{
Common spectral indices
}
\value{
A named list of matrices.
}
\examples{
b <- list(green = matrix(.1,4,4), red = matrix(.08,4,4),
          nir = matrix(.35,4,4), swir16 = matrix(.2,4,4), blue = matrix(.09,4,4))
names(cl_indices(b))
}
