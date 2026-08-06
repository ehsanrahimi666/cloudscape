%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_app}
\alias{cl_app}
\title{Launch the interactive scene explorer}
\usage{
cl_app(stats = NULL, ...)
}
\arguments{
  \item{stats}{Optional \code{cl_stats} to seed the map.}
  \item{...}{Passed to \code{shiny::runApp()}.}
}
\description{
Live imagery browsing needs a server: asset URLs from most catalogues are
signed and expire, and masks are computed on demand. This is therefore a
Shiny application rather than a static file.
}
\value{
Invisibly \code{NULL}.
}
