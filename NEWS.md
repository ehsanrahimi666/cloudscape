# cloudscape 0.1.0

First development release.

* Equal-area analysis grid (EASE-Grid 2.0, EPSG:6933) with a closed-form
  ellipsoidal projection that requires no PROJ installation.
* Sensor driver registry: Landsat 4-9, Sentinel-2, MODIS, generic/UAV.
* Pluggable cloud-probability methods: `threshold`, `fmask`, `qa`, plus
  registered stubs for learned methods.
* Geometric cloud-shadow projection with cloud-height search, thermal height
  estimation, and explicit separation of terrain shadow from cloud shadow.
* Synthetic cloud and shadow simulation sharing the detector's geometry kernel.
* Availability statistics: clear observations, gap distributions, seasonality,
  multi-constellation synergy, sampling feasibility.
* Phenological retrieval-error simulation.
* Evaluation with bootstrap intervals, McNemar tests and calibration metrics.
* `cl_stats` enforces units, sample sizes and denominators on construction.
