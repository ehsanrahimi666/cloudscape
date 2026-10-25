# Convert catalogue items to an observation table

Maps scene footprints onto the equal-area analysis grid and attaches the
scene-level cloud fraction to every intersecting cell. This is tier A:
fast and global, but the cloud fraction is a scene average, so the
resulting clear-observation counts should be read as an optimistic
bound. See
[`cl_clear_prob`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_clear_prob.md).

## Usage

``` r
cl_items_to_obs(items, grid, method = "centroid", overpass_minutes = 20)
```

## Arguments

- items:

  A `cl_items` table.

- grid:

  A `cl_grid`.

- method:

  Footprint indexing method, see
  [`cl_grid_index`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_grid_index.md).

- overpass_minutes:

  Scenes covering the same cell within this many minutes are treated as
  one observation. A sensor tiles a single overpass into several
  products - Sentinel-2 into MGRS tiles, Landsat into consecutive WRS-2
  rows - and every tile covering a cell would otherwise be counted as a
  separate observation of it. In a 100 x 100 km test area this inflated
  Sentinel-2 counts by a factor of 4.6 to 7.9 and Landsat by 1.8, which
  in turn made cloud gaps look shorter and time-series retrieval look
  far easier than it is. Separate orbits on the same day are hours apart
  and remain distinct.

## Value

A `cl_obs` table with tier `"metadata"`, one row per cell per overpass.
Items whose cloud-cover property is missing are excluded with a warning
rather than silently treated as clear.
