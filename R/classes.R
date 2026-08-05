# ---------------------------------------------------------------------------
# Module 2: core data structures
#
# Four classes, all S3 for frictionless interoperability with terra and sf:
#   cl_scene   one acquisition: reflectance + metadata + geometry + QA + masks
#   cl_cube    a lazy, time-ordered collection of scenes on a common grid
#   cl_maskset cloud/shadow probability and classification with provenance
#   cl_stats   long-format grid statistics with enforced units
# ---------------------------------------------------------------------------

# --- cl_scene --------------------------------------------------------------

#' Construct a scene
#'
#' A `cl_scene` bundles everything an algorithm needs for one acquisition.
#' Reflectance is held as a `terra::SpatRaster`, which is itself lazy: pixels
#' stay on disk until a computation forces them into memory. Attaching a DEM,
#' solar geometry or QA layer never triggers a read.
#'
#' @param reflectance A `SpatRaster` with layers named using standardised band
#'   names, or `NULL`.
#' @param sensor Sensor id or `cl_sensor` driver.
#' @param datetime Acquisition time (`POSIXct` or something coercible).
#' @param solar_geom List with `zenith` and `azimuth` in degrees; either scalars
#'   (scene-mean) or `SpatRaster` layers (per-pixel).
#' @param view_geom List with `zenith` and `azimuth` in degrees.
#' @param dem Optional elevation `SpatRaster` aligned to `reflectance`.
#' @param qa Optional QA `SpatRaster`.
#' @param masks Named list of `cl_maskset` objects.
#' @param footprint Optional lon/lat vertex matrix or `sf` geometry.
#' @param id Scene identifier.
#' @param manifest A `cl_manifest`.
#' @param ... Additional metadata stored verbatim.
#'
#' @return An object of class `cl_scene`.
#' @export
cl_scene <- function(reflectance = NULL, sensor, datetime = NULL,
                     solar_geom = NULL, view_geom = NULL, dem = NULL,
                     qa = NULL, masks = list(), footprint = NULL,
                     id = NULL, manifest = NULL, ...) {
  drv <- cl_sensor(sensor)
  if (!is.null(datetime) && !inherits(datetime, "POSIXct")) {
    datetime <- as.POSIXct(datetime, tz = "UTC")
  }
  if (!is.null(solar_geom)) .cs_check_geom(solar_geom, "solar_geom")
  if (!is.null(view_geom)) .cs_check_geom(view_geom, "view_geom")
  cl_assert(is.list(masks), "`masks` must be a list of cl_maskset objects.")
  structure(
    list(
      reflectance = reflectance, sensor = drv, datetime = datetime,
      solar_geom = solar_geom, view_geom = view_geom, dem = dem, qa = qa,
      masks = masks, footprint = footprint, id = id,
      meta = list(...),
      manifest = cl_manifest(manifest, sensor = drv$id, scene_id = id)
    ),
    class = "cl_scene"
  )
}

.cs_check_geom <- function(g, name) {
  cl_assert(is.list(g) && all(c("zenith", "azimuth") %in% names(g)),
            "`", name, "` must be a list with `zenith` and `azimuth`.")
  if (is.numeric(g$zenith)) cl_assert_number(g$zenith, paste0(name, "$zenith"), 0, 90)
  if (is.numeric(g$azimuth)) cl_assert_number(g$azimuth, paste0(name, "$azimuth"), -360, 360)
  invisible(TRUE)
}

