# ---------------------------------------------------------------------------
# Module 0a: sensor driver registry
#
# A driver is a plain list describing everything cloudscape needs to know about
# a sensor. Adding a sensor means writing one driver, not editing algorithms.
# ---------------------------------------------------------------------------

.cs_sensors <- new.env(parent = emptyenv())

#' Construct a sensor driver
#'
#' A sensor driver is the single point of sensor-specific knowledge in
#' cloudscape. Algorithms address bands by standardised names (`blue`, `nir`,
#' `swir16`, `cirrus`, `tir1`, ...) and the driver translates those into the
#' asset names a particular catalogue uses. Everything downstream is therefore
#' sensor-agnostic.
#'
#' @param id Short identifier, e.g. `"landsat-8-9-oli"`.
#' @param name Human-readable name.
#' @param bands Named character vector mapping standardised band names to the
#'   asset or layer names used by this sensor.
#' @param resolution Named numeric vector of native resolutions in metres,
#'   using the same standardised band names.
#' @param platforms `data.frame` with columns `platform`, `start`, `end`
#'   giving the operational period of each satellite in the constellation.
#'   `end` may be `NA` for currently active platforms. Used by [cl_synergy()]
#'   to compute time-varying revisit.
#' @param footprint Footprint geometry type: `"wrs2"`, `"mgrs"`, `"sinusoidal"`,
#'   `"scene"` or `"none"`.
#' @param revisit Nominal revisit interval in days for a single platform.
#' @param qa Optional QA specification created by [cl_qa_spec()].
#' @param scale,offset Linear rescaling from stored integers to reflectance.
#' @param collections Named list mapping catalogue backends to collection ids.
#' @param cloud_property Name of the scene-level cloud-cover property in
#'   catalogue metadata.
#' @param has_thermal,has_cirrus Logical capability flags. Algorithms that
#'   require these bands check the flags and degrade gracefully.
#' @param notes Free text recorded in manifests.
#'
#' @return An object of class `cl_sensor`.
#' @export
#' @examples
#' drv <- cl_sensor("landsat-8-9-oli")
#' drv$bands[["cirrus"]]
cl_sensor_driver <- function(id, name, bands, resolution = NULL,
                             platforms = NULL, footprint = "none",
                             revisit = NA_real_, qa = NULL,
                             scale = 1, offset = 0, collections = list(),
                             cloud_property = "eo:cloud_cover",
                             has_thermal = FALSE, has_cirrus = FALSE,
                             notes = NULL) {
  cl_assert(is.character(id) && length(id) == 1L, "`id` must be a single string.")
  cl_assert(is.character(bands) && !is.null(names(bands)),
            "`bands` must be a named character vector.")
  cl_assert_choice(footprint, "footprint",
                   c("wrs2", "mgrs", "sinusoidal", "scene", "none"))
  structure(
    list(
      id = id, name = name, bands = bands, resolution = resolution,
      platforms = platforms, footprint = footprint, revisit = revisit,
      qa = qa, scale = scale, offset = offset, collections = collections,
      cloud_property = cloud_property, has_thermal = has_thermal,
      has_cirrus = has_cirrus, notes = notes
    ),
    class = "cl_sensor"
  )
}

#' Describe a quality-assessment band
#'
#' QA layers come in two flavours: bit-packed (Landsat `QA_PIXEL`) and
#' categorical (Sentinel-2 `SCL`). `cl_qa_spec()` describes either so that
#' [cl_probability()] with `method = "qa"` can decode any sensor uniformly.
#'
#' @param type `"bitmask"` or `"categorical"`.
#' @param asset Asset name of the QA layer.
#' @param bits Named integer vector of bit positions (0-indexed) for
#'   `type = "bitmask"`. Names should include, where available, `cloud`,
#'   `cloud_shadow`, `snow`, `cirrus`, `water`, `fill`, `dilated_cloud`.
#' @param confidence Named list of two-bit confidence field positions, e.g.
#'   `list(cloud = c(8, 9))`, giving low/medium/high gradations.
#' @param classes Named integer vector mapping class labels to codes for
#'   `type = "categorical"`.
#' @param clear Character vector of class names considered clear.
#'
#' @return An object of class `cl_qa_spec`.
#' @export
cl_qa_spec <- function(type, asset, bits = NULL, confidence = NULL,
                       classes = NULL, clear = NULL) {
  cl_assert_choice(type, "type", c("bitmask", "categorical"))
  if (type == "bitmask" && is.null(bits)) cl_abort("`bits` is required for bitmask QA.")
  if (type == "categorical" && is.null(classes)) cl_abort("`classes` is required for categorical QA.")
  structure(
    list(type = type, asset = asset, bits = bits, confidence = confidence,
         classes = classes, clear = clear),
    class = "cl_qa_spec"
  )
}

