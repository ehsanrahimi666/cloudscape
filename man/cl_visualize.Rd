%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_visualize}
\alias{cl_visualize}
\title{Quick look at a mask or scene}
\usage{
cl_visualize(x, what = c("probability", "class", "shadow"), ...)
}
\arguments{
  \item{x}{A \code{cl_maskset}, \code{cl_scene} or matrix.}
  \item{what}{For a maskset, \code{"probability"}, \code{"class"} or \code{"shadow"}.}
  \item{...}{Passed to [graphics::image()].}
}
\description{
Quick look at a mask or scene
}
\value{
Invisibly \code{x}.
}
