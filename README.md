# cloudscape

**Cloud, shadow and clear-observation analysis for optical satellite imagery.**

cloudscape answers a question that cloud-masking software usually leaves to the
user: *given the clouds, is my study actually possible here?* It combines
interchangeable cloud-detection algorithms, a geometric shadow-projection
engine, synthetic cloud simulation for benchmarking, and an equal-area
statistics engine that turns archive metadata into decision-relevant measures —
expected clear observations, cloud-gap distributions, best acquisition windows,
multi-constellation revisit, and phenological retrieval uncertainty in days.

## Installation

```r
# install.packages("remotes")
remotes::install_github("ehsanrahimi666/cloudscape")

# Model weights, benchmark subsets and the pre-computed global dataset
# live in a companion package (CRAN limits package size):
install.packages("cloudscape.data", repos = "https://ehsanrahimi666.r-universe.dev")
```

The statistical core depends only on base R. `terra`, `sf` and `httr2` are
suggested and are loaded only when raster or network functionality is used, so
`cloudscape` installs and runs its full test suite without a GDAL toolchain.

## Three things it does that existing tools do not

**1. Equal-area statistics.** WRS-2 scene area varies with latitude and
side-lap grows from ~7% at the equator to >50% near the poles, so any
per-scene statistic is latitude-biased, and Landsat and Sentinel-2 footprints
are not comparable. cloudscape aggregates onto EASE-Grid 2.0, where every cell
has identical true ground area.

```r
g <- cl_grid(res = 25000)
nrow(cl_grid_index(box_at_50N, g))   # 4 cells
nrow(cl_grid_index(box_at_70N, g))   # 2 cells — same degrees, half the ground
```

**2. Units that cannot be mislabelled.** Every statistic carries its unit,
sample size and denominator, validated on construction. A count summed over ten
years and divided by ten is a *per-year* mean, not a per-scene mean; encoding
the denominator makes that confusion a validation error rather than a
published table.

```r
cl_stats(1:2, "cloud_fraction", c(0.3, 1.4))
#> Error: Metric 'cloud_fraction' has value 1.4 outside its permitted range [0, 1]
```

**3. Answers in days, not percentages.** Mean cloud cover does not tell a
phenologist whether green-up is retrievable. `cl_pheno_power()` samples a known
seasonal trajectory only on the dates a cell was actually usable, refits, and
reports the error:

```r
d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
for (p in c(0.2, 0.6, 0.9))
  print(cl_pheno_power(d, cloud_fraction = p, n_sim = 300)$summary)
#> cloud 0.2:  73 usable,  SOS error  1 day,   0% failed
#> cloud 0.6:  29 usable,  SOS error  1 day,   5% failed
#> cloud 0.9:   7 usable,  SOS error  9 days, 68% failed
```

Cloud clustering matters independently of how much cloud there is. At a fixed
70% cloud fraction, raising the lag-1 autocorrelation from 0 to 0.7 leaves the
number of usable observations unchanged (22 vs 21) but triples the fit failure
rate (9% to 28%): clustering does not remove observations, it removes them from
where they matter.

## Quick start

```r
library(cloudscape)

# 1. What can I get here?
grid  <- cl_grid(res = 25000)
items <- cl_search(aoi = c(128.0, 35.5, 129.2, 36.2), sensor = "sentinel-2-msi",
                   start = "2020-01-01", end = "2024-12-31")
obs   <- cl_items_to_obs(items, grid)

cl_clear_obs(obs, by = "year")     # counts, with the tier-A caveat attached
cl_gaps(obs, critical = 30)        # longest stretch without a usable image
cl_seasonality(obs)                # best acquisition window per cell

# 2. How many observations will I get from a constellation?
cl_synergy(c("landsat-8-9-oli", "sentinel-2-msi"), "2015-01-01", "2025-12-31")

# 3. Detect cloud and shadow
mask   <- cl_probability(scene, method = "fmask")
shadow <- cl_shadow(mask$class, nir = nir, swir = swir, bt = bt,
                    sun_zenith = 42, sun_azimuth = 155, res = 30)

# 4. Benchmark methods against known truth
sim <- cl_simulate(512, 512, coverage = 0.3, opacity = c(0.2, 1), seed = 1)
cl_compare(list(fmask = m1$class, threshold = m2$class), sim$cloud)

# 5. Share the result
cl_explore(stats, metric = "n_clear_obs", file = "availability.html")
```

## Sensors

Landsat 4–9, Sentinel-2, MODIS, and a generic driver covering PlanetScope,
WorldView, SPOT, RapidEye and UAV imagery. Adding a sensor means writing one
driver, not editing algorithms:

```r
cl_sensor_register(cl_sensor_driver(
  id = "my-sensor", name = "My camera",
  bands = c(blue = "B1", green = "B2", red = "B3", nir = "B4"),
  revisit = 5))

cl_methods(sensor = "my-sensor")   # which algorithms are applicable
```

## Status

Version 0.1.0. The statistical core, geometry engine, simulator and evaluation
framework are implemented and tested. Learned detectors (`s2cloudless`,
`randomforest`, `xgboost`, `unet`) are registered but require the companion
data package. Integration against live STAC endpoints is exercised on CI, not
in the CRAN test suite.

## Citation

A software paper is in preparation. Until then, cite the repository.
