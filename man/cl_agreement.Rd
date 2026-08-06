%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_agreement}
\alias{cl_agreement}
\title{Agreement among several masks}
\usage{
cl_agreement(masks)
}
\arguments{
  \item{masks}{Named list of \code{cl_maskset} objects or 0/1 matrices.}
}
\description{
Agreement among several masks
}
\value{
A list with \code{agreement} (fraction of methods calling cloud),
  \code{consensus} (majority mask), \code{entropy} (binary entropy of the vote) and
  \code{unanimous} (logical matrix).
}
\examples{
a <- matrix(c(1,1,0,0), 2, 2); b <- matrix(c(1,0,0,0), 2, 2)
cl_agreement(list(a = a, b = b))$agreement
}
