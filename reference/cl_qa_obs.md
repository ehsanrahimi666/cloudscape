# Build a quality-layer observation table

Reads each scene's producer quality layer (Landsat `QA_PIXEL`,
Sentinel-2 `SCL`) over the requested grid cells and records, for every
cell-observation, the share of valid pixels flagged as cloud, cloud
shadow and snow. Scene-level cloud cover is an average over a footprint
of 10,000 km2 or more and says little about a particular cell; this
table measures the cell itself. It is the `"qa"` evidence tier and can
be passed to every function that accepts a `cl_obs` table.

A scene contributes to the cells whose centroid lies within its
footprint, as in
[`cl_items_to_obs`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_items_to_obs.md).
Pixels are classified with
[`cl_qa_decode`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_qa_decode.md);
a pixel flagged as both cloud and shadow counts as cloud. Tiles acquired
within `overpass_minutes` of each other are one observation of a cell,
and the tile with the most valid pixels in the cell is kept. Landsat
assets that the catalogue lists in the requester-pays USGS bucket are
read from the Planetary Computer mirror with an anonymous access token.

## Usage

``` r
cl_qa_obs(items, grid, cells, include_cirrus = TRUE, confidence = "medium",
  overpass_minutes = 20, workers = 1L)
```

## Arguments

- items:

  Scenes from
  [`cl_search`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_search.md).

- grid:

  A grid from
  [`cl_grid`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_grid.md).

- cells:

  Cell identifiers to evaluate.

- include_cirrus:

  Passed to
  [`cl_qa_decode`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_qa_decode.md).

- confidence:

  Passed to
  [`cl_qa_decode`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_qa_decode.md).

- overpass_minutes:

  Tiles acquired within this many minutes are one overpass.

- workers:

  Scenes read in parallel by forked processes; forced to 1 on Windows.

## Value

A `cl_obs` table of tier `"qa"`. `cloud_fraction`, `shadow_fraction` and
`snow_fraction` are shares of the valid pixels in the cell;
`valid_fraction` is the share of the cell with valid data, `n_valid` the
number of valid pixels and `id` the scene kept. Cell-observations
without valid pixels are dropped. Attribute `"failed"` holds the
identifiers of scenes that could not be read.
