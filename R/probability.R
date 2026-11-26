# ---------------------------------------------------------------------------
# Module 4: cloud probability
#
# Algorithms are registered, not hard-coded. Each entry declares the bands it
# needs, so cl_methods(sensor = ...) can report which methods are applicable
# before anything is downloaded, and a method that needs a thermal band fails
# with a clear message on Sentinel-2 rather than producing silent nonsense.
# ---------------------------------------------------------------------------

.cs_methods <- new.env(parent = emptyenv())

#' Register a cloud-probability method
#'
#' @param name Method name.
#' @param fun Function with signature `(bands, geom, drv, ...)` returning a
#'   numeric matrix of probabilities in \[0, 1\].
#' @param requires Standardised band names the method needs.
#' @param optional Bands the method uses if present.
#' @param type `"physical"`, `"statistical"` or `"learned"`.
#' @param reference Short citation.
#' @param overwrite Replace an existing registration.
#' @return The method name, invisibly.
#' @export
cl_method_register <- function(name, fun, requires, optional = character(),
                               type = "physical", reference = NA_character_,
                               overwrite = FALSE) {
  if (!overwrite && exists(name, envir = .cs_methods, inherits = FALSE)) {
    cl_abort("Method '", name, "' already registered. Use overwrite = TRUE.")
  }
  assign(name, list(name = name, fun = fun, requires = requires,
                    optional = optional, type = type, reference = reference),
         envir = .cs_methods)
  invisible(name)
}

#' List available cloud-probability methods
#'
#' @param sensor Optional sensor id; when supplied, only methods whose required
#'   bands the sensor provides are returned.
#' @return A data frame of methods.
#' @export
#' @examples
#' cl_methods()
#' cl_methods(sensor = "sentinel-2-msi")   # no thermal-based methods
cl_methods <- function(sensor = NULL) {
  ids <- sort(ls(envir = .cs_methods))
  out <- do.call(rbind, lapply(ids, function(i) {
    m <- get(i, envir = .cs_methods, inherits = FALSE)
    data.frame(method = m$name, type = m$type,
               requires = paste(m$requires, collapse = ", "),
               reference = m$reference, stringsAsFactors = FALSE)
  }))
  if (!is.null(sensor)) {
    drv <- cl_sensor(sensor)
    ok <- vapply(ids, function(i) {
      m <- get(i, envir = .cs_methods, inherits = FALSE)
      all(m$requires %in% names(drv$bands))
    }, logical(1))
    out <- out[ok, , drop = FALSE]
  }
  rownames(out) <- NULL
  out
}

#' Compute cloud probability
#'
#' @param x A `cl_scene`, or a named list of reflectance matrices.
#' @param method Method name; see [cl_methods()].
#' @param sensor Sensor id, required when `x` is a plain list.
#' @param geom Optional list with `sun_zenith`, `sun_azimuth`, `view_zenith`,
#'   `view_azimuth`.
#' @param threshold Probability threshold used to derive the class layer.
#' @param buffer Dilate the resulting cloud mask by this many pixels, in
#'   city-block distance. Cloud masks tend to miss cloud edges, and a small
#'   buffer is common practice; the default of 0 leaves that choice to the
#'   user.
#' @param ... Passed to the method.
#' @return A `cl_maskset`.
#' @export
#' @examples
#' s <- cl_simulate(64, 64, coverage = 0.3, seed = 1,
#'                  background = list(blue = matrix(0.08, 64, 64),
#'                                    green = matrix(0.09, 64, 64),
#'                                    red = matrix(0.07, 64, 64),
#'                                    nir = matrix(0.35, 64, 64),
#'                                    swir16 = matrix(0.22, 64, 64)))
#' m <- cl_probability(s$bands, method = "threshold", sensor = "sentinel-2-msi")
#' round(mean(m$class), 2)
cl_probability <- function(x, method = "threshold", sensor = NULL, geom = NULL,
                           threshold = 0.5, buffer = 0, ...) {
  if (!exists(method, envir = .cs_methods, inherits = FALSE)) {
    cl_abort("Unknown method '", method, "'. Available: ",
             paste(cl_methods()$method, collapse = ", "), ".")
  }
  m <- get(method, envir = .cs_methods, inherits = FALSE)

  if (inherits(x, "cl_scene")) {
    drv <- x$sensor
    bands <- stats::setNames(lapply(cl_bands(x), function(b) .cs_as_matrix(cl_band(x, b))),
                             cl_bands(x))
    geom <- geom %||% list(sun_zenith = x$solar_geom$zenith,
                           sun_azimuth = x$solar_geom$azimuth,
                           view_zenith = x$view_geom$zenith %||% 0,
                           view_azimuth = x$view_geom$azimuth %||% 0)
  } else {
    cl_assert(is.list(x) && !is.null(names(x)),
              "`x` must be a cl_scene or a named list of band matrices.")
    cl_assert(!is.null(sensor), "`sensor` is required when `x` is a plain list.")
    drv <- cl_sensor(sensor)
    bands <- lapply(x, .cs_as_matrix)
  }

  missing <- setdiff(m$requires, names(bands))
  if (length(missing)) {
    cl_abort("Method '", method, "' requires band(s) ",
             paste(missing, collapse = ", "), " which are not present. ",
             "Applicable methods for this sensor: ",
             paste(cl_methods(drv$id)$method, collapse = ", "), ".")
  }

  p <- m$fun(bands, geom, drv, ...)
  p <- .cs_clamp(p)
  cls <- (p >= threshold) * 1
  if (buffer > 0) cls <- .cs_dilate(cls, buffer)
  cl_maskset(probability = p, class = cls, method = method,
             threshold = threshold, buffer = buffer,
             manifest = cl_manifest(NULL, sensor = drv$id, method = method,
                                    type = m$type, reference = m$reference))
}

