# Reads the producer quality layers of the phenology year on a 6.25 km grid
# that nests in the 25 km analysis grid, for the analysis of how usability
# depends on cell size. Work is saved by sensor and month, so an interrupted
# run resumes where it stopped.
source("analysis/config.R")
suppressPackageStartupMessages(library(cloudscape))
area <- study_area(cfg)
items <- readRDS(file.path(data_dir, "items.rds"))
res <- min(cfg$fine_res)
grid <- cl_grid(res = res)
b <- area$bounds
cols <- seq(round((b[1] - grid$xmin) / res) + 1, round((b[3] - grid$xmin) / res))
rows <- seq(round((grid$ymax - b[4]) / res) + 1, round((grid$ymax - b[2]) / res))
cells <- as.vector(outer((rows - 1L) * grid$ncol, cols, "+"))
stopifnot(length(cells) == length(area$cells) * (cfg$grid_res / res)^2)
chunk_dir <- file.path(data_dir, "qa_fine_chunks")
dir.create(chunk_dir, showWarnings = FALSE)

yr <- as.character(cfg$pheno_year)
for (s in names(items)) {
  it <- items[[s]]
  k <- which(format(it$datetime, "%Y") == yr)
  month <- format(it$datetime[k], "%Y-%m")
  for (m in sort(unique(month))) {
    f <- file.path(chunk_dir, sprintf("%s_%s.rds", s, m))
    if (file.exists(f)) next
    sub <- subset_items(it, k[month == m])
    read <- function() tryCatch(suppressMessages(cl_qa_obs(
      sub, grid, cells, include_cirrus = cfg$qa_include_cirrus,
      confidence = cfg$qa_confidence, overpass_minutes = cfg$overpass_minutes,
      workers = 2L)), error = function(e) e)
    o <- read()
    if (!inherits(o, "error") && length(attr(o, "failed"))) o <- read()
    if (inherits(o, "error")) {
      message(s, " ", m, ": ", conditionMessage(o))
      next
    }
    saveRDS(o, f)
    message(s, " ", m, ": ", nrow(o), " cell-observations, ", length(attr(o, "failed")), " scenes unread")
  }
}

expected <- unlist(lapply(names(items), function(s) {
  d <- items[[s]]$datetime
  sprintf("%s_%s.rds", s, sort(unique(format(d[format(d, "%Y") == yr], "%Y-%m"))))
}))
done <- file.exists(file.path(chunk_dir, expected))
message(sum(done), " of ", length(done), " sensor-months complete")
if (all(done)) {
  chunks <- lapply(file.path(chunk_dir, expected), readRDS)
  qa <- bind_obs(chunks)
  attr(qa, "res") <- res
  saveRDS(qa, file.path(data_dir, "obs_qa_fine.rds"))
  unread <- unlist(lapply(chunks, attr, "failed"))
  utils::write.csv(data.frame(id = unread), file.path(data_dir, "qa_fine_unread.csv"), row.names = FALSE)
  message("fine-grid quality-layer observations: ", nrow(qa), "; scenes unread: ", length(unread))
}
