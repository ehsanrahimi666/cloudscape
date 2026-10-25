# Export an interactive map of grid statistics

Writes a self-contained HTML file showing one metric per grid cell. The
output has no server dependency and no expiring URLs, so it can be
archived alongside a manuscript and will still work years later. Live
imagery browsing is a different problem with different constraints and
belongs in
[`cl_app`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_app.md).

## Usage

``` r
cl_explore(stats, metric, period = NULL, file = "cloudscape.html", grid =
  NULL, palette = c("#2c7bb6", "#ffffbf", "#d7191c"), title = NULL)
```

## Arguments

- stats:

  A `cl_stats` table.

- metric:

  Metric to display.

- period:

  Optional period filter.

- file:

  Output path.

- grid:

  The `cl_grid` the cells refer to; taken from `stats` if absent.

- palette:

  Colour ramp endpoints.

- title:

  Map title.

## Value

The output path, invisibly.
