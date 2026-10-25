# Apply a function over chunks, optionally in parallel

Apply a function over chunks, optionally in parallel

## Usage

``` r
cl_apply_chunks(x, chunks, fun, workers = NULL)
```

## Arguments

- x:

  Object passed to `fun` along with each chunk.

- chunks:

  A chunk plan from
  [`cl_chunk`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_chunk.md).

- fun:

  Function with signature `(x, row_start, n_rows)`.

- workers:

  Number of workers; 1 runs sequentially.

## Value

A list of results, one per chunk.
