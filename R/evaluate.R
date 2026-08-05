# ---------------------------------------------------------------------------
# Module 10: evaluation
#
# Two things that are usually missing from cloud-mask comparisons and are
# treated as first-class here:
#
#   1. Uncertainty on the metrics. Two methods differing by 0.4 percent overall
#      accuracy on one scene are not distinguishable. cl_compare() reports
#      paired tests and bootstrap intervals rather than a bare ranking.
#   2. Calibration. A method that outputs probabilities should be judged on
#      whether those probabilities mean anything, not only on accuracy after
#      thresholding. Reliability, Brier score and expected calibration error
#      are reported alongside discrimination.
# ---------------------------------------------------------------------------

#' Confusion matrix
#'
#' @param pred Predicted class codes or logical mask.
#' @param truth Reference class codes or logical mask.
#' @param levels Optional class levels; defaults to the union observed.
#' @param labels Optional class labels.
#' @return A table with predictions in rows and reference in columns.
#' @export
cl_confusion <- function(pred, truth, levels = NULL, labels = NULL) {
  p <- as.vector(.cs_as_matrix(pred)); t <- as.vector(.cs_as_matrix(truth))
  cl_assert(length(p) == length(t), "`pred` and `truth` must be the same length.")
  keep <- !is.na(p) & !is.na(t)
  p <- p[keep]; t <- t[keep]
  if (is.null(levels)) levels <- sort(unique(c(p, t)))
  tab <- table(pred = factor(p, levels = levels, labels = labels %||% levels),
               truth = factor(t, levels = levels, labels = labels %||% levels))
  tab
}

#' Accuracy metrics for a binary or multi-class mask
#'
#' @param pred Predicted mask.
#' @param truth Reference mask.
#' @param positive For binary input, the value treated as the positive class.
#' @param levels Optional class levels for multi-class input.
#' @return A data frame of per-class precision, recall, F1 and IoU plus overall
#'   and balanced accuracy, with an attribute `confusion`.
#' @export
#' @examples
#' set.seed(1)
#' truth <- matrix(rbinom(400, 1, 0.3), 20, 20)
#' pred  <- truth; pred[sample(400, 40)] <- 1 - pred[sample(400, 40)]
#' cl_validate(pred, truth)
cl_validate <- function(pred, truth, positive = 1, levels = NULL) {
  tab <- cl_confusion(pred, truth, levels = levels)
  lv <- rownames(tab)
  n <- sum(tab)
  per <- do.call(rbind, lapply(seq_along(lv), function(i) {
    tp <- tab[i, i]
    fp <- sum(tab[i, ]) - tp
    fn <- sum(tab[, i]) - tp
    tn <- n - tp - fp - fn
    prec <- if ((tp + fp) == 0) NA_real_ else tp / (tp + fp)
    rec  <- if ((tp + fn) == 0) NA_real_ else tp / (tp + fn)
    f1   <- if (is.na(prec) || is.na(rec) || (prec + rec) == 0) NA_real_ else
      2 * prec * rec / (prec + rec)
    iou  <- if ((tp + fp + fn) == 0) NA_real_ else tp / (tp + fp + fn)
    spec <- if ((tn + fp) == 0) NA_real_ else tn / (tn + fp)
    data.frame(class = lv[i], n_truth = sum(tab[, i]), n_pred = sum(tab[i, ]),
               precision = prec, recall = rec, specificity = spec,
               f1 = f1, iou = iou, stringsAsFactors = FALSE)
  }))
  oa <- sum(diag(tab)) / n
  ba <- mean(per$recall, na.rm = TRUE)
  # Matthews correlation for the binary case
  mcc <- NA_real_
  if (length(lv) == 2L) {
    i <- match(as.character(positive), lv)
    if (!is.na(i)) {
      j <- 3L - i
      tp <- tab[i, i]; tn <- tab[j, j]; fp <- tab[i, j]; fn <- tab[j, i]
      den <- sqrt(prod(c(tp + fp, tp + fn, tn + fp, tn + fn)))
      mcc <- if (den == 0) NA_real_ else (tp * tn - fp * fn) / den
    }
  }
  attr(per, "confusion") <- tab
  attr(per, "overall") <- c(n = n, overall_accuracy = oa,
                            balanced_accuracy = ba, mcc = mcc)
  class(per) <- c("cl_validation", "data.frame")
  per
}

