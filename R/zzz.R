.onLoad <- function(libname, pkgname) {
  .cs_register_builtin()
  .cs_register_methods()
  invisible(NULL)
}

.onAttach <- function(libname, pkgname) {
  packageStartupMessage(
    "cloudscape ", utils::packageVersion("cloudscape"),
    " | ", nrow(cl_sensors()), " sensors, ", nrow(cl_methods()), " methods",
    "\nStart with vignette(\"cloudscape\") or ?cl_availability")
}
