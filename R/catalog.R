# ---------------------------------------------------------------------------
# Module 1: catalogue access
#
# Built on the STAC standard rather than on a single provider's client, so that
# adding a sensor or a backend is a driver entry, not new code. The default
# backend is Element84's Earth Search, which requires no authentication and so
# keeps the package installable and demonstrable without credentials.
# ---------------------------------------------------------------------------

.CS_BACKENDS <- list(
  element84 = list(
    url = "https://earth-search.aws.element84.com/v1",
    sign = FALSE,
    note = "Open, no authentication. Landsat C2 L2 and Sentinel-2 L2A."
  ),
  planetary = list(
    url = "https://planetarycomputer.microsoft.com/api/stac/v1",
    sign = TRUE,
    note = "Broader catalogue; asset URLs require SAS signing and expire."
  ),
  cdse = list(
    url = "https://catalogue.dataspace.copernicus.eu/stac",
    sign = TRUE,
    note = "Copernicus Data Space Ecosystem; requires a free account."
  )
)

#' Configure or inspect a catalogue backend
#'
#' @param backend One of `"element84"`, `"planetary"`, `"cdse"`.
#' @return A list describing the backend.
#' @export
#' @examples
#' cl_catalog("element84")$url
cl_catalog <- function(backend = NULL) {
  backend <- backend %||% cl_options()$catalog
  cl_assert_choice(backend, "backend", names(.CS_BACKENDS))
  c(list(backend = backend), .CS_BACKENDS[[backend]])
}

#' Search a catalogue for scenes
#'
#' Queries a STAC API and returns a normalised item table. Provider-specific
#' property names are translated to a common vocabulary so that downstream code
#' never branches on the backend.
#'
#' @param aoi Area of interest: a numeric bounding box `c(xmin, ymin, xmax,
#'   ymax)` in degrees, or an `sf` object.
#' @param sensor Sensor id or alias.
#' @param start,end Date range.
#' @param max_cloud Maximum scene cloud cover in percent.
#' @param limit Maximum items to return; `Inf` fetches all pages.
#' @param backend Catalogue backend.
#' @param retries Number of attempts per HTTP request before giving up.
#'   Retries are applied to each page individually, with exponential backoff
#'   and respect for any `Retry-After` header. This matters more than it
#'   sounds: a large query spans many pages, and retrying the whole query
#'   after a failure on the last page discards every page already fetched and
#'   hits the service harder each time.
#' @param extra Additional STAC query fields.
#'
#' @return A data frame of class `cl_items` with columns `id`, `datetime`,
#'   `sensor`, `platform`, `cloud_cover`, `path_row` or `tile`, `geometry_bbox`
#'   and `assets`.
#' @export
cl_search <- function(aoi, sensor, start, end, max_cloud = 100,
                      limit = 500, backend = NULL, retries = 3L,
                      extra = list()) {
  cl_require(c("httr2", "jsonlite"), reason = "Catalogue search")
  cat_cfg <- cl_catalog(backend)
  drv <- cl_sensor(sensor)
  coll <- drv$collections[[cat_cfg$backend]]
  if (is.null(coll) || is.na(coll)) {
    cl_abort("Sensor '", drv$id, "' is not available on backend '",
             cat_cfg$backend, "'. Available: ",
             paste(names(Filter(Negate(is.na), drv$collections)), collapse = ", "), ".")
  }
  bbox <- .cs_bbox(aoi)
  q <- list(`eo:cloud_cover` = list(lte = max_cloud))
  # Several drivers can map to one catalogue collection: on Element84 both
  # Landsat 4-7 and Landsat 8-9 are served as "landsat-c2-l2". Without a
  # platform filter each driver returns the other's scenes, and the same
  # acquisition is counted twice under two sensor names.
  if (!is.null(drv$platforms) && nrow(drv$platforms)) {
    q[["platform"]] <- list(`in` = as.list(drv$platforms$platform))
  }
  body <- c(list(
    collections = list(coll),
    bbox = as.list(bbox),
    datetime = paste0(format(as.Date(start), "%Y-%m-%dT00:00:00Z"), "/",
                      format(as.Date(end), "%Y-%m-%dT23:59:59Z")),
    limit = min(cl_options()$max_page, if (is.finite(limit)) limit else 500L),
    query = q
  ), extra)

  items <- list(); fetched <- 0L; page <- 0L
  url <- paste0(cat_cfg$url, "/search")
  repeat {
    page <- page + 1L
    req <- httr2::req_timeout(
      httr2::req_body_json(httr2::request(url), body),
      cl_options()$timeout)
    # Retry each page in place. Gateway errors (502, 503, 504) are common on
    # public catalogues under load and are almost always transient.
    req <- httr2::req_retry(
      req,
      max_tries = max(1L, as.integer(retries)),
      is_transient = function(resp)
        httr2::resp_status(resp) %in% c(408L, 425L, 429L, 500L, 502L, 503L, 504L),
      backoff = function(i) min(20, 2^i + stats::runif(1)))
    resp <- tryCatch(httr2::req_perform(req), error = function(e) e)
    if (inherits(resp, "error")) {
      if (length(items)) {
        # Return what was already retrieved rather than discarding it. A
        # truncated record is visible and recoverable; a failed query that
        # throws away six good pages is neither.
        cl_warn("Catalogue request failed on page ", page, " (",
                substr(conditionMessage(resp), 1, 60), "). Returning the ",
                length(items), " items already retrieved; the result is ",
                "incomplete.")
        break
      }
      stop(resp)
    }
    js <- httr2::resp_body_json(resp)
    feats <- js$features %||% list()
    if (!length(feats)) break
    items <- c(items, feats)
    fetched <- fetched + length(feats)
    if (fetched >= limit) break
    nxt <- Filter(function(l) identical(l$rel, "next"), js$links %||% list())
    if (!length(nxt)) break
    body <- utils::modifyList(body, nxt[[1]]$body %||% list())
    url <- nxt[[1]]$href %||% url
  }
  .cs_items(items, drv, cat_cfg)
}

