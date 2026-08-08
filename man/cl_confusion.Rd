%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_confusion}
\alias{cl_confusion}
\title{Confusion matrix}
\usage{
cl_confusion(pred, truth, levels = NULL, labels = NULL)
}
\arguments{
  \item{pred}{Predicted class codes or logical mask.}
  \item{truth}{Reference class codes or logical mask.}
  \item{levels}{Optional class levels; defaults to the union observed.}
  \item{labels}{Optional class labels.}
}
\description{
Confusion matrix
}
\value{
A table with predictions in rows and reference in columns.
}
