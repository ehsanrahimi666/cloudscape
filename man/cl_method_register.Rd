%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_method_register}
\alias{cl_method_register}
\title{Register a cloud-probability method}
\usage{
cl_method_register(name, fun, requires, optional = character(), type =
  "physical", reference = NA_character_, overwrite = FALSE)
}
\arguments{
  \item{name}{Method name.}
  \item{fun}{Function with signature \code{(bands, geom, drv, ...)} returning a
  numeric matrix of probabilities in \\[0, 1\\].}
  \item{requires}{Standardised band names the method needs.}
  \item{optional}{Bands the method uses if present.}
  \item{type}{\code{"physical"}, \code{"statistical"} or \code{"learned"}.}
  \item{reference}{Short citation.}
  \item{overwrite}{Replace an existing registration.}
}
\description{
Register a cloud-probability method
}
\value{
The method name, invisibly.
}
