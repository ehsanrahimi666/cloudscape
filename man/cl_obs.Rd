%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_obs}
\alias{cl_obs}
\title{Build an observation table}
\usage{
cl_obs(cell, date, cloud_fraction, sensor = NA_character_, platform =
  NA_character_, tier = "metadata", shadow_fraction = NA_real_,
  snow_fraction = NA_real_)
}
\arguments{
  \item{cell}{Integer grid cell ids.}
  \item{date}{Acquisition dates.}
  \item{cloud_fraction}{Cloud fraction in \\[0, 1\\] for the cell.}
  \item{sensor}{Sensor ids.}
  \item{platform}{Optional platform names.}
  \item{tier}{Which evidence tier the cloud fractions came from:
  \code{"metadata"} (scene-level catalogue property), \code{"qa"} (aggregated quality
  layer) or \code{"mask"} (computed mask).}
  \item{shadow_fraction}{Optional additional fractions.}
  \item{snow_fraction}{Optional additional fractions.}
}
\description{
Build an observation table
}
\value{
An object of class \code{cl_obs}, inheriting from \code{data.frame}.
}
