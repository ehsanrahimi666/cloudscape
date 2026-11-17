# Reads the producer quality layer of every archived scene over the study
# cells. Work is saved month by month, so an interrupted run resumes where it
# stopped. A month with unreadable scenes is read a second time; scenes that
# still cannot be read are listed in data/qa_unread.csv.
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
    read <- function() tryCatch(suppressMessages(cl_qa_obs(
      sub, area$grid, area$cells, include_cirrus = cfg$qa_include_cirrus,
      confidence = cfg$qa_confidence, overpass_minutes = cfg$overpass_minutes,
      workers = cfg$qa_workers)), error = function(e) e)
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

expected <- unlist(lapply(names(items), function(s)
  sprintf("%s_%s.rds", s, sort(unique(format(items[[s]]$datetime, "%Y-%m"))))))
done <- file.exists(file.path(chunk_dir, expected))
message(sum(done), " of ", length(done), " sensor-months complete")
if (all(done)) {
  chunks <- lapply(file.path(chunk_dir, expected), readRDS)
  qa <- bind_obs(chunks)
  saveRDS(qa, file.path(data_dir, "obs_qa.rds"))
  unread <- do.call(rbind, lapply(seq_along(expected), function(k) {
    id <- attr(chunks[[k]], "failed")
    if (length(id)) data.frame(chunk = sub("\\.rds$", "", expected[k]), id = id)
  }))
  if (is.null(unread)) unread <- data.frame(chunk = character(), id = character())
  utils::write.csv(unread, file.path(data_dir, "qa_unread.csv"), row.names = FALSE)
  message("quality-layer observations: ", nrow(qa), "; scenes unread: ", nrow(unread))
}
