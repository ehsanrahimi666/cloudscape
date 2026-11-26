# Usability of the overpass of the scene example at several cell sizes, from
# the archived scene classification (100 m in the grid projection). For each
# cell size the share of cells that are usable and the share of the observed
# clear area that falls in usable cells are reported.
source("analysis/config.R")
suppressPackageStartupMessages(library(terra))
area <- study_area(cfg)
scl <- terra::rast(file.path(data_dir, "scene_example_scl.tif"))
scl <- terra::crop(scl, terra::ext(area$bounds[c(1, 3, 2, 4)]))
v <- terra::values(scl, mat = FALSE)
valid <- !is.na(v) & v != 0
cloud <- valid & v %in% c(8, 9, 10)
nr <- terra::nrow(scl); nc <- terra::ncol(scl)
stopifnot(nr * terra::res(scl)[2] == cfg$grid_res * 4, nc * terra::res(scl)[1] == cfg$grid_res * 4)
sizes <- c(25000, 12500, 6250, 3125, 1000)
res <- do.call(rbind, lapply(sizes, function(s) {
  f <- s / terra::res(scl)[1]
  row <- (seq_len(nr) - 1L) %/% f; col <- (seq_len(nc) - 1L) %/% f
  k <- as.vector(t(outer(row * 1000L, col, "+")))   # cell of every pixel, row-major
  agg <- function(x) as.numeric(tapply(x, k, sum))
  nv <- agg(valid); nc_ <- agg(cloud); npx <- as.numeric(table(k))
  share_valid <- nv / npx
  cloud_frac <- ifelse(nv > 0, nc_ / nv, 1)
  clear_share <- share_valid * (1 - cloud_frac)
  usable <- clear_share >= 1 - cfg$threshold - 1e-12
  clear_px <- nv - nc_
  data.frame(cell_size_km = s / 1000, cells = length(npx), usable_cells = sum(usable),
             share_usable = mean(usable), share_clear_area_in_usable = sum(clear_px[usable]) / sum(clear_px),
             clear_area_share = sum(clear_px) / sum(npx))
}))
save_csv(res, "scale_example")
message("scale example complete")
