%% Generated from roxygen comments by tools/rd-from-roxygen.py
%% Do not edit by hand
\name{sensor-registry}
\alias{cl_sensor_register}
\alias{cl_sensor}
\alias{cl_sensors}
\title{Register, retrieve and list sensor drivers}
\usage{
cl_sensor_register(driver, overwrite = FALSE)
cl_sensor(id)
cl_sensors()
}
\arguments{
  \item{driver}{A \code{cl_sensor} object.}
  \item{id}{Sensor identifier.}
  \item{overwrite}{Replace an existing registration.}
}
\description{
Register, retrieve and list sensor drivers
}
\value{
\code{cl_sensor_register()} returns the id invisibly; \code{cl_sensor()}
  returns a \code{cl_sensor}; \code{cl_sensors()} returns a data frame summary.
}
