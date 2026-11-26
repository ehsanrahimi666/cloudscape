test_that("projection round-trips and is equal-area", {
  lon <- c(-179, -90, 0, 45, 179); lat <- c(-89, -45, 0, 30, 82)
  p <- cl_project(lon, lat); b <- cl_unproject(p[, "x"], p[, "y"])
  expect_lt(max(abs(b[, "lon"] - lon)), 1e-9)
  expect_lt(max(abs(b[, "lat"] - lat)), 1e-9)
  xr <- diff(range(cl_project(c(-180, 180), c(0, 0))[, "x"]))
  yr <- diff(range(cl_project(c(0, 0), c(-90, 90))[, "y"]))
  expect_lt(abs(xr * yr - 5.100656217e14) / 5.100656217e14, 1e-9)
})

test_that("equal-area grid removes the latitude bias of fixed-degree extents", {
  g <- cl_grid(res = 100000)
  lowlat  <- cl_grid_index(cbind(c(0, 2, 2, 0, 0), c(50, 50, 52, 52, 50)), g)
  highlat <- cl_grid_index(cbind(c(0, 2, 2, 0, 0), c(70, 70, 72, 72, 70)), g)
  expect_lt(nrow(highlat), nrow(lowlat))
  expect_true(all(cl_grid_cells(g, lowlat$cell)$area_km2 == 1e4))
})

test_that("cell lookup round-trips within half a cell", {
  g <- cl_grid(res = 25000)
  cc <- cl_grid_cells(g, cl_grid_lookup(g, 128.6, 35.87))
  expect_lt(abs(cc$lat - 35.87), 0.3)
})

test_that("grids are limited to EPSG:6933 and to integer cell identifiers", {
  expect_error(cl_grid(res = 100000, crs = 3035), "6933")
  expect_error(cl_grid(res = 250), "integer")
  expect_s3_class(cl_grid(res = 250, extent = c(126, 35, 130, 38)), "cl_grid")
})

test_that("edge cells of a global grid report only the area inside the domain", {
  g <- cl_grid(res = 25000)
  edge <- cl_grid_cells(g, 1L)
  mid <- cl_grid_cells(g, cl_grid_lookup(g, 10, 45))
  expect_equal(mid$area_km2, 625)
  expect_lt(edge$area_km2, 625)
  expect_gte(edge$area_km2, 0)
})