#' Register, retrieve and list sensor drivers
#'
#' @param driver A `cl_sensor` object.
#' @param id Sensor identifier.
#' @param overwrite Replace an existing registration.
#' @return `cl_sensor_register()` returns the id invisibly; `cl_sensor()`
#'   returns a `cl_sensor`; `cl_sensors()` returns a data frame summary.
#' @export
#' @rdname sensor-registry
cl_sensor_register <- function(driver, overwrite = FALSE) {
  cl_assert(inherits(driver, "cl_sensor"), "`driver` must be a cl_sensor object.")
  if (!overwrite && exists(driver$id, envir = .cs_sensors, inherits = FALSE)) {
    cl_abort("Sensor '", driver$id, "' is already registered. Use overwrite = TRUE.")
  }
  assign(driver$id, driver, envir = .cs_sensors)
  invisible(driver$id)
}

#' @export
#' @rdname sensor-registry
cl_sensor <- function(id) {
  if (inherits(id, "cl_sensor")) return(id)
  id <- .cs_resolve_sensor(id)
  get(id, envir = .cs_sensors, inherits = FALSE)
}

#' @export
#' @rdname sensor-registry
cl_sensors <- function() {
  ids <- sort(ls(envir = .cs_sensors))
  if (!length(ids)) {
    return(data.frame(id = character(), name = character(),
                      footprint = character(), platforms = integer(),
                      thermal = logical(), cirrus = logical(),
                      stringsAsFactors = FALSE))
  }
  do.call(rbind, lapply(ids, function(i) {
    d <- get(i, envir = .cs_sensors, inherits = FALSE)
    data.frame(
      id = d$id, name = d$name, footprint = d$footprint,
      platforms = if (is.null(d$platforms)) 0L else nrow(d$platforms),
      thermal = d$has_thermal, cirrus = d$has_cirrus,
      stringsAsFactors = FALSE
    )
  }))
}

# Aliases so users can write "landsat8", "L8", "s2" etc.
.cs_aliases <- c(
  "landsat8" = "landsat-8-9-oli", "landsat9" = "landsat-8-9-oli",
  "l8" = "landsat-8-9-oli", "l9" = "landsat-8-9-oli",
  "oli" = "landsat-8-9-oli", "landsat" = "landsat-8-9-oli",
  "landsat5" = "landsat-4-7-tm-etm", "landsat7" = "landsat-4-7-tm-etm",
  "l5" = "landsat-4-7-tm-etm", "l7" = "landsat-4-7-tm-etm",
  "tm" = "landsat-4-7-tm-etm", "etm" = "landsat-4-7-tm-etm",
  "s2" = "sentinel-2-msi", "sentinel2" = "sentinel-2-msi",
  "msi" = "sentinel-2-msi",
  "modis" = "modis-mod09ga", "mod09" = "modis-mod09ga",
  "uav" = "generic-multispectral", "generic" = "generic-multispectral"
)

.cs_resolve_sensor <- function(id) {
  cl_assert(is.character(id) && length(id) == 1L, "`sensor` must be a single string.")
  if (exists(id, envir = .cs_sensors, inherits = FALSE)) return(id)
  key <- tolower(gsub("[^a-z0-9]", "", tolower(id)))
  if (key %in% names(.cs_aliases)) return(unname(.cs_aliases[key]))
  cl_abort("Unknown sensor '", id, "'. See cl_sensors() for registered drivers.")
}

#' @export
print.cl_sensor <- function(x, ...) {
  cat("<cl_sensor>", x$id, "\n")
  cat("  name       :", x$name, "\n")
  cat("  bands      :", paste(names(x$bands), collapse = ", "), "\n")
  cat("  footprint  :", x$footprint, "\n")
  cat("  revisit    :", x$revisit, "days (single platform)\n")
  cat("  thermal    :", x$has_thermal, " cirrus:", x$has_cirrus, "\n")
  if (!is.null(x$platforms)) {
    cat("  platforms  :", paste(x$platforms$platform, collapse = ", "), "\n")
  }
  invisible(x)
}

# ---------------------------------------------------------------------------
# Built-in drivers
# ---------------------------------------------------------------------------

