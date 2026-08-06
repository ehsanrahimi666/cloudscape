drv <- function() cl_sensor("sentinel-2-msi")
cfg <- function() cl_catalog("element84")
parse_items <- function(feats, sensor = "sentinel-2-msi") {
  cloudscape:::.cs_items(feats, cl_sensor(sensor), cfg())
}

test_that("fractional-second datetimes parse", {
  it <- parse_items(list(cs_fixture_s2_item()))
  expect_false(is.na(it$datetime))
  expect_equal(format(it$datetime, "%Y-%m-%d %H:%M:%S"), "2024-06-15 02:31:29")
})

test_that("missing MGRS fields give NA, not the string 'NANANA'", {
  # paste0() renders missing components as literal "NA", which compares equal
  # across unrelated scenes and would silently group them together.
  l <- parse_items(list(cs_fixture_landsat_item()), "landsat-8-9-oli")
  expect_true(is.na(l$tile))
  expect_equal(l$path, 115)
  expect_equal(l$row, 35)
  s <- parse_items(list(cs_fixture_s2_item()))
  expect_equal(s$tile, "52SDG")
  expect_true(is.na(s$path))
})

test_that("sun elevation is converted to zenith", {
  it <- parse_items(list(cs_fixture_s2_item()))
  expect_equal(it$sun_zenith, 90 - 68.31, tolerance = 1e-9)
})

test_that("platform is read per item, not per collection", {
  it <- parse_items(cs_fixture_collection())
  expect_equal(it$platform[2], "sentinel-2b")
  expect_equal(it$platform[1], "sentinel-2a")
})

test_that("MultiPolygon footprints are indexed, not dropped", {
  # Antimeridian tiles are returned as MultiPolygon. Handling only Polygon
  # removed exactly the high-latitude scenes this package exists to quantify.
  g <- cl_grid(res = 25000)
  it <- parse_items(list(cs_fixture_multipolygon_item()))
  o <- cl_items_to_obs(it, g)
  expect_s3_class(o, "cl_obs")
  expect_gt(nrow(o), 0)
  cc <- cl_grid_cells(g, unique(o$cell))
  expect_true(any(cc$lon > 178) && any(cc$lon < -178))
})

test_that("items without cloud cover are excluded with a warning", {
  g <- cl_grid(res = 25000)
  it <- parse_items(cs_fixture_collection())
  expect_warning(o <- cl_items_to_obs(it, g), "no cloud-cover")
  expect_false(any(is.na(o$cloud_fraction)))
  # The sparse item contributed no rows
  expect_equal(length(unique(o$date)), 3)
})

test_that("cloud cover is converted from percent to fraction exactly once", {
  g <- cl_grid(res = 25000)
  it <- parse_items(list(cs_fixture_s2_item(cloud = 37.42)))
  o <- cl_items_to_obs(it, g)
  expect_equal(unique(o$cloud_fraction), 0.3742, tolerance = 1e-9)
  expect_equal(attr(o, "tier"), "metadata")
})

test_that("backends and collections resolve per sensor", {
  expect_equal(cl_catalog("element84")$sign, FALSE)
  expect_error(cl_catalog("nonexistent"), "must be one of")
  expect_equal(cl_sensor("sentinel-2-msi")$collections$element84, "sentinel-2-l2a")
  expect_true(is.na(cl_sensor("landsat-8-9-oli")$collections$cdse))
})

test_that("a query returning zero scenes yields a valid empty table", {
  # structure(NULL, ...) is an ERROR on R >= 4.5 and only a deprecation
  # warning on older R, so this crashed on a user's R 4.6 while passing on the
  # development machine. A polar site in winter legitimately has no
  # acquisitions; that is data, not a failure.
  e <- parse_items(list(), "landsat-8-9-oli")
  expect_s3_class(e, "cl_items")
  expect_equal(nrow(e), 0L)
  expect_true(inherits(e$datetime, "POSIXct"))
  expect_equal(length(attr(e, "geometry")), 0L)
  expect_equal(attr(e, "manifest")$n_items, 0L)
})

test_that("empty and populated results combine without losing types", {
  e <- parse_items(list())
  f <- parse_items(list(cs_fixture_s2_item()))
  m <- rbind(as.data.frame(e), as.data.frame(f))
  expect_equal(nrow(m), 1L)
  expect_true(inherits(m$datetime, "POSIXct"))
  expect_false(is.na(m$cloud_cover[1]))
})
