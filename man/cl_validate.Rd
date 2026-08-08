%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_validate}
\alias{cl_validate}
\title{Accuracy metrics for a binary or multi-class mask}
\usage{
cl_validate(pred, truth, positive = 1, levels = NULL)
}
\arguments{
  \item{pred}{Predicted mask.}
  \item{truth}{Reference mask.}
  \item{positive}{For binary input, the value treated as the positive class.}
  \item{levels}{Optional class levels for multi-class input.}
}
\description{
Accuracy metrics for a binary or multi-class mask
}
\value{
A data frame of per-class precision, recall, F1 and IoU plus overall
  and balanced accuracy, with an attribute \code{confusion}.
}
\examples{
set.seed(1)
truth <- matrix(rbinom(400, 1, 0.3), 20, 20)
pred  <- truth; pred[sample(400, 40)] <- 1 - pred[sample(400, 40)]
cl_validate(pred, truth)
}