# --- built-in methods ------------------------------------------------------

.cs_register_methods <- function() {

  # Brightness/whiteness threshold. Deliberately simple: a transparent baseline
  # that every other method should beat, and the only method that works on a
  # four-band UAV camera.
  cl_method_register(
    "threshold",
    requires = c("blue", "green", "red"),
    optional = c("nir", "swir16"),
    type = "physical",
    reference = "Brightness-whiteness baseline",
    fun = function(bands, geom, drv, bright = 0.25, white = 0.25, ...) {
      vis <- (bands$blue + bands$green + bands$red) / 3
      whiteness <- (abs(bands$blue - vis) + abs(bands$green - vis) +
                      abs(bands$red - vis)) / pmax(vis, 1e-6)
      p_bright <- .cs_logistic_scale(vis, bright, 0.08)
      p_white <- 1 - .cs_logistic_scale(whiteness, white, 0.10)
      p <- sqrt(p_bright * p_white)
      if (!is.null(bands$nir) && !is.null(bands$swir16)) {
        ndsi <- (bands$green - bands$swir16) / pmax(bands$green + bands$swir16, 1e-6)
        ndvi <- (bands$nir - bands$red) / pmax(bands$nir + bands$red, 1e-6)
        # Vegetation and snow are bright but not cloud
        p <- p * (1 - 0.7 * .cs_logistic_scale(ndvi, 0.4, 0.1))
        p <- p * (1 - 0.7 * .cs_logistic_scale(ndsi, 0.4, 0.1))
      }
      p
    })

  # Fmask-style potential cloud layer: the classical decision cascade, adapted
  # to return a continuous score rather than a hard mask so that it can be
  # calibrated and compared on equal terms with probabilistic methods.
  cl_method_register(
    "fmask",
    requires = c("blue", "green", "red", "nir", "swir16", "swir22"),
    optional = c("cirrus", "tir1"),
    type = "physical",
    reference = "Zhu & Woodcock style decision cascade",
    fun = function(bands, geom, drv, ...) {
      eps <- 1e-6
      ndsi <- (bands$green - bands$swir16) / pmax(bands$green + bands$swir16, eps)
      ndvi <- (bands$nir - bands$red) / pmax(bands$nir + bands$red, eps)
      # Fmask's potential-cloud layer is a CONJUNCTION of tests, not a
      # weighted average. Combining them additively lets a clear pixel that
      # passes the permissive tests (swir22 > 0.03, NIR/SWIR ratio) accumulate
      # enough score to cross the threshold even though the discriminating HOT
      # test rejects it. The soft product preserves the logical structure and
      # keeps the output calibrated, so a 0.5 threshold means what it says.
      basic <- .cs_logistic_scale(bands$swir22, 0.03, 0.01) *
        (1 - .cs_logistic_scale(ndsi, 0.8, 0.05)) *
        (1 - .cs_logistic_scale(ndvi, 0.8, 0.05))
      vis <- (bands$blue + bands$green + bands$red) / 3
      whiteness <- (abs(bands$blue - vis) + abs(bands$green - vis) +
                      abs(bands$red - vis)) / pmax(vis, eps)
      w <- 1 - .cs_logistic_scale(whiteness, 0.7, 0.1)
      # Haze-optimised transform: the discriminating test of the cascade
      hot <- bands$blue - 0.5 * bands$red - 0.08
      h <- .cs_logistic_scale(hot, 0, 0.02)
      ratio <- bands$nir / pmax(bands$swir16, eps)
      r <- .cs_logistic_scale(ratio, 0.75, 0.15)
      p <- basic * w * h * r
      if (!is.null(bands$cirrus) && isTRUE(drv$has_cirrus)) {
        pc <- .cs_logistic_scale(bands$cirrus, 0.01, 0.005)
        p <- pmax(p, pc)   # cirrus is diagnostic on its own
      }
      if (!is.null(bands$tir1) && isTRUE(drv$has_thermal)) {
        tq <- stats::quantile(bands$tir1, c(0.175, 0.825), na.rm = TRUE, names = FALSE)
        cold <- 1 - .cs_logistic_scale(bands$tir1, tq[1], max(1, diff(tq) / 4))
        p <- pmin(1, p * (0.6 + 0.6 * cold))
      }
      p
    })

  # Read the sensor's own quality layer. Not a detector but the honest baseline
  # every operational user actually starts from, and the reference against
  # which cl_disagreement() measures other methods.
  cl_method_register(
    "qa",
    requires = character(),
    type = "physical",
    reference = "Native producer QA (CFMask / Sen2Cor SCL)",
    fun = function(bands, geom, drv, qa = NULL, include_cirrus = TRUE, ...) {
      cl_assert(!is.null(qa), "method = \"qa\" needs the QA layer via `qa = `.")
      cl_assert(!is.null(drv$qa), "Sensor '", drv$id, "' has no QA specification.")
      cl_qa_decode(qa, drv, include_cirrus = include_cirrus)$cloud * 1
    })

  # Learned methods: registered so that cl_methods() advertises them and the
  # error message is actionable, rather than the function simply not existing.
  for (nm in c("s2cloudless", "randomforest", "xgboost", "unet")) {
    local({
      n <- nm
      cl_method_register(
        n, requires = c("blue", "red", "nir"), type = "learned",
        reference = "not implemented: needs pre-trained weights",
        fun = function(bands, geom, drv, model = NULL, ...) {
          cl_abort(
            "Method '", n, "' is registered but not implemented: it needs ",
            "pre-trained weights, which this version of cloudscape does not ",
            "distribute.\n",
            "  To use your own detector under this name, register it with ",
            "cl_method_register(\"", n, "\", fun, requires, overwrite = TRUE)."
          )
        })
    })
  }
  invisible(TRUE)
}

