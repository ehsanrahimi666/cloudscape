%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_clear_prob}
\alias{cl_clear_prob}
\title{Probability that a pixel in a cell is clear}
\usage{
cl_clear_prob(obs, model = c("independent", "clustered", "empirical"), kappa
  = 0.5, coverage = TRUE, threshold = 0.2)
}
\arguments{
  \item{obs}{A \code{cl_obs} table.}
  \item{model}{One of \code{"independent"}, \code{"clustered"}, \code{"empirical"}.}
  \item{kappa}{Beta concentration for \code{"clustered"}.}
  \item{coverage}{Take the valid share of the cell (column \code{valid_fraction},
  present in tier \code{"qa"}) into account, so that the probability refers to a
  pixel at a random location in the cell rather than to a pixel within the
  observed part. Has no effect on tables without that column.}
  \item{threshold}{Usability threshold for \code{"clustered"}, see
  \code{\link{cl_clear_obs}}.}
}
\description{
Converts the cloud fraction of each observation into a clear probability.

\code{"independent"} sets the probability that a pixel at a random location in
the cell is clear to \code{1 - cloud_fraction}. With tier \code{"metadata"} the
fraction is that of the whole scene, so the value assumes that the cell is
as cloudy as the scene; scene metadata carry no information on where in the
footprint the cloud was.

\code{"empirical"} requires tier \code{"qa"} or \code{"mask"} data, where the fraction was
measured for the cell rather than inferred from the scene, and also returns
\code{1 - cloud_fraction}.

\code{"clustered"} answers a different question: the probability that the cell
observation is usable at \code{threshold}, that is, that at least
\code{1 - threshold} of the cell is observed and clear, when the clear share of
the cell follows a Beta distribution with mean \code{1 - cloud_fraction} and
concentration \code{kappa}. Small \code{kappa} makes cells mostly clear or mostly
cloudy. The model is intended for scene-level fractions, where the share of
a particular cell is unknown.
}
\value{
Numeric vector of probabilities, one per row of \code{obs}.
}
