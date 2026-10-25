# Common spectral indices

Common spectral indices

## Usage

``` r
cl_indices(bands, which = c("ndvi", "ndsi", "ndwi", "whiteness", "hot"))
```

## Arguments

- bands:

  Named list of reflectance matrices.

- which:

  Indices to compute.

## Value

A named list of matrices.

## Examples

``` r
b <- list(green = matrix(.1,4,4), red = matrix(.08,4,4),
          nir = matrix(.35,4,4), swir16 = matrix(.2,4,4), blue = matrix(.09,4,4))
names(cl_indices(b))
#> [1] "ndvi"      "ndsi"      "ndwi"      "whiteness" "hot"      
```