#' @export
print.cl_scene <- function(x, ...) {
  cat("<cl_scene>", x$id %||% "(unnamed)", "\n")
  cat("  sensor    :", x$sensor$id, "\n")
  cat("  datetime  :", if (is.null(x$datetime)) "-" else format(x$datetime, "%Y-%m-%d %H:%M UTC"), "\n")
  cat("  bands     :", if (is.null(x$reflectance)) "-" else paste(cl_bands(x), collapse = ", "), "\n")
  if (!is.null(x$solar_geom) && is.numeric(x$solar_geom$zenith)) {
    cat("  sun       : zenith", round(x$solar_geom$zenith, 2),
        "deg, azimuth", round(x$solar_geom$azimuth, 2), "deg\n")
  }
  cat("  dem       :", !is.null(x$dem), "  qa:", !is.null(x$qa), "\n")
  if (length(x$masks)) cat("  masks     :", paste(names(x$masks), collapse = ", "), "\n")
  invisible(x)
}

#' Band names present in a scene
#' @param x A `cl_scene`.
#' @return Character vector of standardised band names.
#' @export
cl_bands <- function(x) {
  cl_assert(inherits(x, "cl_scene"), "`x` must be a cl_scene.")
  if (is.null(x$reflectance)) return(character())
  cl_require("terra", reason = "Inspecting scene bands")
  names(x$reflectance)
}

#' Extract a band by standardised name
#' @param x A `cl_scene`.
#' @param band Standardised band name, e.g. `"nir"`.
#' @param required Error if the band is absent.
#' @return A `SpatRaster` layer, or `NULL`.
#' @export
cl_band <- function(x, band, required = TRUE) {
  nms <- cl_bands(x)
  if (!band %in% nms) {
    if (required) {
      cl_abort("Band '", band, "' not present. Available: ",
               paste(nms, collapse = ", "), ".")
    }
    return(NULL)
  }
  x$reflectance[[band]]
}

# --- cl_cube ---------------------------------------------------------------

#' Construct a lazy scene collection
#'
#' A `cl_cube` never holds pixels. It holds an index of scenes plus a template
#' describing the target geometry, and materialises blocks on demand. This is
#' what allows a decade of imagery to be summarised without exhausting memory.
#'
#' @param scenes A list of `cl_scene` objects, or a data frame index with at
#'   least the columns `id`, `datetime`, `sensor` and `href`.
#' @param template Optional `SpatRaster` defining target grid, extent and CRS.
#' @param grid Optional `cl_grid` for statistical aggregation.
#' @param manifest A `cl_manifest`.
#' @return An object of class `cl_cube`.
#' @export
cl_cube <- function(scenes, template = NULL, grid = NULL, manifest = NULL) {
  if (is.list(scenes) && length(scenes) && inherits(scenes[[1L]], "cl_scene")) {
    index <- do.call(rbind, lapply(scenes, function(s) {
      data.frame(id = s$id %||% NA_character_,
                 datetime = s$datetime %||% as.POSIXct(NA),
                 sensor = s$sensor$id, href = NA_character_,
                 stringsAsFactors = FALSE)
    }))
  } else {
    cl_assert(is.data.frame(scenes), "`scenes` must be a list of cl_scene or a data frame.")
    need <- c("id", "datetime", "sensor")
    cl_assert(all(need %in% names(scenes)),
              "Scene index needs columns: ", paste(need, collapse = ", "), ".")
    index <- scenes
    scenes <- NULL
  }
  ord <- order(index$datetime)
  structure(
    list(index = index[ord, , drop = FALSE],
         scenes = if (is.null(scenes)) NULL else scenes[ord],
         template = template, grid = grid,
         manifest = cl_manifest(manifest, n_scenes = nrow(index))),
    class = "cl_cube"
  )
}

#' @export
print.cl_cube <- function(x, ...) {
  cat("<cl_cube>", nrow(x$index), "scenes\n")
  if (nrow(x$index)) {
    rng <- range(x$index$datetime, na.rm = TRUE)
    cat("  period  :", format(rng[1], "%Y-%m-%d"), "to", format(rng[2], "%Y-%m-%d"), "\n")
    tb <- table(x$index$sensor)
    cat("  sensors :", paste(names(tb), unname(tb), sep = " (n=", collapse = "), "), ")\n")
  }
  cat("  loaded  :", !is.null(x$scenes), "\n")
  invisible(x)
}

