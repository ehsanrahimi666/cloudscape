%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_obs}
\alias{cl_obs}
\title{Build an observation table}
\usage{
cl_obs(cell, date, cloud_fraction, sensor = NA_character_, platform =
  NA_character_, tier = "metadata", shadow_fraction = NA_real_,
  snow_fraction = NA_real_, ..., percent = NULL)
}
\arguments{
  \item{cell}{Integer grid cell ids.}
  \item{date}{Acquisition dates.}
  \item{cloud_fraction}{Cloud fraction of the cell, as a fraction in \[0, 1\]
  or, with \code{percent = TRUE}, as a percentage in \[0, 100\].}
  \item{sensor}{Sensor ids.}
  \item{platform}{Optional platform names.}
  \item{tier}{Which evidence tier the cloud fractions came from:
  \code{"metadata"} (scene-level catalogue property), \code{"qa"} (aggregated quality
  layer) or \code{"mask"} (computed mask).}
  \item{shadow_fraction}{Optional additional fractions, on the
  same scale as \code{cloud_fraction}.}
  \item{snow_fraction}{Optional additional fractions, on the
  same scale as \code{cloud_fraction}.}
  \item{...}{Further named columns, each of length one or of the length of
  \code{cell}, kept aligned with the observations (for example \code{valid_fraction}
  or a scene identifier).}
  \item{percent}{Whether the fractions are given as percentages. With \code{NULL}
  they are taken as percentages, with a warning, only when a cloud fraction
  exceeds 1; a percentage series whose values never exceed 1 cannot be
  recognised and must be passed with \code{percent = TRUE}.}
}
\description{
Build an observation table
}
\value{
An object of class \code{cl_obs}, inheriting from \code{data.frame}, ordered
  by cell and date.
}
