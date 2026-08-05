# ---------------------------------------------------------------------------
# Module 0b: equal-area analysis grid
#
# Why this module exists
# ----------------------
# Sensor footprints are not equal-area. WRS-2 scene polygons vary in ground
# area with latitude and their side-lap grows from roughly 7 percent at the
# equator to more than 50 percent near the poles; MGRS tiles have a different
# geometry again. Any statistic aggregated per scene or per tile is therefore
# area-biased with latitude, and Landsat and Sentinel-2 statistics computed on
# their native footprints are not directly comparable.
#
# cloudscape resolves both problems by making an equal-area grid the internal
# unit of analysis. Footprints are import geometries only. The default is
# EASE-Grid 2.0 global (EPSG:6933), a cylindrical equal-area projection on the
# WGS84 ellipsoid with standard parallel 30 degrees, in which every grid cell
# has exactly the same true ground area.
# ---------------------------------------------------------------------------

# WGS84 ellipsoid constants
.CS_A  <- 6378137.0
.CS_F  <- 1 / 298.257223563
.CS_E2 <- 2 * .CS_F - .CS_F^2
.CS_E  <- sqrt(.CS_E2)

# Authalic "q" function (Snyder 1987, eq. 3-12)
.cs_q <- function(phi) {
  s <- sin(phi)
  es <- .CS_E * s
  (1 - .CS_E2) * (s / (1 - es^2) - (1 / (2 * .CS_E)) * log((1 - es) / (1 + es)))
}

# k0 for a cylindrical equal-area projection with standard parallel lat_ts
.cs_k0 <- function(lat_ts = 30) {
  p <- deg2rad(lat_ts)
  cos(p) / sqrt(1 - .CS_E2 * sin(p)^2)
}

#' Project longitude/latitude to and from EASE-Grid 2.0 metres
#'
#' Closed-form cylindrical equal-area projection on the WGS84 ellipsoid. These
#' are provided directly rather than through PROJ so that the analysis grid,
#' and the tests that verify it, work without a geospatial toolchain.
#'
#' @param lon,lat Longitude and latitude in degrees.
#' @param x,y Projected coordinates in metres.
#' @param lat_ts Standard parallel in degrees. 30 gives EPSG:6933.
#' @return A two-column matrix with columns `x`/`y` or `lon`/`lat`.
#' @export
#' @examples
#' cl_project(c(0, 90), c(0, 45))
#' cl_unproject(cl_project(10, 50)[, 1], cl_project(10, 50)[, 2])
cl_project <- function(lon, lat, lat_ts = 30) {
  cl_assert_number(lon, "lon", -180, 180)
  cl_assert_number(lat, "lat", -90, 90)
  k0 <- .cs_k0(lat_ts)
  x <- .CS_A * k0 * deg2rad(lon)
  y <- .CS_A * .cs_q(deg2rad(lat)) / (2 * k0)
  cbind(x = x, y = y)
}

#' @export
#' @rdname cl_project
cl_unproject <- function(x, y, lat_ts = 30) {
  k0 <- .cs_k0(lat_ts)
  lon <- rad2deg(x / (.CS_A * k0))
  q <- 2 * y * k0 / .CS_A
  qp <- .cs_q(pi / 2)
  # Guard against rounding past the pole
  q <- pmin(pmax(q, -qp), qp)
  # Authalic latitude, then Newton iteration on q (Snyder 1987, eq. 3-16)
  beta <- asin(q / qp)
  phi <- beta
  for (i in seq_len(12)) {
    s <- sin(phi); c <- cos(phi)
    es <- .CS_E2 * s^2
    dphi <- ((1 - es)^2 / (2 * c)) *
      (q / (1 - .CS_E2) - s / (1 - es) +
         (1 / (2 * .CS_E)) * log((1 - .CS_E * s) / (1 + .CS_E * s)))
    phi <- phi + dphi
    if (all(abs(dphi) < 1e-12, na.rm = TRUE)) break
  }
  phi[abs(q - qp) < 1e-12] <- pi / 2
  phi[abs(q + qp) < 1e-12] <- -pi / 2
  cbind(lon = lon, lat = rad2deg(phi))
}