#' @export
length.cl_cube <- function(x) nrow(x$index)

# --- cl_maskset ------------------------------------------------------------

#' Construct a cloud/shadow mask set
#'
#' Keeping probability and class in one object with the threshold and method
#' recorded means a mask can always be re-thresholded without recomputation,
#' and that comparisons between methods carry their own provenance.
#'
#' @param probability `SpatRaster` or numeric matrix of cloud probability in
#'   \[0, 1\].
#' @param class Optional integer `SpatRaster`/matrix of class codes. See
#'   [cl_classes()] for the coding.
#' @param shadow Optional shadow probability layer.
#' @param method Name of the generating algorithm.
#' @param threshold Probability threshold used to derive `class`.
#' @param manifest A `cl_manifest`.
#' @param ... Additional algorithm parameters, recorded verbatim.
#' @return An object of class `cl_maskset`.
#' @export
cl_maskset <- function(probability, class = NULL, shadow = NULL,
                       method = NA_character_, threshold = NA_real_,
                       manifest = NULL, ...) {
  structure(
    list(probability = probability, class = class, shadow = shadow,
         method = method, threshold = threshold, params = list(...),
         manifest = cl_manifest(manifest, method = method, threshold = threshold)),
    class = "cl_maskset"
  )
}

#' Standard class coding
#'
#' cloudscape uses one class vocabulary across all sensors and algorithms so
#' that masks from Fmask, Sen2Cor SCL, s2cloudless and neural models can be
#' compared directly.
#'
#' @return A named integer vector.
#' @export
#' @examples
#' cl_classes()
cl_classes <- function() {
  c(fill = 0L, clear_land = 1L, clear_water = 2L, cloud_thin = 3L,
    cloud_thick = 4L, cloud_shadow = 5L, snow_ice = 6L, terrain_shadow = 7L)
}

#' @export
print.cl_maskset <- function(x, ...) {
  cat("<cl_maskset>\n")
  cat("  method    :", x$method, "\n")
  cat("  threshold :", x$threshold, "\n")
  cat("  layers    : probability",
      if (!is.null(x$class)) ", class" else "",
      if (!is.null(x$shadow)) ", shadow" else "", "\n", sep = "")
  invisible(x)
}

# --- cl_obs ----------------------------------------------------------------
#
# Lives here rather than with the availability functions that consume it: it is
# a data structure, and putting a constructor in an analysis module forced the
# catalogue reader (layer 1) to depend on analysis code (layer 3). The
# architecture test caught that; this is the fix.

#' Build an observation table
#'
#' @param cell Integer grid cell ids.
#' @param date Acquisition dates.
#' @param cloud_fraction Cloud fraction in \[0, 1\] for the cell.
#' @param sensor Sensor ids.
#' @param platform Optional platform names.
#' @param tier Which evidence tier the cloud fractions came from:
#'   `"metadata"` (scene-level catalogue property), `"qa"` (aggregated quality
#'   layer) or `"mask"` (computed mask).
#' @param shadow_fraction,snow_fraction Optional additional fractions.
#' @return An object of class `cl_obs`, inheriting from `data.frame`.
#' @export
cl_obs <- function(cell, date, cloud_fraction, sensor = NA_character_,
                   platform = NA_character_, tier = "metadata",
                   shadow_fraction = NA_real_, snow_fraction = NA_real_) {
  cl_assert_choice(tier, "tier", c("metadata", "qa", "mask"))
  cf <- as.numeric(cloud_fraction)
  if (any(cf > 1, na.rm = TRUE)) {
    cl_warn("`cloud_fraction` contains values above 1; assuming percent and dividing by 100.")
    cf <- cf / 100
  }
  cl_assert(all(cf >= 0 & cf <= 1, na.rm = TRUE),
            "`cloud_fraction` must lie in [0, 1] (or [0, 100] as percent).")
  df <- data.frame(
    cell = as.integer(cell), date = as.Date(date),
    sensor = as.character(sensor), platform = as.character(platform),
    cloud_fraction = cf,
    shadow_fraction = as.numeric(shadow_fraction),
    snow_fraction = as.numeric(snow_fraction),
    stringsAsFactors = FALSE
  )
  df <- df[order(df$cell, df$date), , drop = FALSE]
  structure(df, class = c("cl_obs", "data.frame"), tier = tier)
}

