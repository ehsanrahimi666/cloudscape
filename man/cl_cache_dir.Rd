%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_cache_dir}
\alias{cl_cache_dir}
\title{Locate the cloudscape cache directory}
\usage{
cl_cache_dir(create = TRUE)
}
\arguments{
  \item{create}{Create the directory if it does not exist.}
}
\description{
Downloaded assets, resumable harvest state and companion datasets are stored
here. The location follows, in order of precedence: the \code{cache_dir} option,
the \code{CLOUDSCAPE_CACHE} environment variable, then a user-level cache path.
}
\value{
Absolute path to the cache directory.
}
