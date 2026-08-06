%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_options}
\alias{cl_options}
\title{Get or set package options}
\usage{
cl_options(...)
}
\arguments{
  \item{...}{Named options to set. Supported names:
  \\describe\{
    \item\{\code{catalog}\}\{Default STAC backend, one of \code{"element84"},
      \code{"planetary"}, \code{"cdse"}.\}
    \item\{\code{grid_res}\}\{Default analysis grid resolution in metres.\}
    \item\{\code{grid_crs}\}\{EPSG code of the equal-area analysis CRS.
      Defaults to 6933 (EASE-Grid 2.0 global).\}
    \item\{\code{chunk_pixels}\}\{Target pixels per processing block.\}
    \item\{\code{workers}\}\{Number of parallel workers.\}
    \item\{\code{cache_dir}\}\{Directory for downloaded assets and harvest state.\}
    \item\{\code{timeout}\}\{HTTP timeout in seconds.\}
    \item\{\code{max_page}\}\{Maximum STAC items requested per page.\}
    \item\{\code{verbose}\}\{Emit progress messages.\}
  \}}
}
\description{
\code{cl_options()} is the single configuration entry point for cloudscape.
Called with no arguments it returns the full option list. Called with named
arguments it sets them and returns the previous values invisibly, so it can
be used with [base::on.exit()] to make temporary changes.
}
\value{
A named list of options. When setting, the previous values are
  returned invisibly.
}
\examples{
old <- cl_options(verbose = FALSE)
cl_options()$verbose
cl_options(old)
}
