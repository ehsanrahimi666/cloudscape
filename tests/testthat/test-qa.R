# Synthetic quality layers written to local GeoTIFFs, so these tests read real
# rasters through the same code path as catalogue assets without any network.

qa_fixture <- function(sensor, key, left, right, datatype) {
  grid <- cl_grid(res = 25000)
  k <- cl_grid_lookup(grid, 128.7, 36.5)
  cc <- cl_grid_cells(grid, k)
  half <- grid$res / 2
  xy <- cbind(cc$x + c(-1, 1, 1, -1, -1) * half, cc$y + c(-1, -1, 1, 1, -1) * half)
  cell <- terra::project(terra::vect(xy, type = "polygons", crs = "EPSG:6933"),
                         "EPSG:32652")
  e <- terra::ext(cell)
  r <- terra::rast(terra::ext(e$xmin - 2000, e$xmax + 2000, e$ymin - 2000, e$ymax + 2000),
                   resolution = 100, crs = "EPSG:32652")
  mid <- (e$xmin + e$xmax) / 2
  terra::values(r) <- ifelse(terra::xFromCell(r, seq_len(terra::ncell(r))) < mid,
                             left, right)
  f <- tempfile(fileext = ".tif")
  terra::writeRaster(r, f, datatype = datatype, NAflag = 255, overwrite = TRUE)
  ll <- cl_unproject(cc$x + c(-1, 1, 1, -1, -1) * half * 1.5,
                     cc$y + c(-1, -1, 1, 1, -1) * half * 1.5)
  ring <- lapply(seq_len(nrow(ll)), function(i) list(ll[i, "lon"], ll[i, "lat"]))
  items <- structure(
    data.frame(id = "TEST", datetime = as.POSIXct("2024-06-01 02:00:00", tz = "UTC"),
               sensor = sensor, platform = "test", cloud_cover = 50,
               stringsAsFactors = FALSE),
    class = c("cl_items", "data.frame"),
    geometry = list(list(type = "Polygon", coordinates = list(ring))),
    assets = list(stats::setNames(list(list(href = f)), key)))
  list(items = items, grid = grid, cell = k)
}

test_that("quality-layer fractions are measured over the cell", {
  skip_if_not_installed("terra")
  fx <- qa_fixture("sentinel-2-msi", "scl", left = 9, right = 4, datatype = "INT1U")
  o <- cl_qa_obs(fx$items, fx$grid, fx$cell)
  expect_s3_class(o, "cl_obs")
  expect_equal(attr(o, "tier"), "qa")
  expect_equal(nrow(o), 1L)
  expect_lt(abs(o$cloud_fraction - 0.5), 0.03)
  expect_equal(o$shadow_fraction, 0)
  expect_gt(o$valid_fraction, 0.97)
})

test_that("fill pixels reduce the valid share, not the clear share", {
  skip_if_not_installed("terra")
  fx <- qa_fixture("landsat-8-9-oli", "qa_pixel", left = 8, right = 1,
                   datatype = "INT2U")
  o <- cl_qa_obs(fx$items, fx$grid, fx$cell)
  expect_equal(o$cloud_fraction, 1)
  expect_lt(abs(o$valid_fraction - 0.5), 0.03)
})

test_that("requester-pays Landsat assets map to a signed public mirror", {
  env <- get(".cs_pc_tokens", envir = asNamespace("cloudscape"))
  sig <- "sv=test"
  assign("landsateuwest/landsat-c2",
         list(token = sig, expiry = Sys.time() + 3600), envir = env)
  on.exit(rm(list = "landsateuwest/landsat-c2", envir = env))
  readable <- get(".cs_readable_href", envir = asNamespace("cloudscape"))
  expect_equal(readable("s3://usgs-landsat/collection02/level-2/a/QA.TIF"),
               "https://landsateuwest.blob.core.windows.net/landsat-c2/level-2/a/QA.TIF?sv=test")
  expect_equal(readable("s3://sentinel-cogs/a/SCL.tif"),
               "https://sentinel-cogs.s3.us-west-2.amazonaws.com/a/SCL.tif")
  expect_equal(readable("/data/scene/QA.tif"), "/data/scene/QA.tif")
})

test_that("an acquisition listed in several processing versions is kept once", {
  latest <- get(".cs_latest_versions", envir = asNamespace("cloudscape"))
  df <- data.frame(
    id = c("S2A_52SDF_20190324_0_L2A", "S2A_52SDF_20190324_1_L2A",
           "S2A_52SDF_20190331_0_L2A", "LC08_L2SP_114035_20190327_20200829_02_T1"),
    datetime = as.POSIXct(c("2019-03-24 02:33:29", "2019-03-24 02:27:21",
                            "2019-03-31 02:18:45", "2019-03-27 01:58:39"), tz = "UTC"),
    platform = c("sentinel-2a", "sentinel-2a", "sentinel-2a", "landsat-8"),
    tile = c("52SDF", "52SDF", "52SDF", NA), path = c(NA, NA, NA, 114),
    row = c(NA, NA, NA, 35), stringsAsFactors = FALSE)
  expect_equal(latest(df), c(FALSE, TRUE, TRUE, TRUE))
})