#' @export
print.cl_obs <- function(x, n = 6L, ...) {
  cat("<cl_obs>", nrow(x), "observations,", length(unique(x$cell)), "cells, tier:",
      attr(x, "tier"), "\n")
  if (nrow(x)) {
    cat("  period :", format(min(x$date)), "to", format(max(x$date)), "\n")
    cat("  cloud  : mean", round(mean(x$cloud_fraction, na.rm = TRUE), 3),
        " median", round(stats::median(x$cloud_fraction, na.rm = TRUE), 3), "\n")
  }
  print(utils::head(as.data.frame(x), n))
  invisible(x)
}


# --- cl_stats --------------------------------------------------------------

# The vocabulary of permitted metrics and their units. Any aggregation that
# changes the denominator must also change the unit, which the validator
# enforces. This exists because scene-level and per-year aggregates of the same
# underlying quantity are easily mislabelled, and a mislabelled denominator
# turns a correct computation into a wrong published number.
.CS_METRICS <- data.frame(
  metric = c("n_scenes", "n_clear_obs", "cloud_fraction", "clear_fraction",
             "shadow_fraction", "snow_fraction", "max_gap_days",
             "mean_gap_days", "p_clear", "revisit_days", "sos_error_days",
             "disagreement"),
  unit = c("count", "count", "fraction", "fraction",
           "fraction", "fraction", "days",
           "days", "probability", "days", "days",
           "fraction"),
  lower = c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  upper = c(Inf, Inf, 1, 1, 1, 1, Inf, Inf, 1, Inf, Inf, 1),
  # How two values of the same metric combine. Getting this wrong is easy and
  # silent: a maximum gap is not additive and not averageable, and a fraction
  # combined without weighting by sample size gives the mean of means, which
  # is not the mean.
  combine = c("sum", "sum", "wmean", "wmean",
              "wmean", "wmean", "max",
              "wmean", "wmean", "wmean", "wmean",
              "wmean"),
  stringsAsFactors = FALSE
)

#' Construct a grid statistics table
#'
#' `cl_stats` is a long-format table: one row per cell, period, sensor and
#' metric. Every row must declare its `unit`, its sample size `n`, and the
#' `denominator` the value is expressed per. The constructor validates these
#' against a controlled vocabulary and refuses out-of-range values.
#'
#' This strictness is deliberate. A count of images summed over ten years and
#' then divided by ten is a mean *per year*, not a mean *per scene footprint*;
#' presenting one as the other produces values that are physically impossible
#' for the stated denominator. Encoding the denominator in the data structure
#' makes that class of error a validation failure rather than a published
#' table.
#'
#' @param cell Integer grid cell ids.
#' @param metric Metric name; see [cl_metrics()].
#' @param value Numeric values.
#' @param period Character period labels, e.g. `"2023"` or `"2023-06"`.
#' @param sensor Sensor ids.
#' @param n Sample size behind each value.
#' @param se Optional standard errors.
#' @param denominator What the value is expressed per: one of `"cell"`,
#'   `"cell-year"`, `"cell-month"`, `"scene"`, `"pixel"`.
#' @param grid Optional `cl_grid` the cells refer to.
#' @param manifest A `cl_manifest`.
#'
#' @return An object of class `cl_stats`, which inherits from `data.frame`.
#' @export
#' @examples
#' s <- cl_stats(cell = 1:3, metric = "cloud_fraction", value = c(.2, .5, .9),
#'               period = "2023", sensor = "sentinel-2-msi", n = c(40, 38, 41),
#'               denominator = "cell-year")
#' summary(s)
cl_stats <- function(cell, metric, value, period = NA_character_,
                     sensor = NA_character_, n = NA_integer_, se = NA_real_,
                     denominator = "cell-year", grid = NULL, manifest = NULL) {
  df <- data.frame(
    cell = as.integer(cell), period = as.character(period),
    sensor = as.character(sensor), metric = as.character(metric),
    value = as.numeric(value), n = as.integer(n), se = as.numeric(se),
    stringsAsFactors = FALSE
  )
  df$denominator <- as.character(denominator)
  df$unit <- .CS_METRICS$unit[match(df$metric, .CS_METRICS$metric)]
  validate_cl_stats(df)
  structure(df, class = c("cl_stats", "data.frame"),
            grid = grid,
            manifest = cl_manifest(manifest, n_rows = nrow(df)))
}