#' @export
print.cl_validation <- function(x, ...) {
  ov <- attr(x, "overall")
  cat("<cl_validation>", format(ov[["n"]], big.mark = ","), "pixels\n")
  cat("  overall accuracy :", round(ov[["overall_accuracy"]], 4), "\n")
  cat("  balanced accuracy:", round(ov[["balanced_accuracy"]], 4), "\n")
  if (!is.na(ov[["mcc"]])) cat("  MCC              :", round(ov[["mcc"]], 4), "\n")
  print(as.data.frame(x), row.names = FALSE, digits = 4)
  invisible(x)
}

#' ROC curve and area under it
#'
#' @param prob Predicted probabilities in \[0, 1\].
#' @param truth Binary reference (1 = positive).
#' @param n_thresh Number of thresholds to evaluate.
#' @return A data frame of `threshold`, `fpr`, `tpr`, `precision`, with an `auc`
#'   attribute.
#' @export
#' @examples
#' set.seed(2)
#' truth <- rbinom(500, 1, 0.4)
#' prob  <- pmin(pmax(truth * 0.6 + runif(500) * 0.5, 0), 1)
#' attr(cl_roc(prob, truth), "auc")
cl_roc <- function(prob, truth, n_thresh = 101) {
  p <- as.vector(.cs_as_matrix(prob)); y <- as.vector(.cs_as_matrix(truth)) > 0
  keep <- !is.na(p) & !is.na(y); p <- p[keep]; y <- y[keep]
  th <- seq(0, 1, length.out = n_thresh)
  res <- do.call(rbind, lapply(th, function(t) {
    hit <- p >= t
    tp <- sum(hit & y); fp <- sum(hit & !y)
    fn <- sum(!hit & y); tn <- sum(!hit & !y)
    data.frame(threshold = t,
               fpr = if ((fp + tn) == 0) NA_real_ else fp / (fp + tn),
               tpr = if ((tp + fn) == 0) NA_real_ else tp / (tp + fn),
               precision = if ((tp + fp) == 0) NA_real_ else tp / (tp + fp))
  }))
  # Trapezoidal AUC over increasing FPR
  o <- order(res$fpr, res$tpr)
  x <- res$fpr[o]; yv <- res$tpr[o]
  ok <- !is.na(x) & !is.na(yv)
  auc <- if (sum(ok) < 2L) NA_real_ else
    sum(diff(x[ok]) * (utils::head(yv[ok], -1) + utils::tail(yv[ok], -1)) / 2)
  attr(res, "auc") <- auc
  res
}

#' Probability calibration
#'
#' A detector can discriminate well and still be badly calibrated, in which case
#' its probabilities cannot be used to weight observations or propagate
#' uncertainty. This reports the reliability curve together with the Brier score
#' and expected calibration error.
#'
#' @param prob Predicted probabilities.
#' @param truth Binary reference.
#' @param bins Number of probability bins.
#' @return A data frame with one row per bin, with `brier` and `ece` attributes.
#' @export
cl_calibration <- function(prob, truth, bins = 10L) {
  p <- as.vector(.cs_as_matrix(prob)); y <- as.vector(.cs_as_matrix(truth)) > 0
  keep <- !is.na(p) & !is.na(y); p <- p[keep]; y <- y[keep]
  br <- seq(0, 1, length.out = bins + 1L)
  idx <- pmin(bins, pmax(1L, findInterval(p, br, rightmost.closed = TRUE)))
  out <- do.call(rbind, lapply(seq_len(bins), function(b) {
    i <- idx == b
    data.frame(bin = b, lower = br[b], upper = br[b + 1L], n = sum(i),
               mean_pred = if (any(i)) mean(p[i]) else NA_real_,
               observed = if (any(i)) mean(y[i]) else NA_real_)
  }))
  attr(out, "brier") <- mean((p - as.numeric(y))^2)
  attr(out, "ece") <- sum(out$n / length(p) *
                            abs(out$mean_pred - out$observed), na.rm = TRUE)
  out
}