#' Define an equal-area analysis grid
#'
#' @param res Cell size in metres. Common choices are 100000 for global
#'   overviews, 25000 for continental analysis and 5000 for regional work.
#' @param crs EPSG code of the equal-area CRS. Only 6933 is supported by the
#'   built-in closed-form projection; other codes require `sf`.
#' @param extent Either `"global"` or a numeric vector
#'   `c(xmin, ymin, xmax, ymax)` in **degrees**.
#' @return An object of class `cl_grid`.
#' @export
#' @examples
#' g <- cl_grid(res = 100000)
#' g
#' nrow(cl_grid_cells(g)) > 0
cl_grid <- function(res = NULL, crs = NULL, extent = "global") {
  res <- res %||% cl_options()$grid_res
  crs <- crs %||% cl_options()$grid_crs
  cl_assert_number(res, "res", lower = 1)
  if (!identical(crs, 6933)) {
    cl_require("sf", reason = "Analysis grids in a CRS other than EPSG:6933")
  }
  if (identical(extent, "global")) {
    bb_deg <- c(-180, -90, 180, 90)
  } else {
    cl_assert(is.numeric(extent) && length(extent) == 4L,
              "`extent` must be \"global\" or c(xmin, ymin, xmax, ymax) in degrees.")
    bb_deg <- extent
  }
  ll <- cl_project(bb_deg[1], bb_deg[2])
  ur <- cl_project(bb_deg[3], bb_deg[4])
  # Snap outward to whole cells so cell boundaries are reproducible across
  # different extents: the global origin (0, 0) is always a cell corner.
  xmin <- floor(ll[1, "x"] / res) * res
  ymin <- floor(ll[1, "y"] / res) * res
  xmax <- ceiling(ur[1, "x"] / res) * res
  ymax <- ceiling(ur[1, "y"] / res) * res
  structure(
    list(res = res, crs = crs,
         xmin = xmin, ymin = ymin, xmax = xmax, ymax = ymax,
         ncol = as.integer(round((xmax - xmin) / res)),
         nrow = as.integer(round((ymax - ymin) / res)),
         extent_deg = bb_deg),
    class = "cl_grid"
  )
}

#' @export
print.cl_grid <- function(x, ...) {
  cat("<cl_grid> EPSG:", x$crs, "\n", sep = "")
  cat("  resolution : ", x$res, " m (cell area ", format(x$res^2 / 1e6, big.mark = ","),
      " km2)\n", sep = "")
  cat("  dimensions : ", x$nrow, " rows x ", x$ncol, " cols = ",
      format(as.numeric(x$nrow) * x$ncol, big.mark = ","), " cells\n", sep = "")
  cat("  extent     : ", paste(round(x$extent_deg, 3), collapse = ", "), " (degrees)\n", sep = "")
  invisible(x)
}

#' Cell identifiers, centroids and areas
#'
#' Cells are numbered row-major from the top-left, matching raster convention.
#' Because the grid is equal-area, every cell has an area of exactly `res^2`
#' square metres regardless of latitude; this is the property that removes the
#' latitude bias present in per-scene statistics.
#'
#' @param grid A `cl_grid`.
#' @param cells Optional integer vector of cell ids; defaults to all cells.
#'   Supplying ids avoids materialising a global table.
#' @return A data frame with `cell`, `row`, `col`, `x`, `y`, `lon`, `lat`,
#'   `area_km2`.
#' @export
cl_grid_cells <- function(grid, cells = NULL) {
  cl_assert(inherits(grid, "cl_grid"), "`grid` must be a cl_grid.")
  n <- as.numeric(grid$nrow) * grid$ncol
  if (is.null(cells)) {
    if (n > 5e6) {
      cl_abort("This grid has ", format(n, big.mark = ","), " cells. Pass `cells` ",
               "to materialise a subset, or use a coarser `res`.")
    }
    cells <- seq_len(n)
  }
  cl_assert(all(cells >= 1 & cells <= n), "`cells` out of range for this grid.")
  row <- ((cells - 1L) %/% grid$ncol) + 1L
  col <- ((cells - 1L) %% grid$ncol) + 1L
  x <- grid$xmin + (col - 0.5) * grid$res
  y <- grid$ymax - (row - 0.5) * grid$res
  ll <- cl_unproject(x, y)
  data.frame(cell = as.integer(cells), row = as.integer(row), col = as.integer(col),
             x = x, y = y, lon = ll[, "lon"], lat = ll[, "lat"],
             area_km2 = grid$res^2 / 1e6, stringsAsFactors = FALSE)
}