test_that("a Landsat scene missing from the mirror path is read from the mirror's own record", {
  skip_if_not_installed("terra")
  fx <- qa_fixture("landsat-8-9-oli", "qa_pixel", left = 8, right = 1,
                   datatype = "INT2U")
  local <- attr(fx$items, "assets")[[1]]$qa_pixel$href
  attr(fx$items, "assets")[[1]]$qa_pixel$href <-
    "s3://usgs-landsat/collection02/level-2/standard/oli-tirs/2024/TEST_QA_PIXEL.TIF"
  looked_up <- character()
  local_mocked_bindings(
    .cs_readable_href = function(href) file.path(tempdir(), "absent.tif"),
    .cs_pc_landsat_href = function(id, asset) {
      looked_up <<- c(looked_up, id)
      local
    })
  o <- cl_qa_obs(fx$items, fx$grid, fx$cell)
  expect_equal(looked_up, "TEST")
  expect_equal(o$cloud_fraction, 1)
  expect_length(attr(o, "failed"), 0)
})

test_that("Sentinel-2 SCL classes are decoded by validity and cloud state", {
  scl <- matrix(c(0L, 1L, 2L, 3L, 4L, 5L, 6L, 7L, 8L, 9L, 10L, 11L, 200L, NA), 1)
  d <- cl_qa_decode(scl, "sentinel-2-msi")
  expect_equal(d$fill, matrix(c(TRUE, TRUE, rep(FALSE, 10), TRUE, TRUE), 1))
  expect_equal(which(d$cloud), 9:11)
  expect_equal(which(d$shadow), 4L)
  expect_equal(which(d$snow), 12L)
  cls <- cl_classes()
  expect_equal(d$class[1, 3], cls[["terrain_shadow"]])
  expect_equal(d$class[1, 8], cls[["clear_land"]])
  d2 <- cl_qa_decode(scl, "sentinel-2-msi", include_cirrus = FALSE)
  expect_false(d2$cloud[1, 11])
  expect_false(d2$fill[1, 11])
})

test_that("bit-packed QA without a cirrus or fill bit decodes", {
  clear57 <- matrix(5440L, 1)
  expect_false(cl_qa_decode(clear57, "landsat-4-7-tm-etm")$cloud[1, 1])
  modis <- cl_qa_decode(matrix(0:3, 1), "modis-mod09ga", include_cirrus = FALSE)
  expect_equal(as.vector(modis$cloud), c(FALSE, TRUE, TRUE, FALSE))
  cirrus <- cl_qa_decode(matrix(bitwShiftL(0:3, 8L), 1), "modis-mod09ga")
  expect_equal(as.vector(cirrus$cloud), c(FALSE, FALSE, TRUE, TRUE))
  expect_true(cl_qa_decode(matrix(NA_integer_, 1), "modis-mod09ga")$fill[1, 1])
  expect_error(cl_qa_decode(matrix(21824L, 1), "landsat-8-9-oli", confidence = "low"))
  expect_false(cl_qa_decode(matrix(21824L, 1), "landsat-8-9-oli")$cloud[1, 1])
})

test_that("a Landsat 4-7 scene is read with the default arguments", {
  skip_if_not_installed("terra")
  fx <- qa_fixture("landsat-4-7-tm-etm", "qa_pixel", left = 5440, right = 5440,
                   datatype = "INT2U")
  o <- cl_qa_obs(fx$items, fx$grid, fx$cell)
  expect_equal(o$cloud_fraction, 0)
})

test_that("asset keys are matched without regard to case", {
  skip_if_not_installed("terra")
  fx <- qa_fixture("sentinel-2-msi", "SCL", left = 9, right = 4, datatype = "INT1U")
  o <- cl_qa_obs(fx$items, fx$grid, fx$cell)
  expect_lt(abs(o$cloud_fraction - 0.5), 0.03)
})

test_that("columns of the QA table stay aligned when sensors interleave in time", {
  skip_if_not_installed("terra")
  a <- qa_fixture("sentinel-2-msi", "scl", left = 9, right = 9, datatype = "INT1U")
  b <- qa_fixture("landsat-8-9-oli", "qa_pixel", left = 21824, right = 21824,
                  datatype = "INT2U")
  c2 <- qa_fixture("sentinel-2-msi", "scl", left = 4, right = 4, datatype = "INT1U")
  df <- rbind(as.data.frame(a$items), as.data.frame(b$items), as.data.frame(c2$items))
  df$id <- c("S2_cloudy", "L8_clear", "S2_clear")
  df$datetime <- as.POSIXct(c("2024-06-03 02:00:00", "2024-06-01 02:00:00",
                              "2024-06-08 02:00:00"), tz = "UTC")
  items <- structure(df, class = c("cl_items", "data.frame"),
                     geometry = c(attr(a$items, "geometry"), attr(b$items, "geometry"),
                                  attr(c2$items, "geometry")),
                     assets = c(attr(a$items, "assets"), attr(b$items, "assets"),
                                attr(c2$items, "assets")))
  o <- as.data.frame(cl_qa_obs(items, a$grid, a$cell))
  expect_equal(o$id[order(o$date)], c("L8_clear", "S2_cloudy", "S2_clear"))
  expect_equal(o$cloud_fraction[o$id == "S2_cloudy"], 1)
  expect_equal(o$cloud_fraction[o$id == "L8_clear"], 0)
  expect_equal(as.Date(o$datetime), o$date)
})
