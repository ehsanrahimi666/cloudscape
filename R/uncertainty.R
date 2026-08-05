# ---------------------------------------------------------------------------
# Module 6: uncertainty and inter-method disagreement
#
# Published cloud masks disagree with each other far more than any of them
# disagrees with its own validation set, because validation sets are not drawn
# from the surfaces where masks fail: snow and ice, bright soil, sun glint,
# coastal water and thin cirrus. Mapping disagreement requires no new algorithm
# and no reference labels, and it identifies exactly the regions where a cloud
# statistic should not be trusted.
# ---------------------------------------------------------------------------

#' Agreement among several masks
#'
#' @param masks Named list of `cl_maskset` objects or 0/1 matrices.
#' @return A list with `agreement` (fraction of methods calling cloud),
#'   `consensus` (majority mask), `entropy` (binary entropy of the vote) and
#'   `unanimous` (logical matrix).
#' @export
#' @examples
#' a <- matrix(c(1,1,0,0), 2, 2); b <- matrix(c(1,0,0,0), 2, 2)
#' cl_agreement(list(a = a, b = b))$agreement
cl_agreement <- function(masks) {
  cl_assert(is.list(masks) && length(masks) >= 2L,
            "`masks` must be a list of at least two masks.")
  M <- lapply(masks, .cs_mask_matrix)
  d <- dim(M[[1L]])
  cl_assert(all(vapply(M, function(m) identical(dim(m), d), logical(1))),
            "All masks must have identical dimensions.")
  s <- Reduce(`+`, M)
  frac <- s / length(M)
  p <- pmin(pmax(frac, 1e-9), 1 - 1e-9)
  list(agreement = frac,
       consensus = (frac > 0.5) * 1,
       entropy = -(p * log2(p) + (1 - p) * log2(1 - p)),
       unanimous = (frac == 0 | frac == 1))
}

.cs_mask_matrix <- function(m) {
  if (inherits(m, "cl_maskset")) m <- m$class %||% m$probability
  (.cs_as_matrix(m) > 0) * 1
}

#' Pairwise disagreement between masks
#'
#' @param masks Named list of masks.
#' @param strata Optional factor or matrix of stratum labels, for example a
#'   land-cover or snow layer, used to report where methods diverge.
#' @return A list with `pairwise` (a data frame of agreement, Jaccard and
#'   commission/omission relative to each other) and, when `strata` is given,
#'   `by_stratum`.
#' @export
cl_disagreement <- function(masks, strata = NULL) {
  M <- lapply(masks, .cs_mask_matrix)
  nms <- names(M) %||% paste0("m", seq_along(M))
  cmb <- utils::combn(seq_along(M), 2L)
  pw <- do.call(rbind, lapply(seq_len(ncol(cmb)), function(k) {
    a <- M[[cmb[1, k]]]; b <- M[[cmb[2, k]]]
    inter <- sum(a & b); uni <- sum(a | b)
    data.frame(method_a = nms[cmb[1, k]], method_b = nms[cmb[2, k]],
               agreement = mean(a == b),
               jaccard = if (uni == 0) NA_real_ else inter / uni,
               a_only = sum(a & !b) / length(a),
               b_only = sum(b & !a) / length(a),
               cloud_a = mean(a), cloud_b = mean(b),
               stringsAsFactors = FALSE)
  }))
  out <- list(pairwise = pw)
  if (!is.null(strata)) {
    st <- as.vector(.cs_as_matrix(strata))
    ag <- cl_agreement(masks)
    out$by_stratum <- do.call(rbind, lapply(sort(unique(st)), function(s) {
      i <- st == s
      data.frame(stratum = s, n = sum(i),
                 mean_agreement = mean(ag$unanimous[i]),
                 mean_entropy = mean(ag$entropy[i]),
                 mean_cloud = mean(ag$agreement[i]), stringsAsFactors = FALSE)
    }))
  }
  out
}

#' Flag conditions where cloud masks are known to be unreliable
#'
#' Returns a per-pixel reliability score. Low values mark surfaces on which
#' every published cloud mask has documented weaknesses, so that a downstream
#' statistic can be reported with an honest caveat rather than an unqualified
#' number.
#'
#' @param bands Named list of reflectance matrices.
#' @param dem Optional elevation matrix, used to flag terrain shadow risk.
#' @param sun_zenith,sun_azimuth Illumination geometry, for terrain shadow.
#' @param res Pixel size in metres.
#' @return A list with `reliability` in \[0, 1\] and named logical `flags`.
#' @export
cl_reliability <- function(bands, dem = NULL, sun_zenith = NULL,
                           sun_azimuth = NULL, res = 30) {
  eps <- 1e-6
  B <- lapply(bands, .cs_as_matrix)
  d <- dim(B[[1L]])
  flags <- list()
  pen <- array(0, d)

  if (all(c("green", "swir16") %in% names(B))) {
    ndsi <- (B$green - B$swir16) / pmax(B$green + B$swir16, eps)
    flags$snow_ice <- ndsi > 0.4
    pen <- pen + 0.45 * flags$snow_ice
  }
  if (all(c("red", "nir", "swir16") %in% names(B))) {
    ndvi <- (B$nir - B$red) / pmax(B$nir + B$red, eps)
    flags$bright_bare <- ndvi < 0.1 & B$swir16 > 0.3
    pen <- pen + 0.25 * flags$bright_bare
  }
  if (all(c("green", "nir") %in% names(B))) {
    ndwi <- (B$green - B$nir) / pmax(B$green + B$nir, eps)
    flags$water_edge <- ndwi > 0 & ndwi < 0.3
    pen <- pen + 0.2 * flags$water_edge
    flags$sun_glint <- ndwi > 0.3 & B$nir > 0.12
    pen <- pen + 0.3 * flags$sun_glint
  }
  if (!is.null(dem) && !is.null(sun_zenith)) {
    ts <- cl_terrain_shadow(dem, sun_zenith, sun_azimuth %||% 180, res = res)
    flags$terrain_shadow <- ts > 0
    pen <- pen + 0.4 * flags$terrain_shadow
  }
  list(reliability = .cs_clamp(1 - pen), flags = flags)
}