#' Validate a statistics table
#' @param df A data frame or `cl_stats`.
#' @return `TRUE` invisibly, or an error describing the first violation.
#' @export
validate_cl_stats <- function(df) {
  need <- c("cell", "period", "sensor", "metric", "value", "n", "denominator")
  missing <- setdiff(need, names(df))
  if (length(missing)) cl_abort("cl_stats is missing column(s): ",
                                paste(missing, collapse = ", "), ".")
  unknown <- setdiff(unique(df$metric), .CS_METRICS$metric)
  if (length(unknown)) {
    cl_abort("Unknown metric(s): ", paste(unknown, collapse = ", "),
             ". See cl_metrics() for the controlled vocabulary.")
  }
  ok_denom <- c("cell", "cell-year", "cell-month", "cell-season", "scene", "pixel")
  bad <- setdiff(unique(df$denominator), ok_denom)
  if (length(bad)) {
    cl_abort("Unknown denominator(s): ", paste(bad, collapse = ", "),
             ". Must be one of: ", paste(ok_denom, collapse = ", "), ".")
  }
  spec <- .CS_METRICS[match(df$metric, .CS_METRICS$metric), ]
  bad <- which(!is.na(df$value) & (df$value < spec$lower | df$value > spec$upper))
  if (length(bad)) {
    i <- bad[1L]
    cl_abort("Metric '", df$metric[i], "' has value ", df$value[i],
             " outside its permitted range [", spec$lower[i], ", ",
             spec$upper[i], "] (row ", i, ").")
  }
  if (any(!is.na(df$n) & df$n < 0)) cl_abort("`n` must be non-negative.")
  invisible(TRUE)
}

#' The controlled metric vocabulary
#' @return A data frame of metric names, units and permitted ranges.
#' @export
cl_metrics <- function() .CS_METRICS

