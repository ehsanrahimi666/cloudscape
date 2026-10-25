# Register, retrieve and list sensor drivers

Register, retrieve and list sensor drivers

## Usage

``` r
cl_sensor_register(driver, overwrite = FALSE)
cl_sensor(id)
cl_sensors()
```

## Arguments

- driver:

  A `cl_sensor` object.

- id:

  Sensor identifier.

- overwrite:

  Replace an existing registration.

## Value

`cl_sensor_register()` returns the id invisibly; `cl_sensor()` returns a
`cl_sensor`; `cl_sensors()` returns a data frame summary.
