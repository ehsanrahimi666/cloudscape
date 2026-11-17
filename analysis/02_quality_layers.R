# Reads the producer quality layer of every archived scene over the study
# cells. Work is saved month by month, so an interrupted run resumes where it
# stopped; network reads that fail are retried on the next run.
source("analysis/config.R")
suppressPackageStartupMessages(library(cloudscape))
area <- study_area(cfg)
items <- readRDS(file.path(data_dir, "items.rds"))
chunk_dir <- file.path(data_dir, "qa_chunks")
dir.create(chunk_dir, showWarnings = FALSE)

for (s in names(items)) {
  it <- items[[s]]
  month <- format(it$datetime, "%Y-%m")
  for (m in sort(unique(month))) {
    f <- file.path(chunk_dir, sprintf("%s_%s.rds", s, m))
    if (file.exists(f)) next
    sub <- subset_items(it, which(month == m))
    o <- tryCatch(suppressMessages(cl_qa_obs(
      sub, area$grid, area$cells, include_cirrus = cfg$qa_include_cirrus,
      confidence = cfg$qa_confidence, overpass_minutes = cfg$overpass_minutes,
      workers = cfg$qa_workers)), error = function(e) e)
    if (inherits(o, "error")) {
      message(s, " ", m, ": ", conditionMessage(o))
      next
    }
    if (length(attr(o, "failed"))) {
      message(s, " ", m, ": ", length(attr(o, "failed")), " scenes unread; month left for the next run")
      next
    }
    saveRDS(o, f)
    message(s, " ", m, ": ", nrow(o), " cell-observations")
  }
}

expected <- unlist(lapply(names(items), function(s)
  sprintf("%s_%s.rds", s, sort(unique(format(items[[s]]$datetime, "%Y-%m"))))))
done <- file.exists(file.path(chunk_dir, expected))
message(sum(done), " of ", length(done), " sensor-months complete")
if (all(done)) {
  qa <- bind_obs(lapply(file.path(chunk_dir, expected), readRDS))
  saveRDS(qa, file.path(data_dir, "obs_qa.rds"))
  message("quality-layer observations: ", nrow(qa))
}
