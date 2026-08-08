%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_apply_chunks}
\alias{cl_apply_chunks}
\title{Apply a function over chunks, optionally in parallel}
\usage{
cl_apply_chunks(x, chunks, fun, workers = NULL)
}
\arguments{
  \item{x}{Object passed to \code{fun} along with each chunk.}
  \item{chunks}{A chunk plan from \code{\link{cl_chunk}}.}
  \item{fun}{Function with signature \code{(x, row_start, n_rows)}.}
  \item{workers}{Number of workers; 1 runs sequentially.}
}
\description{
Apply a function over chunks, optionally in parallel
}
\value{
A list of results, one per chunk.
}
