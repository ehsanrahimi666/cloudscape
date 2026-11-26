# Share of saturated or defective pixels (Sentinel-2 SCL class 1) and the
# processing baseline reported in the metadata of every archived Sentinel-2
# scene, retrieved from the same catalogue by scene identifier.
source("analysis/config.R")
suppressPackageStartupMessages(library(cloudscape))
items <- readRDS(file.path(data_dir, "items.rds"))[["sentinel-2-msi"]]
url <- paste0(cl_catalog("element84")$url, "/search")
ids <- items$id
props <- c("s2:saturated_defective_pixel_percentage", "s2:nodata_pixel_percentage",
           "s2:dark_features_percentage", "s2:unclassified_percentage")
props_chr <- "s2:processing_baseline"
fetch <- function(chunk) {
  body <- list(collections = list("sentinel-2-l2a"), ids = as.list(chunk),
               limit = length(chunk))
  for (attempt in 1:6) {
    r <- tryCatch(httr2::req_perform(httr2::req_body_json(httr2::request(url), body)),
                  error = function(e) e)
    if (!inherits(r, "error")) break
    Sys.sleep(10 * attempt)
  }
  if (inherits(r, "error")) stop("The catalogue did not answer: ", conditionMessage(r))
  f <- httr2::resp_body_json(r)$features
  do.call(rbind, lapply(f, function(x) data.frame(
    id = x$id, t(vapply(props, function(p) as.numeric(x$properties[[p]] %||% NA_real_), numeric(1))),
    baseline = as.character(x$properties[[props_chr]] %||% NA_character_),
    check.names = FALSE)))
}
`%||%` <- function(a, b) if (is.null(a)) b else a
chunks <- split(ids, ceiling(seq_along(ids) / 100))
tab <- do.call(rbind, lapply(chunks, fetch))
names(tab) <- c("id", "saturated_defective", "nodata", "dark_features", "unclassified", "baseline")
utils::write.csv(tab, file.path(data_dir, "scl_scene_percentages.csv"), row.names = FALSE)
out <- data.frame(accessed = format(Sys.Date()), n_scenes = length(ids), n_found = nrow(tab),
                  n_saturated_positive = sum(tab$saturated_defective > 0, na.rm = TRUE),
                  max_saturated_percent = max(tab$saturated_defective, na.rm = TRUE),
                  mean_saturated_percent = mean(tab$saturated_defective, na.rm = TRUE),
                  n_missing = sum(is.na(tab$saturated_defective)))
save_csv(out, "scl_saturation")
save_csv(as.data.frame(table(baseline = tab$baseline), responseName = "n_scenes"), "s2_baselines")
print(out)
