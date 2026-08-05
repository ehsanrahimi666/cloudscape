# ---------------------------------------------------------------------------
# Module 11: processing engine
# ---------------------------------------------------------------------------

#' Plan chunked processing of a large raster
#'
#' Returns row blocks sized to the configured pixel budget. Working in blocks is
#' what allows continental analysis on ordinary hardware; the block size is
#' exposed rather than hidden so that it can be tuned to available memory.
#'
#' @param nrow,ncol Raster dimensions.
#' @param n_layers Number of layers held simultaneously.
#' @param budget Target pixels in memory at once.
#' @return A data frame with `block`, `row_start`, `n_rows`.
#' @export
#' @examples
#' cl_chunk(10000, 10000, n_layers = 8)
cl_chunk <- function(nrow, ncol, n_layers = 1L, budget = NULL) {
  budget <- budget %||% cl_options()$chunk_pixels
  rows_per <- max(1L, floor(budget / (ncol * max(1L, n_layers))))
  starts <- seq(1L, nrow, by = rows_per)
  data.frame(block = seq_along(starts), row_start = starts,
             n_rows = pmin(rows_per, nrow - starts + 1L))
}

#' Apply a function over chunks, optionally in parallel
#'
#' @param x Object passed to `fun` along with each chunk.
#' @param chunks A chunk plan from [cl_chunk()].
#' @param fun Function with signature `(x, row_start, n_rows)`.
#' @param workers Number of workers; 1 runs sequentially.
#' @return A list of results, one per chunk.
#' @export
cl_apply_chunks <- function(x, chunks, fun, workers = NULL) {
  workers <- workers %||% cl_options()$workers
  f <- function(i) fun(x, chunks$row_start[i], chunks$n_rows[i])
  if (workers > 1L && cl_has("future.apply")) {
    return(future.apply::future_lapply(seq_len(nrow(chunks)), f))
  }
  if (workers > 1L) {
    cl_warn("`future.apply` is not installed; running sequentially.")
  }
  lapply(seq_len(nrow(chunks)), f)
}
