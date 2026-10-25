# Load a benchmark dataset

`"synthetic"` scenes are simulated on the fly. The other datasets are
read from the cache directory; this version of cloudscape does not
distribute them, and when they are absent the function stops with a
message giving the expected location.

## Usage

``` r
cl_benchmark(dataset = c("synthetic", "cloudsen12", "kappaset", "biome"), n
  = 20L, cache = cl_cache_dir())
```

## Arguments

- dataset:

  One of `"cloudsen12"`, `"kappaset"`, `"biome"`, `"synthetic"`.

- n:

  Number of patches to return.

- cache:

  Cache directory.

## Value

For `"synthetic"`, a list of simulated scenes generated on the fly. For
the others, the cached dataset if present, otherwise an informative
error.
