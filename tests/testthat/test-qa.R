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
