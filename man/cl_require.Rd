%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_require}
\alias{cl_require}
\title{Require a suggested package}
\usage{
cl_require(pkg, reason = NULL)
}
\arguments{
  \item{pkg}{Package name(s).}
  \item{reason}{Short description of what the package is needed for.}
}
\description{
cloudscape keeps its hard dependency surface small: the statistical core
(availability, gaps, seasonality, phenology, evaluation, simulation) runs on
base R alone, while raster and network functionality is gated behind
suggested packages. This helper produces a single actionable error rather
than an opaque failure deep in a call stack.
}
\value{
\code{TRUE} invisibly if all packages are available; otherwise an error.
}
