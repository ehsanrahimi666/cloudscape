%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{cl_clear_prob}
\alias{cl_clear_prob}
\title{Probability that a pixel in a cell is clear}
\usage{
cl_clear_prob(obs, model = c("independent", "clustered", "empirical"), kappa
  = 0.5)
}
\arguments{
  \item{obs}{A \code{cl_obs} table.}
  \item{model}{One of \code{"independent"}, \code{"clustered"}, \code{"empirical"}.}
  \item{kappa}{Beta concentration for \code{"clustered"}; lower means more
  clustered. Values near 0.5 match reported pixel-scale behaviour.}
}
\description{
Converting a scene-level cloud fraction into a per-pixel clear probability
requires an assumption, and the choice of assumption matters more than most
users expect.

\code{"independent"} sets \code{P(clear) = 1 - cloud_fraction}. This treats cloud as
spatially random within the footprint. Cloud is strongly clustered, so this
systematically \strong{overestimates} the number of usable observations for a
specific location: a scene reported as 50 percent cloudy is far more often
half covered by one cloud deck than uniformly half-obscured. It is the
assumption implicit in any analysis that uses scene cloud percentage as a
usability measure, and it is why tier A results should be read as an upper
bound.

\code{"clustered"} applies a Beta-distributed correction with concentration
\code{kappa}, reproducing the observed U-shaped distribution of pixel-level cloud
occurrence within partly cloudy scenes.

\code{"empirical"} requires tier \code{"qa"} or \code{"mask"} data, where the fraction was
measured for the cell rather than inferred from the scene, and applies no
correction.
}
\value{
Numeric vector of clear probabilities, one per row of \code{obs}.
}
