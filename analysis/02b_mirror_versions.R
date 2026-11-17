# Compares the Landsat scenes listed by Earth Search with those held by the
# Planetary Computer mirror from which the quality layers are read: the same
# processing version, another processing version, or absent from the mirror.
source("analysis/config.R")
suppressPackageStartupMessages(library(cloudscape))
area <- study_area(cfg)
es <- readRDS(file.path(data_dir, "items.rds"))[["landsat-8-9-oli"]]
pc <- suppressMessages(cl_search(area$aoi, "landsat-8-9-oli", cfg$start, cfg$end,
                                 backend = "planetary", limit = Inf, retries = 6L))
version_of <- function(items) {
  href <- vapply(attr(items, "assets"), function(a) {
    h <- a[["qa_pixel"]]$href
    if (is.null(h)) NA_character_ else h
  }, "")
  sub("^.*_L2SP_[0-9]{6}_[0-9]{8}_([0-9]{8})_.*$", "\\1", basename(sub("\\?.*$", "", href)))
}
v_es <- version_of(es)
v_pc <- version_of(pc)[match(es$id, pc$id)]
out <- data.frame(id = es$id, platform = es$platform, date = as.Date(es$datetime),
                  processed_earth_search = v_es, processed_mirror = v_pc,
                  status = ifelse(is.na(v_pc), "absent from mirror",
                                  ifelse(v_pc == v_es, "same version", "other version")))
save_csv(out, "landsat_mirror_versions")
print(table(out$platform, out$status))