#' Locate cells from coordinates
#'
#' @param grid A `cl_grid`.
#' @param lon,lat Coordinates in degrees.
#' @return Integer vector of cell ids, `NA` outside the grid.
#' @export
cl_grid_lookup <- function(grid, lon, lat) {
  xy <- cl_project(lon, lat)
  col <- floor((xy[, "x"] - grid$xmin) / grid$res) + 1L
  row <- floor((grid$ymax - xy[, "y"]) / grid$res) + 1L
  out <- (row - 1L) * grid$ncol + col
  out[col < 1 | col > grid$ncol | row < 1 | row > grid$nrow] <- NA_integer_
  as.integer(out)
}

# Base-R ray-casting point-in-polygon test. Used by the sampling-based
# footprint indexer so that grid indexing does not require sf.
.cs_pip <- function(px, py, vx, vy) {
  n <- length(vx)
  inside <- logical(length(px))
  j <- n
  for (i in seq_len(n)) {
    yi <- vy[i]; yj <- vy[j]; xi <- vx[i]; xj <- vx[j]
    cross <- ((yi > py) != (yj > py)) &
      (px < (xj - xi) * (py - yi) / (yj - yi) + xi)
    inside <- xor(inside, cross)
    j <- i
  }
  inside
}

#' Index sensor footprints onto the analysis grid
#'
#' Converts a scene or tile footprint into a set of grid cells with weights.
#' Two methods are available. `"centroid"` assigns a cell to a footprint when
#' the cell centroid falls inside it; it is unbiased in expectation, needs no
#' geospatial dependencies, and is accurate when cells are much smaller than
#' footprints (the usual case: 25 km cells against 180 km Landsat scenes).
#' `"area"` computes exact fractional overlap and requires `sf`; use it when
#' cell size approaches footprint size.
#'
#' @param footprint Either a two-column matrix or data frame of polygon vertex
#'   longitudes and latitudes, or an `sf` object.
#' @param grid A `cl_grid`.
#' @param method `"centroid"` or `"area"`.
#' @return A data frame with columns `cell` and `weight`, where `weight` is the
#'   fraction of the cell covered by the footprint (always 1 for
#'   `method = "centroid"`).
#' @export
#' @examples
#' g <- cl_grid(res = 100000)
#' poly <- cbind(lon = c(0, 2, 2, 0, 0), lat = c(50, 50, 52, 52, 50))
#' head(cl_grid_index(poly, g))
cl_grid_index <- function(footprint, grid, method = c("centroid", "area")) {
  method <- match.arg(method)
  cl_assert(inherits(grid, "cl_grid"), "`grid` must be a cl_grid.")

  if (method == "area") {
    cl_require("sf", reason = "Exact area-weighted footprint indexing")
    return(.cs_grid_index_sf(footprint, grid))
  }

  v <- .cs_as_ring(footprint)
  xy <- cl_project(v[, 1], v[, 2])
  # Candidate window from the projected bounding box
  cmin <- max(1L, floor((min(xy[, "x"]) - grid$xmin) / grid$res) + 1L)
  cmax <- min(grid$ncol, floor((max(xy[, "x"]) - grid$xmin) / grid$res) + 1L)
  rmin <- max(1L, floor((grid$ymax - max(xy[, "y"])) / grid$res) + 1L)
  rmax <- min(grid$nrow, floor((grid$ymax - min(xy[, "y"])) / grid$res) + 1L)
  if (cmin > cmax || rmin > rmax) {
    return(data.frame(cell = integer(), weight = numeric(), stringsAsFactors = FALSE))
  }
  cols <- cmin:cmax; rows <- rmin:rmax
  gx <- grid$xmin + (cols - 0.5) * grid$res
  gy <- grid$ymax - (rows - 0.5) * grid$res
  px <- rep(gx, times = length(gy))
  py <- rep(gy, each = length(gx))
  keep <- .cs_pip(px, py, xy[, "x"], xy[, "y"])
  if (!any(keep)) {
    return(data.frame(cell = integer(), weight = numeric(), stringsAsFactors = FALSE))
  }
  cc <- rep(cols, times = length(rows))[keep]
  rr <- rep(rows, each = length(cols))[keep]
  data.frame(cell = as.integer((rr - 1L) * grid$ncol + cc),
             weight = 1, stringsAsFactors = FALSE)
}

