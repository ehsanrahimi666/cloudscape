# Queries the catalogue once and archives every scene record with its
# footprint and quality-layer asset, so that all later steps run offline.
source("analysis/config.R")
suppressPackageStartupMessages(library(cloudscape))
area <- study_area(cfg)

# One request per sensor and year, each retried after a pause, because the
# public catalogue intermittently answers with gateway errors.
query <- function(s, y) {
  for (attempt in 1:6) {
    # A partial result is returned with a warning; here it is a failure.
    it <- tryCatch(withCallingHandlers(
      cl_search(area$aoi, s, sprintf("%d-01-01", y), sprintf("%d-12-31", y),
                limit = Inf, retries = 6L),
      warning = function(w) if (grepl("incomplete", conditionMessage(w))) stop(w)),
      error = function(e) e)
    if (!inherits(it, "error")) return(it)
    message(s, " ", y, ": ", conditionMessage(it), "; retrying")
    Sys.sleep(30 * attempt)
  }
  stop("The catalogue did not answer for ", s, " ", y, ".")
}

pieces <- lapply(cfg$sensors, function(s) lapply(cfg$years, function(y) query(s, y)))
names(pieces) <- cfg$sensors
man <- do.call(rbind, lapply(cfg$sensors, function(s) do.call(rbind, lapply(seq_along(cfg$years), function(k) {
  m <- attr(pieces[[s]][[k]], "manifest")
  data.frame(sensor = s, year = cfg$years[k], backend = m$backend, url = m$url,
             accessed = m$accessed, n_items = nrow(pieces[[s]][[k]]),
             n_superseded = m$n_superseded, stringsAsFactors = FALSE)
}))))
utils::write.csv(man, file.path(data_dir, "query_manifest.csv"), row.names = FALSE)

items <- lapply(cfg$sensors, function(s) {
  it <- bind_items(pieces[[s]])
  key <- cl_sensor(s)$qa$asset
  attr(it, "assets") <- lapply(attr(it, "assets"), function(a) a[key])
  it
})
names(items) <- cfg$sensors
saveRDS(items, file.path(data_dir, "items.rds"))
tab <- do.call(rbind, lapply(items, function(it) as.data.frame(it)[, c(
  "id", "datetime", "sensor", "platform", "cloud_cover", "path", "row", "tile")]))
utils::write.csv(tab, file.path(data_dir, "items.csv"), row.names = FALSE)
print(man[, c("sensor", "year", "n_items", "n_superseded")])
