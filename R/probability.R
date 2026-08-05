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
#' @param buffer Dilate the resulting cloud mask by this many pixels. Cloud
#'   masks systematically under-detect at edges, so a small buffer is standard
#'   practice; the default of 0 leaves that decision explicit.
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
        reference = "requires cloudscape.data",
        fun = function(bands, geom, drv, model = NULL, ...) {
          cl_abort(
            "Method '", n, "' needs pre-trained weights, which are distributed ",
            "in the companion data package because CRAN limits package size.\n",
            "  install.packages(\"cloudscape.data\", repos = ",
            "\"https://ehsanrahimi666.r-universe.dev\")\n",
            "  Or pass your own fitted model via `model = `."
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
#' @param qa QA matrix or `SpatRaster`.
#' @param sensor Sensor id or driver.
#' @param include_cirrus Treat flagged cirrus as cloud.
#' @param confidence Minimum confidence level (`"low"`, `"medium"`, `"high"`)
#'   for bit-packed QA with confidence fields.
#' @return A list of logical matrices: `cloud`, `shadow`, `snow`, `water`,
#'   `fill`, plus `class` in the standard vocabulary.
#' @export
cl_qa_decode <- function(qa, sensor, include_cirrus = TRUE, confidence = "medium") {
  drv <- cl_sensor(sensor)
  spec <- drv$qa
  cl_assert(!is.null(spec), "Sensor '", drv$id, "' has no QA specification.")
  q <- .cs_as_matrix(qa)
  cls <- cl_classes()

  if (spec$type == "bitmask") {
    bit <- function(nm) {
      if (is.null(spec$bits[[nm]])) return(array(FALSE, dim(q)))
      matrix(bitwAnd(as.integer(q), bitwShiftL(1L, spec$bits[[nm]])) > 0, nrow(q), ncol(q))
    }
    cloud <- bit("cloud") | bit("dilated_cloud")
    if (include_cirrus) cloud <- cloud | bit("cirrus")
    if (!is.null(spec$confidence$cloud)) {
      lvl <- c(low = 1L, medium = 2L, high = 3L)[confidence]
      b <- spec$confidence$cloud
      conf <- matrix(bitwAnd(bitwShiftR(as.integer(q), b[1]), 3L), nrow(q), ncol(q))
      cloud <- cloud | (conf >= lvl)
    }
    shadow <- bit("cloud_shadow"); snow <- bit("snow")
    water <- bit("water"); fill <- bit("fill")
  } else {
    code <- spec$classes
    inset <- function(nms) {
      w <- unlist(code[intersect(nms, names(code))])
      matrix(q %in% w, nrow(q), ncol(q))
    }
    cloud <- inset(c("cloud_medium", "cloud_high", if (include_cirrus) "cirrus"))
    shadow <- inset("cloud_shadow")
    snow <- inset("snow"); water <- inset("water"); fill <- inset("no_data")
  }

  class <- matrix(cls[["clear_land"]], nrow(q), ncol(q))
  class[water] <- cls[["clear_water"]]
  class[snow] <- cls[["snow_ice"]]
  class[shadow] <- cls[["cloud_shadow"]]
  class[cloud] <- cls[["cloud_thick"]]
  class[fill] <- cls[["fill"]]
  list(cloud = cloud, shadow = shadow, snow = snow, water = water,
       fill = fill, class = class)
}
