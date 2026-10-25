# Ground displacement of a cloud shadow

For a cloud top at height `height` above the surface, illuminated with
solar zenith angle `sun_zenith` and solar azimuth `sun_azimuth`, the
shadow falls at a horizontal distance `height * tan(sun_zenith)` in the
direction the sunlight travels, that is, `sun_azimuth + 180` degrees.

A second, smaller displacement arises because the satellite does not
view the cloud from nadir: an elevated cloud is imaged away from the
ground point it actually sits above. Landsat's field of view is narrow
enough that this is often neglected, but across a Sentinel-2 swath it
reaches roughly 0.19 times the cloud height and is worth correcting.

## Usage

``` r
cl_shadow_offset(height, sun_zenith, sun_azimuth, view_zenith = 0,
  view_azimuth = 0, correct_parallax = TRUE)
```

## Arguments

- height:

  Cloud-top height above the surface, in metres.

- sun_zenith:

  Solar zenith angle in degrees (0 = overhead).

- sun_azimuth:

  Solar azimuth in degrees clockwise from north, giving the compass
  direction *of* the sun.

- view_zenith:

  Sensor viewing geometry in degrees. Defaults assume nadir viewing.

- view_azimuth:

  Sensor viewing geometry in degrees. Defaults assume nadir viewing.

- correct_parallax:

  Apply the viewing-geometry correction.

## Value

A matrix with columns `dx` (metres east) and `dy` (metres north), giving
the offset from the observed cloud position to the shadow position.

## Examples

``` r
# Sun due south at 45 degrees zenith: a 1 km cloud casts a 1 km shadow north
cl_shadow_offset(1000, sun_zenith = 45, sun_azimuth = 180)
#>                 dx   dy
#> [1,] -1.224647e-13 1000

# Sun in the east: shadow falls to the west
cl_shadow_offset(1000, sun_zenith = 45, sun_azimuth = 90)
#>         dx            dy
#> [1,] -1000 -6.123234e-14
```
