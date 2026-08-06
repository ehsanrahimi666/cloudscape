%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_disagreement}
\alias{cl_disagreement}
\title{Pairwise disagreement between masks}
\usage{
cl_disagreement(masks, strata = NULL)
}
\arguments{
  \item{masks}{Named list of masks.}
  \item{strata}{Optional factor or matrix of stratum labels, for example a
  land-cover or snow layer, used to report where methods diverge.}
}
\description{
Pairwise disagreement between masks
}
\value{
A list with \code{pairwise} (a data frame of agreement, Jaccard and
  commission/omission relative to each other) and, when \code{strata} is given,
  \code{by_stratum}.
}
