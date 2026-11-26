# True-colour image and scene classification of one Sentinel-2 overpass, for
# the figure comparing scene cloud cover with cell cloud fractions. The
# overpass is chosen by rule: of the overpasses in the phenology year whose
# quality layers cover all sixteen cells (valid share at least 0.9 in each),
# the one with the widest range of cell cloud fraction. The images are
# resampled to 100 m in the grid projection and archived with the inputs.
source("analysis/config.R")
suppressPackageStartupMessages(library(cloudscape))
area <- study_area(cfg)
items <- readRDS(file.path(data_dir, "items.rds"))[["sentinel-2-msi"]]
qa <- readRDS(file.path(data_dir, "obs_qa.rds"))
qa <- as.data.frame(qa)[qa$cell %in% area$cells & qa$sensor == "sentinel-2-msi" &
                          format(qa$date, "%Y") == as.character(cfg$pheno_year), ]

by_date <- split(qa, qa$date)
cand <- do.call(rbind, lapply(by_date, function(d) data.frame(
  date = d$date[1], cells = length(unique(d$cell)), min_valid = min(d$valid_fraction),
  range = diff(range(d$cloud_fraction)))))
cand <- cand[cand$cells == length(area$cells) & cand$min_valid >= 0.9, ]
stopifnot(nrow(cand) > 0L)
pick <- cand[order(-cand$range, cand$date), ][1, ]

it <- as.data.frame(items)
sel <- which(as.Date(it$datetime) == pick$date)
scl <- vapply(attr(items, "assets")[sel], function(a) a$scl$href, "")
tci <- sub("SCL\\.tif$", "TCI.tif", scl)
stopifnot(all(tci != scl))

margin <- 5000
te <- as.character(area$bounds + c(-margin, -margin, margin, margin))
warp <- function(src, dst, resampling, nodata) {
  sf::gdal_utils("warp", source = paste0("/vsicurl/", src), destination = dst,
                 options = c("-t_srs", "EPSG:6933", "-te", te, "-tr", "100", "100",
                             "-r", resampling, "-srcnodata", nodata, "-dstnodata", nodata,
                             "-ovr", "AUTO", "-co", "COMPRESS=DEFLATE", "-overwrite"))
}
# The image subsets are archived with the analysis; they are read from the
# catalogue assets only when absent.
dst <- file.path(data_dir, c("scene_example_tci.tif", "scene_example_scl.tif"))
if (!all(file.exists(dst))) {
  old <- Sys.getenv(c("GDAL_DISABLE_READDIR_ON_OPEN", "CPL_VSIL_CURL_ALLOWED_EXTENSIONS"))
  Sys.setenv(GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR", CPL_VSIL_CURL_ALLOWED_EXTENSIONS = ".tif")
  warp(tci, dst[1], "average", "0")
  warp(scl, dst[2], "mode", "0")
  do.call(Sys.setenv, as.list(old))
}

save_csv(data.frame(date = pick$date, id = it$id[sel], tile = it$tile[sel],
                    scene_cloud_cover = it$cloud_cover[sel] / 100,
                    cell_cloud_min = min(by_date[[as.character(pick$date)]]$cloud_fraction),
                    cell_cloud_max = max(by_date[[as.character(pick$date)]]$cloud_fraction),
                    candidates = nrow(cand)), "scene_example")
message("scene example: ", pick$date, " (", length(sel), " tiles)")
