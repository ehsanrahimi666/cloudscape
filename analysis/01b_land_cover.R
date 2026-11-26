# Land cover of the study area from ESA WorldCover 2021 (v200), resampled to
# 100 m in the grid projection with the modal class, and the share of each
# class over the sixteen cells.
source("analysis/config.R")
area <- study_area(cfg)
tiles <- c("N36E126", "N36E129")
src <- sprintf("/vsicurl/https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/ESA_WorldCover_10m_2021_v200_%s_Map.tif", tiles)
dst <- file.path(data_dir, "land_cover_100m.tif")
old <- Sys.getenv(c("GDAL_DISABLE_READDIR_ON_OPEN", "CPL_VSIL_CURL_ALLOWED_EXTENSIONS"))
Sys.setenv(GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR", CPL_VSIL_CURL_ALLOWED_EXTENSIONS = ".tif")
sf::gdal_utils("warp", source = src, destination = dst,
               options = c("-t_srs", "EPSG:6933", "-te", as.character(area$bounds),
                           "-tr", "100", "100", "-r", "mode", "-ovr", "AUTO",
                           "-co", "COMPRESS=DEFLATE", "-overwrite"))
do.call(Sys.setenv, as.list(old))
lc <- terra::values(terra::rast(dst), mat = FALSE)
classes <- c(`10` = "Tree cover", `20` = "Shrubland", `30` = "Grassland", `40` = "Cropland",
             `50` = "Built-up", `60` = "Bare or sparse vegetation", `70` = "Snow and ice",
             `80` = "Permanent water", `90` = "Herbaceous wetland", `95` = "Mangroves",
             `100` = "Moss and lichen")
tab <- table(factor(lc[!is.na(lc) & lc > 0], levels = as.integer(names(classes))))
out <- data.frame(code = as.integer(names(classes)), class = unname(classes),
                  share = as.numeric(tab) / sum(tab))
utils::write.csv(out, file.path(data_dir, "land_cover_shares.csv"), row.names = FALSE)
utils::write.csv(data.frame(source = sub("^/vsicurl/", "", src), accessed = format(Sys.Date())),
                 file.path(data_dir, "land_cover_manifest.csv"), row.names = FALSE)
message("land cover: ", paste(sprintf("%s %.1f%%", out$class, 100 * out$share)[out$share > 0.01], collapse = ", "))
