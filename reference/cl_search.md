# Search a catalogue for scenes

Queries a STAC API and returns a normalised item table.
Provider-specific property names are translated to a common vocabulary
so that downstream code never branches on the backend.

## Usage

``` r
cl_search(aoi, sensor, start, end, max_cloud = 100, limit = 500, backend =
  NULL, retries = 3L, extra = list())
```

## Arguments

- aoi:

  Area of interest: a numeric bounding box `c(xmin, ymin, xmax, ymax)`
  in degrees, or an `sf` object.

- sensor:

  Sensor id or alias.

- start:

  Date range.

- end:

  Date range.

- max_cloud:

  Maximum scene cloud cover in percent.

- limit:

  Maximum items to return; `Inf` fetches all pages.

- backend:

  Catalogue backend.

- retries:

  Number of attempts per HTTP request before giving up. Retries are
  applied to each page individually, with exponential backoff and
  respect for any `Retry-After` header. This matters more than it
  sounds: a large query spans many pages, and retrying the whole query
  after a failure on the last page discards every page already fetched
  and hits the service harder each time.

- extra:

  Additional STAC query fields.

## Value

A data frame of class `cl_items` with columns `id`, `datetime`,
`sensor`, `platform`, `cloud_cover`, `path_row` or `tile`,
`geometry_bbox` and `assets`.
