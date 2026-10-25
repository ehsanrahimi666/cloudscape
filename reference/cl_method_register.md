# Register a cloud-probability method

Register a cloud-probability method

## Usage

``` r
cl_method_register(name, fun, requires, optional = character(), type =
  "physical", reference = NA_character_, overwrite = FALSE)
```

## Arguments

- name:

  Method name.

- fun:

  Function with signature `(bands, geom, drv, ...)` returning a numeric
  matrix of probabilities in \\0, 1\\.

- requires:

  Standardised band names the method needs.

- optional:

  Bands the method uses if present.

- type:

  `"physical"`, `"statistical"` or `"learned"`.

- reference:

  Short citation.

- overwrite:

  Replace an existing registration.

## Value

The method name, invisibly.
