# Locate the cloudscape cache directory

Downloaded assets, resumable harvest state and companion datasets are
stored here. The location follows, in order of precedence: the
`cache_dir` option, the `CLOUDSCAPE_CACHE` environment variable, then a
user-level cache path.

## Usage

``` r
cl_cache_dir(create = TRUE)
```

## Arguments

- create:

  Create the directory if it does not exist.

## Value

Absolute path to the cache directory.