.cs_as_ring <- function(footprint) {
  if (inherits(footprint, c("sf", "sfc"))) {
    cl_require("sf", reason = "Reading sf footprints")
    g <- sf::st_coordinates(sf::st_transform(sf::st_geometry(footprint), 4326))
    return(cbind(g[, 1], g[, 2]))
  }
  m <- as.matrix(footprint)
  cl_assert(ncol(m) >= 2L, "`footprint` needs at least two columns (lon, lat).")
  m <- m[, 1:2, drop = FALSE]
  storage.mode(m) <- "double"
  if (!identical(m[1, ], m[nrow(m), ])) m <- rbind(m, m[1, , drop = FALSE])
  m
}

.cs_grid_index_sf <- function(footprint, grid) {
  fp <- if (inherits(footprint, c("sf", "sfc"))) sf::st_geometry(footprint) else {
    v <- .cs_as_ring(footprint)
    sf::st_sfc(sf::st_polygon(list(v)), crs = 4326)
  }
  fp <- sf::st_transform(fp, grid$crs)
  bb <- sf::st_bbox(fp)
  cmin <- max(1L, floor((bb["xmin"] - grid$xmin) / grid$res) + 1L)
  cmax <- min(grid$ncol, ceiling((bb["xmax"] - grid$xmin) / grid$res))
  rmin <- max(1L, floor((grid$ymax - bb["ymax"]) / grid$res) + 1L)
  rmax <- min(grid$nrow, ceiling((grid$ymax - bb["ymin"]) / grid$res))
  if (cmin > cmax || rmin > rmax) {
    return(data.frame(cell = integer(), weight = numeric(), stringsAsFactors = FALSE))
  }
  cells <- as.vector(outer((rmin:rmax - 1L) * grid$ncol, cmin:cmax, "+"))
  polys <- lapply(cells, function(k) {
    r <- ((k - 1L) %/% grid$ncol) + 1L
    cc <- ((k - 1L) %% grid$ncol) + 1L
    x0 <- grid$xmin + (cc - 1L) * grid$res; x1 <- x0 + grid$res
    y1 <- grid$ymax - (r - 1L) * grid$res;  y0 <- y1 - grid$res
    sf::st_polygon(list(cbind(c(x0, x1, x1, x0, x0), c(y0, y0, y1, y1, y0))))
  })
  sfc <- sf::st_sfc(polys, crs = grid$crs)
  inter <- suppressWarnings(sf::st_intersection(sfc, sf::st_union(fp)))
  idx <- attr(inter, "idx")
  hit <- if (is.null(idx)) seq_along(inter) else idx[, 1]
  w <- as.numeric(sf::st_area(inter)) / grid$res^2
  keep <- w > 1e-9
  data.frame(cell = as.integer(cells[hit][keep]),
             weight = pmin(1, w[keep]), stringsAsFactors = FALSE)
}
