%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_explore}
\alias{cl_explore}
\title{Export an interactive map of grid statistics}
\usage{
cl_explore(stats, metric, period = NULL, file = "cloudscape.html", grid =
  NULL, palette = c("#2c7bb6", "#ffffbf", "#d7191c"), title = NULL)
}
\arguments{
  \item{stats}{A \code{cl_stats} table.}
  \item{metric}{Metric to display.}
  \item{period}{Optional period filter.}
  \item{file}{Output path.}
  \item{grid}{The \code{cl_grid} the cells refer to; taken from \code{stats} if absent.}
  \item{palette}{Colour ramp endpoints.}
  \item{title}{Map title.}
}
\description{
Writes a self-contained HTML file showing one metric per grid cell. The
output has no server dependency and no expiring URLs, so it can be archived
alongside a manuscript and will still work years later. Live imagery
browsing is a different problem with different constraints and belongs in
\code{\link{cl_app}}.
}
\value{
The output path, invisibly.
}
