%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_compare}
\alias{cl_compare}
\title{Compare methods with uncertainty}
\usage{
cl_compare(preds, truth, n_boot = 500L, conf = 0.95, block = NULL)
}
\arguments{
  \item{preds}{Named list of predicted masks.}
  \item{truth}{Reference mask.}
  \item{n_boot}{Bootstrap replicates.}
  \item{conf}{Confidence level.}
  \item{block}{Optional vector of block ids, one per pixel, for a block
  bootstrap that resamples whole blocks with replacement. Cloud masks are
  spatially autocorrelated, so a pixel-wise bootstrap understates
  uncertainty; blocks such as tiles or scenes account for that dependence
  at their scale. Pixels missing in the reference, a prediction or \code{block}
  are left out.}
}
\description{
Paired comparison of two or more masks against a common reference. Reports
bootstrap confidence intervals on overall accuracy for each method, and
McNemar's test for each pair, so that a difference is only claimed when the
paired evidence supports it. McNemar's test treats pixels as independent,
so its p-values are optimistic for spatially autocorrelated masks; the
block bootstrap intervals are the more conservative evidence.
}
\value{
A list with \code{summary} (per-method accuracy and interval) and
  \code{pairwise} (McNemar statistics and p-values).
}
\examples{
set.seed(3)
truth <- matrix(rbinom(1000, 1, .35), 25, 40)
a <- truth; a[sample(1000, 60)] <- 1 - a[sample(1000, 60)]
b <- truth; b[sample(1000, 120)] <- 1 - b[sample(1000, 120)]
cl_compare(list(good = a, worse = b), truth, n_boot = 200)$summary
}
