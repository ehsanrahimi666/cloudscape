# Decode a producer quality layer

Translates a bit-packed or categorical QA band into the standard class
vocabulary of
[`cl_classes`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_classes.md),
using the sensor driver's specification.

For bit-packed layers, each flag is either a single bit or a field of
several bits with the values that raise it (see
[`cl_qa_spec`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_qa_spec.md));
flags the specification does not define are never raised. For
categorical layers, pixels whose code is neither a cloud, cloud-shadow
or snow class nor listed in the specification's `clear` set are invalid
and reported as `fill`. For Sentinel-2 `SCL` this marks no-data and
saturated or defective pixels (classes 0 and 1) as invalid, and counts
topographic cast shadow (class 2), vegetation, bare soil, water and
unclassified pixels (classes 4 to 7) as valid and cloud-free. Missing
values are invalid for both types.

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

  Treat flagged cirrus as cloud. Ignored for sensors whose QA has no
  cirrus flag.

- confidence:

  Minimum cloud confidence (`"medium"` or `"high"`) for bit-packed QA
  with confidence fields. Pixels at or above it are cloud, in addition
  to those with the cloud bit set. The lowest level is not offered
  because the Landsat Collection 2 algorithm assigns it to almost all
  clear pixels.

## Value

A list of logical matrices: `cloud`, `shadow`, `snow`, `water`, `fill`,
plus `class` in the standard vocabulary.
