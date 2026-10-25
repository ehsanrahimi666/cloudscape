# Standard class coding

cloudscape uses one class vocabulary across all sensors and algorithms
so that masks from Fmask, Sen2Cor SCL, s2cloudless and neural models can
be compared directly.

## Usage

``` r
cl_classes()
```

## Value

A named integer vector.

## Examples

``` r
cl_classes()
#>           fill     clear_land    clear_water     cloud_thin    cloud_thick 
#>              0              1              2              3              4 
#>   cloud_shadow       snow_ice terrain_shadow 
#>              5              6              7 
```
