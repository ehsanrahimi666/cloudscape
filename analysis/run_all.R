# Runs the analysis of the article from the archived inputs in analysis/data,
# each step in a fresh R session, from the repository root:
#   Rscript analysis/run_all.R          analysis, figures and numbers
#   Rscript analysis/run_all.R --fetch  first query the catalogue and read the
#                                       quality layers again (network access;
#                                       the remote archives may have changed)
fetch <- c("01_query.R", "01b_land_cover.R", "01c_scl_saturation.R", "02_quality_layers.R",
           "02b_mirror_versions.R", "02c_quality_layers_fine.R")
steps <- c("03_availability.R", "03b_persistence_simulation.R", "03c_scale.R", "04_phenology.R",
           "05_validation.R", "05b_scene_example.R", "05c_scale_example.R", "06_figures.R",
           "07_numbers.R")
if ("--fetch" %in% commandArgs(trailingOnly = TRUE)) steps <- c(fetch, steps)
rscript <- file.path(R.home("bin"), "Rscript")
for (s in steps) {
  t0 <- Sys.time()
  status <- system2(rscript, c("--vanilla", file.path("analysis", s)))
  message(sprintf("%-32s %6.1f min", s, as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  if (status != 0) stop(s, " failed with status ", status)
}