#' Combine statistics tables
#'
#' Merges rows describing the same cell, period, sensor and metric, using the
#' combination rule declared for each metric in [cl_metrics()]: counts add,
#' fractions and rates combine as sample-size-weighted means, and maximum gap
#' takes the maximum.
#'
#' This is for combining *disjoint* evidence, such as separate years, sensors
#' or spatial partitions. It cannot repair double counting: if the same
#' acquisition was aggregated into two inputs, summing the counts will inflate
#' them. Deduplicate at the observation level before aggregating.
#'
#' @param ... `cl_stats` tables.
#' @param grid Optional `cl_grid` recorded on the result.
#' @return A single `cl_stats` table.
#' @export
#' @examples
#' a <- cl_stats(1:2, "n_scenes", c(10, 12), period = "2023", n = c(10, 12))
#' b <- cl_stats(1:2, "n_scenes", c(5, 6), period = "2023", n = c(5, 6))
#' cl_stats_merge(a, b)$value
cl_stats_merge <- function(..., grid = NULL) {
  parts <- list(...)
  if (length(parts) == 1L && is.list(parts[[1L]]) &&
      !inherits(parts[[1L]], "data.frame")) {
    parts <- parts[[1L]]
  }
  parts <- Filter(function(x) !is.null(x) && nrow(x) > 0L, parts)
  if (!length(parts)) cl_abort("Nothing to merge.")
  df <- do.call(rbind, lapply(parts, as.data.frame))
  key <- paste(df$cell, df$period, df$sensor, df$metric, sep = "\r")
  sp <- split(seq_len(nrow(df)), key)
  rule <- stats::setNames(.CS_METRICS$combine, .CS_METRICS$metric)

  out <- do.call(rbind, lapply(sp, function(ix) {
    r <- df[ix[1L], , drop = FALSE]
    if (length(ix) > 1L) {
      v <- df$value[ix]; n <- df$n[ix]; n[is.na(n)] <- 0
      r$value <- switch(rule[[r$metric]],
        sum   = sum(v, na.rm = TRUE),
        max   = max(v, na.rm = TRUE),
        wmean = if (sum(n) > 0) sum(v * n, na.rm = TRUE) / sum(n)
                else mean(v, na.rm = TRUE))
      r$n <- sum(df$n[ix], na.rm = TRUE)
      r$se <- NA_real_   # not recoverable from summaries alone
    }
    r
  }))
  rownames(out) <- NULL
  validate_cl_stats(out)
  structure(out, class = c("cl_stats", "data.frame"),
            grid = grid %||% attr(parts[[1L]], "grid"),
            manifest = cl_manifest(NULL, merged_from = length(parts),
                                   n_rows = nrow(out)))
}

#' @export
summary.cl_stats <- function(object, ...) {
  sp <- split(object$value, object$metric)
  out <- do.call(rbind, lapply(names(sp), function(m) {
    v <- sp[[m]]
    data.frame(metric = m,
               unit = .CS_METRICS$unit[match(m, .CS_METRICS$metric)],
               n_rows = length(v),
               min = min(v, na.rm = TRUE),
               median = stats::median(v, na.rm = TRUE),
               mean = mean(v, na.rm = TRUE),
               max = max(v, na.rm = TRUE),
               stringsAsFactors = FALSE)
  }))
  rownames(out) <- NULL
  out
}

#' @export
print.cl_stats <- function(x, n = 6L, ...) {
  cat("<cl_stats>", nrow(x), "rows,",
      length(unique(x$cell)), "cells,",
      length(unique(x$metric)), "metrics\n")
  denom <- unique(x$denominator)
  cat("  denominator:", paste(denom, collapse = ", "), "\n")
  print(utils::head(as.data.frame(x), n))
  if (nrow(x) > n) cat("  ...", nrow(x) - n, "more rows\n")
  invisible(x)
}

#' Reshape statistics from long to wide
#' @param x A `cl_stats`.
#' @param metrics Metrics to include; defaults to all.
#' @return A data frame with one row per cell/period/sensor and one column per
#'   metric.
#' @export
cl_stats_wide <- function(x, metrics = NULL) {
  cl_assert(inherits(x, "cl_stats"), "`x` must be a cl_stats.")
  if (!is.null(metrics)) x <- x[x$metric %in% metrics, , drop = FALSE]
  key <- paste(x$cell, x$period, x$sensor, sep = "\r")
  ukey <- unique(key)
  parts <- do.call(rbind, strsplit(ukey, "\r", fixed = TRUE))
  out <- data.frame(cell = as.integer(parts[, 1]), period = parts[, 2],
                    sensor = parts[, 3], stringsAsFactors = FALSE)
  for (m in unique(x$metric)) {
    sub <- x[x$metric == m, , drop = FALSE]
    out[[m]] <- sub$value[match(ukey, paste(sub$cell, sub$period, sub$sensor, sep = "\r"))]
  }
  out
}