# paste0() turns missing components into the literal characters "NA", so a
# Landsat item, which carries no MGRS fields, silently acquired the tile id
# "NANANA". That is worse than a missing value because it compares equal
# across every such item and would group unrelated scenes together.
.cs_mgrs_tile <- function(zone, band, square) {
  if (any(is.na(c(zone, band, square)))) return(NA_character_)
  sprintf("%02d%s%s", as.integer(zone), as.character(band), as.character(square))
}

# GeoJSON geometry to a list of exterior rings, as lon/lat matrices.
#
# Polygon nests coordinates one level deep, MultiPolygon two. Catalogues return
# MultiPolygon for tiles crossing the antimeridian, and for scenes split by a
# provider's footprint simplification. Treating only Polygon meant those items
# produced no grid cells at all, silently removing exactly the high-latitude
# scenes whose availability this package exists to quantify.
.cs_geom_rings <- function(g) {
  if (is.null(g) || is.null(g$coordinates)) return(list())
  as_ring <- function(r) {
    m <- do.call(rbind, lapply(r, function(p) c(p[[1L]], p[[2L]])))
    storage.mode(m) <- "double"
    m
  }
  type <- g$type %||% "Polygon"
  if (identical(type, "MultiPolygon")) {
    return(lapply(g$coordinates, function(poly) as_ring(poly[[1L]])))
  }
  if (identical(type, "Polygon")) return(list(as_ring(g$coordinates[[1L]])))
  cl_warn("Unsupported geometry type '", type, "'; footprint skipped.")
  list()
}

.cs_bbox <- function(aoi) {
  if (inherits(aoi, c("sf", "sfc"))) {
    cl_require("sf", reason = "Converting sf to a bounding box")
    bb <- sf::st_bbox(sf::st_transform(sf::st_geometry(aoi), 4326))
    return(as.numeric(bb))
  }
  cl_assert(is.numeric(aoi) && length(aoi) == 4L,
            "`aoi` must be c(xmin, ymin, xmax, ymax) in degrees, or an sf object.")
  aoi
}

