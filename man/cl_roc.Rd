%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_roc}
\alias{cl_roc}
\title{ROC curve and area under it}
\usage{
cl_roc(prob, truth, n_thresh = 101)
}
\arguments{
  \item{prob}{Predicted probabilities in \[0, 1\].}
  \item{truth}{Binary reference (1 = positive).}
  \item{n_thresh}{Number of thresholds to evaluate.}
}
\description{
ROC curve and area under it
}
\value{
A data frame of \code{threshold}, \code{fpr}, \code{tpr}, \code{precision}, with an \code{auc}
  attribute.
}
\examples{
set.seed(2)
truth <- rbinom(500, 1, 0.4)
prob  <- pmin(pmax(truth * 0.6 + runif(500) * 0.5, 0), 1)
attr(cl_roc(prob, truth), "auc")
}
