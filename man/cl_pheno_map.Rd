%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_pheno_map}
\alias{cl_pheno_map}
\title{Map phenological retrieval error across grid cells}
\usage{
cl_pheno_map(obs, year = NULL, n_sim = 50L, ...)
}
\arguments{
  \item{obs}{A \code{cl_obs} table.}
  \item{year}{Year to analyse; defaults to the most frequent year present.}
  \item{n_sim}{Replicates per cell.}
  \item{...}{Passed to \code{\link{cl_pheno_power}}.}
}
\description{
Applies \code{\link{cl_pheno_power}} cell by cell using the actual acquisition dates
and cloud fractions recorded for each cell, turning an observation table into
a map of expected phenological uncertainty.
}
\value{
A \code{cl_stats} table with metric \code{sos_error_days}, carrying a
  \code{details} attribute with the full per-cell summaries.
}
