%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_benchmark}
\alias{cl_benchmark}
\title{Load a benchmark dataset}
\usage{
cl_benchmark(dataset = c("synthetic", "cloudsen12", "kappaset", "biome"), n
  = 20L, cache = cl_cache_dir())
}
\arguments{
  \item{dataset}{One of \code{"cloudsen12"}, \code{"kappaset"}, \code{"biome"}, \code{"synthetic"}.}
  \item{n}{Number of patches to return.}
  \item{cache}{Cache directory.}
}
\description{
\code{"synthetic"} scenes are simulated on the fly. The other datasets are read
from the cache directory; this version of cloudscape does not distribute
them, and when they are absent the function stops with a message giving the
expected location.
}
\value{
For \code{"synthetic"}, a list of simulated scenes generated on the fly.
  For the others, the cached dataset if present, otherwise an informative
  error.
}
