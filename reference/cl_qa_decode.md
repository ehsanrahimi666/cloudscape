# Decode a producer quality layer

Translates a bit-packed or categorical QA band into the standard class
vocabulary of
[`cl_classes`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_classes.md),
using the sensor driver's specification.

## Usage

``` r
cl_qa_decode(qa, sensor, include_cirrus = TRUE, confidence = "medium")
```

## Arguments

- qa:

  QA matrix or `SpatRaster`.

- sensor:

  Sensor id or driver.

- include_cirrus:

  Treat flagged cirrus as cloud.

- confidence:

  Minimum confidence level (`"low"`, `"medium"`, `"high"`) for
  bit-packed QA with confidence fields.

## Value

A list of logical matrices: `cloud`, `shadow`, `snow`, `water`, `fill`,
plus `class` in the standard vocabulary.