.cs_items <- function(features, drv, cat_cfg) {
  # Zero features is a legitimate answer, not a failure: a polar site in winter
  # or a short window over a small area genuinely has no acquisitions. The
  # empty table must still be correctly typed, because callers rbind it with
  # populated ones. Returning structure(NULL, ...) here was an error on R 4.6
  # (a deprecation warning on older R), so a valid empty window crashed the
  # query and, downstream, discarded a whole year of good data.
  if (!length(features)) {
    empty <- data.frame(
      id = character(), datetime = as.POSIXct(character(), tz = "UTC"),
      sensor = character(), platform = character(),
      cloud_cover = numeric(), cloud_cover_land = numeric(),
      sun_zenith = numeric(), sun_azimuth = numeric(), view_zenith = numeric(),
      path = numeric(), row = numeric(), tile = character(),
      stringsAsFactors = FALSE)
    return(structure(empty, class = c("cl_items", "data.frame"),
                     geometry = list(), assets = list(),
                     manifest = cl_manifest(NULL, backend = cat_cfg$backend,
                                            url = cat_cfg$url, sensor = drv$id,
                                            n_items = 0L,
                                            accessed = format(Sys.time(),
                                              "%Y-%m-%dT%H:%M:%S%z"))))
  }
  get <- function(f, ...) {
    for (k in c(...)) if (!is.null(f$properties[[k]])) return(f$properties[[k]])
    NA
  }
  df <- do.call(rbind, lapply(features, function(f) {
    data.frame(
      id = f$id %||% NA_character_,
      datetime = as.POSIXct(sub("Z$", "", get(f, "datetime", "start_datetime")),
                            format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
      sensor = drv$id,
      platform = as.character(get(f, "platform")),
      cloud_cover = as.numeric(get(f, "eo:cloud_cover")),
      cloud_cover_land = as.numeric(get(f, "landsat:cloud_cover_land")),
      sun_zenith = 90 - as.numeric(get(f, "view:sun_elevation")),
      sun_azimuth = as.numeric(get(f, "view:sun_azimuth")),
      view_zenith = as.numeric(get(f, "view:off_nadir")),
      path = as.numeric(get(f, "landsat:wrs_path")),
      row = as.numeric(get(f, "landsat:wrs_row")),
      tile = .cs_mgrs_tile(get(f, "mgrs:utm_zone"), get(f, "mgrs:latitude_band"),
                           get(f, "mgrs:grid_square")),
      stringsAsFactors = FALSE
    )
  }))
  geoms <- lapply(features, function(f) f$geometry)
  assets <- lapply(features, function(f) f$assets)
  structure(df, class = c("cl_items", "data.frame"),
            geometry = geoms, assets = assets,
            manifest = cl_manifest(NULL, backend = cat_cfg$backend,
                                   url = cat_cfg$url, sensor = drv$id,
                                   n_items = nrow(df),
                                   accessed = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")))
}

#' @export
print.cl_items <- function(x, n = 6L, ...) {
  cat("<cl_items>", nrow(x), "scenes from", attr(x, "manifest")$backend, "\n")
  if (nrow(x)) {
    cat("  period :", format(min(x$datetime)), "to", format(max(x$datetime)), "\n")
    cat("  cloud  : median", round(stats::median(x$cloud_cover, na.rm = TRUE), 1), "%\n")
  }
  print(utils::head(as.data.frame(x)[, c("id", "datetime", "platform", "cloud_cover")], n))
  invisible(x)
}

#' Convert catalogue items to an observation table
#'
#' Maps scene footprints onto the equal-area analysis grid and attaches the
#' scene-level cloud fraction to every intersecting cell. This is tier A: fast
#' and global, but the cloud fraction is a scene average, so the resulting
#' clear-observation counts should be read as an optimistic bound. See
#' [cl_clear_prob()].
#'
#' @param items A `cl_items` table.
#' @param grid A `cl_grid`.
#' @param method Footprint indexing method, see [cl_grid_index()].
#' @param overpass_minutes Scenes covering the same cell within this many
#'   minutes are treated as one observation. A sensor tiles a single overpass
#'   into several products - Sentinel-2 into MGRS tiles, Landsat into
#'   consecutive WRS-2 rows - and every tile covering a cell would otherwise be
#'   counted as a separate observation of it. In a 100 x 100 km test area this
#'   inflated Sentinel-2 counts by a factor of 4.6 to 7.9 and Landsat by 1.8,
#'   which in turn made cloud gaps look shorter and time-series retrieval look
#'   far easier than it is. Separate orbits on the same day are hours apart and
#'   remain distinct.
#' @return A `cl_obs` table with tier `"metadata"`, one row per cell per
#'   overpass. Items whose cloud-cover property is missing are excluded with a
#'   warning rather than silently treated as clear.
#' @export
cl_items_to_obs <- function(items, grid, method = "centroid",
                            overpass_minutes = 20) {
  cl_assert(inherits(items, "cl_items"), "`items` must come from cl_search().")
  geoms <- attr(items, "geometry")
  n_missing <- sum(is.na(items$cloud_cover))
  if (n_missing > 0L) {
    cl_warn(n_missing, " of ", nrow(items), " items have no cloud-cover ",
            "property and are excluded. Their acquisitions still happened, so ",
            "clear-observation counts derived from the remainder are ",
            "conditional on cloud cover being reported.")
  }
  rows <- lapply(seq_len(nrow(items)), function(i) {
    if (is.na(items$cloud_cover[i])) return(NULL)
    rings <- .cs_geom_rings(geoms[[i]])
    if (!length(rings)) return(NULL)
    cells <- unique(unlist(lapply(rings, function(m)
      cl_grid_index(m, grid, method = method)$cell)))
    if (!length(cells)) return(NULL)
    data.frame(cell = cells, datetime = items$datetime[i],
               date = as.Date(items$datetime[i]),
               cloud_fraction = items$cloud_cover[i] / 100,
               sensor = items$sensor[i], platform = items$platform[i],
               stringsAsFactors = FALSE)
  })
  d <- do.call(rbind, rows)
  if (is.null(d)) cl_abort("No item footprints intersected the grid.")

  n_tiles <- nrow(d)
  d <- .cs_collapse_overpasses(d, overpass_minutes)
  if (n_tiles > nrow(d)) {
    cl_msg("Collapsed ", format(n_tiles, big.mark = ","), " scene-tiles into ",
           format(nrow(d), big.mark = ","), " cell-observations (factor ",
           round(n_tiles / nrow(d), 2), "); tiles of one overpass are one ",
           "observation of a cell.")
  }
  out <- cl_obs(d$cell, d$date, d$cloud_fraction, d$sensor, d$platform,
                tier = "metadata")
  out$n_tiles <- d$n_tiles
  out
}


# Collapse scene-tiles into overpasses.
#
# A cell is covered by every tile of an overpass that overlaps it. Those are
# one observation of that cell, not several: they are the same instrument
# looking at the same ground at the same instant. Rows are grouped by cell and
# sensor, then split wherever the gap to the previous acquisition exceeds
# `minutes`. Cloud fraction is averaged across the contributing tiles, which is
# the best available estimate for the cell given only scene-level metadata.
.cs_collapse_overpasses <- function(d, minutes = 20) {
  if (!nrow(d)) return(d)
  o <- order(d$cell, d$sensor, d$datetime)
  d <- d[o, , drop = FALSE]
  n <- nrow(d)
  if (n == 1L) { d$n_tiles <- 1L; return(d) }
  gap <- as.numeric(difftime(d$datetime[-1], d$datetime[-n], units = "mins"))
  brk <- c(TRUE, d$cell[-1] != d$cell[-n] | d$sensor[-1] != d$sensor[-n] |
             gap > minutes)
  grp <- cumsum(brk)
  idx <- !duplicated(grp)
  out <- d[idx, , drop = FALSE]
  out$cloud_fraction <- as.numeric(tapply(d$cloud_fraction, grp, mean,
                                          na.rm = TRUE))
  out$n_tiles <- as.integer(tapply(grp, grp, length))
  rownames(out) <- NULL
  out
}