# Smooth threshold: maps x to [0, 1] with midpoint `mid` and scale `sc`.
# Used everywhere instead of hard cut-offs so that outputs are continuous and
# can be calibrated, which hard thresholds cannot.
.cs_logistic_scale <- function(x, mid, sc) 1 / (1 + exp(-(x - mid) / max(sc, 1e-9)))

#' Decode a producer quality layer
#'
#' Translates a bit-packed or categorical QA band into the standard class
#' vocabulary of [cl_classes()], using the sensor driver's specification.
#'
#' For bit-packed layers, each flag is either a single bit or a field of
#' several bits with the values that raise it (see [cl_qa_spec()]); flags the
#' specification does not define are never raised. For categorical layers,
#' pixels whose code is neither a cloud, cloud-shadow or snow class nor listed
#' in the specification's `clear` set are invalid and reported as `fill`. For
#' Sentinel-2 `SCL` this marks no-data and saturated or defective pixels
#' (classes 0 and 1) as invalid, and counts topographic cast shadow (class 2),
#' vegetation, bare soil, water and unclassified pixels (classes 4 to 7) as
#' valid and cloud-free. Missing values are invalid for both types.
#'
#' @param qa QA matrix or `SpatRaster`.
#' @param sensor Sensor id or driver.
#' @param include_cirrus Treat flagged cirrus as cloud. Ignored for sensors
#'   whose QA has no cirrus flag.
#' @param confidence Minimum cloud confidence (`"medium"` or `"high"`) for
#'   bit-packed QA with confidence fields. Pixels at or above it are cloud, in
#'   addition to those with the cloud bit set. The lowest level is not offered
#'   because the Landsat Collection 2 algorithm assigns it to almost all clear
#'   pixels.
#' @return A list of logical matrices: `cloud`, `shadow`, `snow`, `water`,
#'   `fill`, plus `class` in the standard vocabulary.
#' @export
cl_qa_decode <- function(qa, sensor, include_cirrus = TRUE, confidence = "medium") {
  drv <- cl_sensor(sensor)
  spec <- drv$qa
  cl_assert(!is.null(spec), "Sensor '", drv$id, "' has no QA specification.")
  cl_assert_choice(confidence, "confidence", c("medium", "high"))
  q <- .cs_as_matrix(qa)
  na <- is.na(q)
  qi <- matrix(as.integer(q), nrow(q), ncol(q))
  qi[na] <- 0L
  cls <- cl_classes()
  none <- matrix(FALSE, nrow(q), ncol(q))

  if (spec$type == "bitmask") {
    bit <- function(nm) {
      if (!nm %in% names(spec$bits)) return(none)
      f <- spec$bits[[nm]]
      if (is.list(f)) {
        lo <- min(f$bits)
        v <- bitwAnd(bitwShiftR(qi, lo), bitwShiftL(1L, length(f$bits)) - 1L)
        return(matrix(v %in% f$values, nrow(q), ncol(q)))
      }
      matrix(bitwAnd(qi, bitwShiftL(1L, as.integer(f))) > 0, nrow(q), ncol(q))
    }
    cloud <- bit("cloud") | bit("dilated_cloud")
    if (include_cirrus) cloud <- cloud | bit("cirrus")
    if (!is.null(spec$confidence$cloud)) {
      lvl <- c(medium = 2L, high = 3L)[[confidence]]
      b <- spec$confidence$cloud
      conf <- matrix(bitwAnd(bitwShiftR(qi, min(b)), 3L), nrow(q), ncol(q))
      cloud <- cloud | (conf >= lvl)
    }
    shadow <- bit("cloud_shadow"); snow <- bit("snow")
    water <- bit("water"); fill <- bit("fill")
    terrain <- none
  } else {
    code <- spec$classes
    inset <- function(nms) {
      w <- unlist(code[intersect(nms, names(code))])
      matrix(qi %in% w, nrow(q), ncol(q))
    }
    cloud_cls <- c("cloud_medium", "cloud_high", "cloud", "cirrus")
    cloud <- inset(setdiff(cloud_cls, if (!include_cirrus) "cirrus"))
    cirrus_clear <- if (!include_cirrus) inset("cirrus") else none
    shadow <- inset("cloud_shadow")
    snow <- inset("snow"); water <- inset("water")
    terrain <- inset("cast_shadow")
    valid <- if (is.null(spec$clear)) !inset("no_data") else
      cloud | cirrus_clear | shadow | snow | inset(spec$clear)
    fill <- !valid
  }
  fill <- fill | na
  cloud <- cloud & !fill; shadow <- shadow & !fill; snow <- snow & !fill
  water <- water & !fill; terrain <- terrain & !fill

  class <- matrix(cls[["clear_land"]], nrow(q), ncol(q))
  class[water] <- cls[["clear_water"]]
  class[terrain] <- cls[["terrain_shadow"]]
  class[snow] <- cls[["snow_ice"]]
  class[shadow] <- cls[["cloud_shadow"]]
  class[cloud] <- cls[["cloud_thick"]]
  class[fill] <- cls[["fill"]]
  list(cloud = cloud, shadow = shadow, snow = snow, water = water,
       fill = fill, class = class)
}
