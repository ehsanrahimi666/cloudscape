# Package index

## Package overview

- [`cloudscape`](https://ehsanrahimi666.github.io/cloudscape/reference/cloudscape-package.md)
  [`cloudscape-package`](https://ehsanrahimi666.github.io/cloudscape/reference/cloudscape-package.md)
  : cloudscape: Clear-Observation Availability and Cloud Analysis for
  Optical Satellite Image Time Series

## Configuration and sensors

- [`cl_options()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_options.md)
  : Get or set package options
- [`cl_cache_dir()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_cache_dir.md)
  : Locate the cloudscape cache directory
- [`cl_require()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_require.md)
  : Require a suggested package
- [`cl_manifest()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_manifest.md)
  : Create or extract a provenance manifest
- [`cl_sensor_register()`](https://ehsanrahimi666.github.io/cloudscape/reference/sensor-registry.md)
  [`cl_sensor()`](https://ehsanrahimi666.github.io/cloudscape/reference/sensor-registry.md)
  [`cl_sensors()`](https://ehsanrahimi666.github.io/cloudscape/reference/sensor-registry.md)
  : Register, retrieve and list sensor drivers
- [`cl_sensor_driver()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_sensor_driver.md)
  : Construct a sensor driver
- [`cl_qa_spec()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_qa_spec.md)
  : Describe a quality-assessment band

## Analysis grid

- [`cl_grid()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_grid.md)
  : Define an equal-area analysis grid
- [`cl_grid_cells()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_grid_cells.md)
  : Cell identifiers, centroids and areas
- [`cl_grid_index()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_grid_index.md)
  : Index sensor footprints onto the analysis grid
- [`cl_grid_lookup()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_grid_lookup.md)
  : Locate cells from coordinates
- [`cl_project()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_project.md)
  [`cl_unproject()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_project.md)
  : Project longitude/latitude to and from EASE-Grid 2.0 metres

## Catalogue access

- [`cl_catalog()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_catalog.md)
  : Configure or inspect a catalogue backend
- [`cl_search()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_search.md)
  : Search a catalogue for scenes
- [`cl_items_to_obs()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_items_to_obs.md)
  : Convert catalogue items to an observation table

## Data structures

- [`cl_scene()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_scene.md)
  : Construct a scene
- [`cl_cube()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_cube.md)
  : Construct a lazy scene collection
- [`cl_maskset()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_maskset.md)
  : Construct a cloud/shadow mask set
- [`cl_stats()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_stats.md)
  : Construct a grid statistics table
- [`cl_stats_merge()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_stats_merge.md)
  : Combine statistics tables
- [`cl_stats_wide()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_stats_wide.md)
  : Reshape statistics from long to wide
- [`cl_classes()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_classes.md)
  : Standard class coding
- [`cl_metrics()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_metrics.md)
  : The controlled metric vocabulary
- [`validate_cl_stats()`](https://ehsanrahimi666.github.io/cloudscape/reference/validate_cl_stats.md)
  : Validate a statistics table
- [`cl_bands()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_bands.md)
  : Band names present in a scene
- [`cl_band()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_band.md)
  : Extract a band by standardised name

## Preprocessing

- [`cl_scale()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_scale.md)
  : Rescale stored integers to reflectance
- [`cl_geometry()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_geometry.md)
  : Attach or compute scene geometry
- [`cl_solar_position()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_solar_position.md)
  : Solar position for a location and time
- [`cl_indices()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_indices.md)
  : Common spectral indices

## Cloud detection

- [`cl_probability()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_probability.md)
  : Compute cloud probability
- [`cl_methods()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_methods.md)
  : List available cloud-probability methods
- [`cl_method_register()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_method_register.md)
  : Register a cloud-probability method
- [`cl_qa_decode()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_qa_decode.md)
  : Decode a producer quality layer

## Shadow

- [`cl_shadow()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_shadow.md)
  : Detect cloud shadows
- [`cl_shadow_offset()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_shadow_offset.md)
  : Ground displacement of a cloud shadow
- [`cl_shadow_project()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_shadow_project.md)
  : Project a cloud mask to candidate shadow locations
- [`cl_cloud_height()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_cloud_height.md)
  : Estimate cloud-top height from thermal brightness temperature
- [`cl_terrain_shadow()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_terrain_shadow.md)
  : Cast shadow from terrain

## Uncertainty

- [`cl_agreement()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_agreement.md)
  : Agreement among several masks
- [`cl_disagreement()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_disagreement.md)
  : Pairwise disagreement between masks
- [`cl_reliability()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_reliability.md)
  : Flag conditions where cloud masks are known to be unreliable

## Availability and feasibility

- [`cl_obs()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_obs.md)
  : Build an observation table
- [`cl_clear_obs()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_clear_obs.md)
  : Clear observation counts per cell and period
- [`cl_clear_prob()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_clear_prob.md)
  : Probability that a pixel in a cell is clear
- [`cl_gaps()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_gaps.md)
  : Cloud-gap statistics
- [`cl_seasonality()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_seasonality.md)
  : Seasonal clear-sky model
- [`cl_synergy()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_synergy.md)
  : Multi-constellation revisit synergy
- [`cl_feasibility()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_feasibility.md)
  : Sampling design feasibility
- [`cl_persistence()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_persistence.md)
  : Estimate the temporal persistence of cloud from an observation
  record

## Phenology

- [`cl_pheno_curve()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_pheno_curve.md)
  : Double-logistic seasonal trajectory
- [`cl_pheno_fit()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_pheno_fit.md)
  : Fit a seasonal trajectory and extract phenological metrics
- [`cl_pheno_power()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_pheno_power.md)
  : Phenological retrieval error under realistic cloud loss
- [`cl_pheno_map()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_pheno_map.md)
  : Map phenological retrieval error across grid cells

## Simulation and evaluation

- [`cl_simulate()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_simulate.md)
  : Simulate clouds and cloud shadows
- [`cl_simulate_series()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_simulate_series.md)
  : Simulate a contaminated time series
- [`cl_validate()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_validate.md)
  : Accuracy metrics for a binary or multi-class mask
- [`cl_confusion()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_confusion.md)
  : Confusion matrix
- [`cl_roc()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_roc.md)
  : ROC curve and area under it
- [`cl_calibration()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_calibration.md)
  : Probability calibration
- [`cl_compare()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_compare.md)
  : Compare methods with uncertainty
- [`cl_benchmark()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_benchmark.md)
  : Load a benchmark dataset

## Performance, visualisation, export

- [`cl_chunk()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_chunk.md)
  : Plan chunked processing of a large raster
- [`cl_apply_chunks()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_apply_chunks.md)
  : Apply a function over chunks, optionally in parallel
- [`cl_visualize()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_visualize.md)
  : Quick look at a mask or scene
- [`cl_explore()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_explore.md)
  : Export an interactive map of grid statistics
- [`cl_app()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_app.md)
  : Launch the interactive scene explorer
- [`cl_export()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_export.md)
  : Export cloudscape objects