.cs_register_builtin <- function() {

  # --- Landsat 8/9 OLI-TIRS ------------------------------------------------
  cl_sensor_register(cl_sensor_driver(
    id = "landsat-8-9-oli",
    name = "Landsat 8/9 OLI-TIRS",
    bands = c(coastal = "coastal", blue = "blue", green = "green", red = "red",
              nir = "nir08", swir16 = "swir16", swir22 = "swir22",
              cirrus = "cirrus", tir1 = "lwir11"),
    resolution = c(coastal = 30, blue = 30, green = 30, red = 30, nir = 30,
                   swir16 = 30, swir22 = 30, cirrus = 30, tir1 = 100),
    platforms = data.frame(
      platform = c("landsat-8", "landsat-9"),
      start    = as.Date(c("2013-04-11", "2021-11-01")),
      end      = as.Date(c(NA, NA)),
      stringsAsFactors = FALSE
    ),
    footprint = "wrs2", revisit = 16,
    qa = cl_qa_spec(
      type = "bitmask", asset = "qa_pixel",
      bits = c(fill = 0, dilated_cloud = 1, cirrus = 2, cloud = 3,
               cloud_shadow = 4, snow = 5, clear = 6, water = 7),
      confidence = list(cloud = c(8, 9), cloud_shadow = c(10, 11),
                        snow = c(12, 13), cirrus = c(14, 15))
    ),
    scale = 2.75e-05, offset = -0.2,
    collections = list(element84 = "landsat-c2-l2",
                       planetary = "landsat-c2-l2",
                       cdse = NA_character_),
    cloud_property = "eo:cloud_cover",
    has_thermal = TRUE, has_cirrus = TRUE,
    notes = "Collection 2 Level-2. QA_PIXEL is produced by CFMask."
  ))

  # --- Landsat 4-7 TM / ETM+ ----------------------------------------------
  cl_sensor_register(cl_sensor_driver(
    id = "landsat-4-7-tm-etm",
    name = "Landsat 4/5 TM and Landsat 7 ETM+",
    bands = c(blue = "blue", green = "green", red = "red", nir = "nir08",
              swir16 = "swir16", swir22 = "swir22", tir1 = "lwir"),
    resolution = c(blue = 30, green = 30, red = 30, nir = 30,
                   swir16 = 30, swir22 = 30, tir1 = 120),
    platforms = data.frame(
      platform = c("landsat-4", "landsat-5", "landsat-7"),
      start    = as.Date(c("1982-08-22", "1984-03-01", "1999-04-15")),
      end      = as.Date(c("1993-12-14", "2013-06-05", "2022-04-06")),
      stringsAsFactors = FALSE
    ),
    footprint = "wrs2", revisit = 16,
    qa = cl_qa_spec(
      type = "bitmask", asset = "qa_pixel",
      bits = c(fill = 0, dilated_cloud = 1, cloud = 3, cloud_shadow = 4,
               snow = 5, clear = 6, water = 7),
      confidence = list(cloud = c(8, 9), cloud_shadow = c(10, 11), snow = c(12, 13))
    ),
    scale = 2.75e-05, offset = -0.2,
    collections = list(element84 = "landsat-c2-l2", planetary = "landsat-c2-l2"),
    has_thermal = TRUE, has_cirrus = FALSE,
    notes = "No cirrus band; cirrus-dependent tests are skipped automatically."
  ))

  # --- Sentinel-2 MSI ------------------------------------------------------
  cl_sensor_register(cl_sensor_driver(
    id = "sentinel-2-msi",
    name = "Sentinel-2 MSI",
    bands = c(coastal = "coastal", blue = "blue", green = "green", red = "red",
              rededge1 = "rededge1", rededge2 = "rededge2", rededge3 = "rededge3",
              nir = "nir", nir08 = "nir08", watervapour = "nir09",
              cirrus = "cirrus", swir16 = "swir16", swir22 = "swir22"),
    resolution = c(coastal = 60, blue = 10, green = 10, red = 10,
                   rededge1 = 20, rededge2 = 20, rededge3 = 20, nir = 10,
                   nir08 = 20, watervapour = 60, cirrus = 60,
                   swir16 = 20, swir22 = 20),
    platforms = data.frame(
      platform = c("sentinel-2a", "sentinel-2b", "sentinel-2c"),
      start    = as.Date(c("2015-06-23", "2017-03-07", "2024-09-05")),
      end      = as.Date(c(NA, NA, NA)),
      stringsAsFactors = FALSE
    ),
    footprint = "mgrs", revisit = 10,
    qa = cl_qa_spec(
      type = "categorical", asset = "scl",
      classes = c(no_data = 0, saturated = 1, cast_shadow = 2, cloud_shadow = 3,
                  vegetation = 4, bare_soil = 5, water = 6, unclassified = 7,
                  cloud_medium = 8, cloud_high = 9, cirrus = 10, snow = 11),
      clear = c("vegetation", "bare_soil", "water", "unclassified")
    ),
    scale = 1e-04, offset = 0,
    collections = list(element84 = "sentinel-2-l2a",
                       planetary = "sentinel-2-l2a",
                       cdse = "SENTINEL-2"),
    cloud_property = "eo:cloud_cover",
    has_thermal = FALSE, has_cirrus = TRUE,
    notes = paste(
      "SCL is produced by Sen2Cor; its behaviour has changed across processing",
      "baselines, so SCL-derived statistics are not homogeneous through time.",
      "Sentinel-2A operated in an extended tailored scenario after 2C became",
      "operational, so nominal revisit understates actual acquisition density."
    )
  ))

  # --- MODIS ---------------------------------------------------------------
  cl_sensor_register(cl_sensor_driver(
    id = "modis-mod09ga",
    name = "MODIS Terra/Aqua surface reflectance (MOD09GA/MYD09GA)",
    bands = c(red = "sur_refl_b01", nir = "sur_refl_b02", blue = "sur_refl_b03",
              green = "sur_refl_b04", swir13 = "sur_refl_b05",
              swir16 = "sur_refl_b06", swir22 = "sur_refl_b07"),
    resolution = c(red = 500, nir = 500, blue = 500, green = 500,
                   swir13 = 500, swir16 = 500, swir22 = 500),
    platforms = data.frame(
      platform = c("terra", "aqua"),
      start    = as.Date(c("2000-02-24", "2002-07-04")),
      end      = as.Date(c(NA, NA)),
      stringsAsFactors = FALSE
    ),
    footprint = "sinusoidal", revisit = 1,
    qa = cl_qa_spec(
      type = "bitmask", asset = "state_1km",
      bits = c(cloud = 0, cloud_shadow = 2, cirrus = 8, snow = 12,
               internal_cloud = 10),
      confidence = NULL
    ),
    scale = 1e-04, offset = 0,
    collections = list(planetary = "modis-09A1-061"),
    cloud_property = NA_character_,
    has_thermal = FALSE, has_cirrus = FALSE,
    notes = paste(
      "Daily coverage at coarse resolution. The surface-reflectance products",
      "carry no scene-level cloud-cover property, so cl_search() cannot filter",
      "or report cloud for this sensor: cloud must be read from the state_1km",
      "quality layer with cl_qa_decode(), which requires the pixels rather",
      "than the metadata. MODIS is therefore not a drop-in third chain for",
      "metadata-based cloud comparison.")
  ))

  # --- Generic / UAV -------------------------------------------------------
  cl_sensor_register(cl_sensor_driver(
    id = "generic-multispectral",
    name = "Generic multispectral raster (UAV, PlanetScope, WorldView, SPOT)",
    bands = c(blue = "blue", green = "green", red = "red", nir = "nir"),
    resolution = c(blue = NA_real_, green = NA_real_, red = NA_real_, nir = NA_real_),
    platforms = NULL, footprint = "none", revisit = NA_real_,
    qa = NULL, scale = 1, offset = 0, collections = list(),
    has_thermal = FALSE, has_cirrus = FALSE,
    notes = paste(
      "Fallback driver for user-supplied rasters. Only algorithms that require",
      "no thermal or cirrus band are available; cl_probability() reports which",
      "methods are applicable via cl_methods(sensor = ...)."
    )
  ))

  invisible(TRUE)
}

#' Bands required by a method, checked against a sensor
#'
#' @param sensor A sensor id or `cl_sensor`.
#' @param required Character vector of standardised band names.
#' @return `TRUE` invisibly, or an error naming the missing bands.
#' @keywords internal
cl_check_bands <- function(sensor, required) {
  drv <- cl_sensor(sensor)
  missing <- setdiff(required, names(drv$bands))
  if (length(missing)) {
    cl_abort("Sensor '", drv$id, "' has no ", paste(missing, collapse = ", "),
             " band(s); this algorithm cannot be applied. ",
             "Use cl_methods(sensor = '", drv$id, "') to list applicable methods.")
  }
  invisible(TRUE)
}
