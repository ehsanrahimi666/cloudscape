# Describe a quality-assessment band

QA layers come in two flavours: bit-packed (Landsat `QA_PIXEL`) and
categorical (Sentinel-2 `SCL`). `cl_qa_spec()` describes either so that
[`cl_probability`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_probability.md)
with `method = "qa"` can decode any sensor uniformly.

## Usage

``` r
cl_qa_spec(type, asset, bits = NULL, confidence = NULL, classes = NULL,
  clear = NULL)
```

## Arguments

- type:

  `"bitmask"` or `"categorical"`.

- asset:

  Asset name of the QA layer.

- bits:

  Bit positions (0-indexed) of the flags for `type = "bitmask"`: a named
  integer vector of single bits, or a named list whose elements are
  single bits or, for fields of several bits,
  `list(bits = c(lo, hi), values = ...)`, the field values that raise
  the flag. Names should include, where available, `cloud`,
  `cloud_shadow`, `snow`, `cirrus`, `water`, `fill`, `dilated_cloud`.

- confidence:

  Named list of two-bit confidence field positions, e.g.
  `list(cloud = c(8, 9))`, giving low/medium/high gradations.

- classes:

  Named integer vector mapping class labels to codes for
  `type = "categorical"`.

- clear:

  Character vector of the class names of valid, cloud-free pixels for
  `type = "categorical"`. Classes that are neither in `clear` nor cloud,
  cloud-shadow or snow classes are treated as invalid. With `NULL`,
  every class except `no_data` is valid.

## Value

An object of class `cl_qa_spec`.