#' Compare methods with uncertainty
#'
#' Paired comparison of two or more masks against a common reference. Reports
#' bootstrap confidence intervals on overall accuracy for each method, and
#' McNemar's test for each pair, so that a difference is only claimed when the
#' paired evidence supports it.
#'
#' @param preds Named list of predicted masks.
#' @param truth Reference mask.
#' @param n_boot Bootstrap replicates.
#' @param conf Confidence level.
#' @param block Optional integer vector of block ids for a block bootstrap.
#'   Cloud masks are spatially autocorrelated, so a pixel-wise bootstrap
#'   understates uncertainty; supplying tile ids gives an honest interval.
#' @return A list with `summary` (per-method accuracy and interval) and
#'   `pairwise` (McNemar statistics and p-values).
#' @export
#' @examples
#' set.seed(3)
#' truth <- matrix(rbinom(1000, 1, .35), 25, 40)
#' a <- truth; a[sample(1000, 60)] <- 1 - a[sample(1000, 60)]
#' b <- truth; b[sample(1000, 120)] <- 1 - b[sample(1000, 120)]
#' cl_compare(list(good = a, worse = b), truth, n_boot = 200)$summary
cl_compare <- function(preds, truth, n_boot = 500L, conf = 0.95, block = NULL) {
  cl_assert(is.list(preds) && length(preds) >= 1L,
            "`preds` must be a named list of masks.")
  y <- as.vector(.cs_as_matrix(truth))
  P <- lapply(preds, function(p) as.vector(.cs_as_matrix(p)))
  cl_assert(all(vapply(P, length, integer(1)) == length(y)),
            "All predictions must match the reference in length.")
  correct <- lapply(P, function(p) p == y)
  n <- length(y)
  blocks <- if (is.null(block)) seq_len(n) else as.integer(block)
  ub <- unique(blocks)

  a <- 1 - conf
  summ <- do.call(rbind, lapply(names(correct), function(nm) {
    cc <- correct[[nm]]
    bs <- vapply(seq_len(n_boot), function(i) {
      sel <- sample(ub, length(ub), replace = TRUE)
      mean(cc[blocks %in% sel])
    }, numeric(1))
    data.frame(method = nm, accuracy = mean(cc),
               lower = stats::quantile(bs, a / 2, names = FALSE),
               upper = stats::quantile(bs, 1 - a / 2, names = FALSE),
               stringsAsFactors = FALSE)
  }))

  pw <- NULL
  if (length(correct) >= 2L) {
    cmb <- utils::combn(names(correct), 2L)
    pw <- do.call(rbind, lapply(seq_len(ncol(cmb)), function(k) {
      i <- correct[[cmb[1, k]]]; j <- correct[[cmb[2, k]]]
      b <- sum(i & !j); c <- sum(!i & j)
      stat <- if ((b + c) == 0) NA_real_ else (abs(b - c) - 1)^2 / (b + c)
      data.frame(method_a = cmb[1, k], method_b = cmb[2, k],
                 a_only_correct = b, b_only_correct = c,
                 mcnemar_chi2 = stat,
                 p_value = if (is.na(stat)) NA_real_ else
                   stats::pchisq(stat, 1, lower.tail = FALSE),
                 stringsAsFactors = FALSE)
    }))
  }
  list(summary = summ[order(-summ$accuracy), ], pairwise = pw,
       n_boot = n_boot, blocked = !is.null(block))
}

#' Load a benchmark dataset
#'
#' Benchmark imagery is too large to ship on CRAN and is therefore distributed
#' through the companion data package. This function resolves the request,
#' checks the cache, and gives an actionable message rather than failing
#' obscurely when the data are absent.
#'
#' @param dataset One of `"cloudsen12"`, `"kappaset"`, `"biome"`, `"synthetic"`.
#' @param n Number of patches to return.
#' @param cache Cache directory.
#' @return For `"synthetic"`, a list of simulated scenes generated on the fly.
#'   For the others, the cached dataset if present, otherwise an informative
#'   error.
#' @export
cl_benchmark <- function(dataset = c("synthetic", "cloudsen12", "kappaset", "biome"),
                         n = 20L, cache = cl_cache_dir()) {
  dataset <- match.arg(dataset)
  if (dataset == "synthetic") {
    return(lapply(seq_len(n), function(i) {
      cl_simulate(128, 128,
                  coverage = stats::runif(1, 0.05, 0.7),
                  size = stats::runif(1, 0.05, 0.35),
                  opacity = c(0.15, 1),
                  sun_zenith = stats::runif(1, 20, 70),
                  sun_azimuth = stats::runif(1, 0, 360),
                  height = stats::runif(1, 500, 8000),
                  seed = i)
    }))
  }
  path <- file.path(cache, "benchmarks", dataset)
  if (!dir.exists(path)) {
    cl_abort(
      "Benchmark '", dataset, "' is not cached.\n",
      "  It ships in the companion data package, which is kept separate ",
      "because CRAN limits package size.\n",
      "  install.packages(\"cloudscape.data\", repos = ",
      "\"https://ehsanrahimi666.r-universe.dev\")\n",
      "  Expected location: ", path
    )
  }
  readRDS(file.path(path, "index.rds"))
}
