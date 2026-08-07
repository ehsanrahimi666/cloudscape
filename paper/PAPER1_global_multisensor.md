# Three cloud-masking chains disagree about how cloudy the Earth is becoming: a multi-sensor assessment of optical observation availability, 2013–2025

**Ehsan Rahimi**^1\*^ and **Chuleui Jung**^1,2^

^1^ Agricultural Science and Technology Institute, Gyeongkuk National University, Andong, Republic of Korea
^2^ Department of Plant Medical, Gyeongkuk National University, Andong, Republic of Korea

\* Correspondence: ehsanrahimi666@gmail.com

## ABSTRACT

**Aim**

To determine how much usable optical satellite observation actually exists across the terrestrial surface, how that has changed as the Landsat and Sentinel-2 constellations grew, and whether cloud statistics reported by different processing chains are mutually consistent enough to be combined.

**Location**

Twenty-four terrestrial sites spanning 17 climate regimes from Tierra del Fuego (54.8° S) to Svalbard (78.2° N), each resolved as sixteen 25 km equal-area grid cells (384 cells, 10,000 km² per site), with a supplementary systematic global land sample.

**Time period**

2013–2025, covering the full operational records of Landsat 7, Landsat 8, Landsat 9, Sentinel-2A, Sentinel-2B and Sentinel-2C.

**Major taxa studied**

Not applicable. The measured quantity is the observability of the land surface by optical sensors, with land-surface phenology used as the application through which observability is expressed.

**Methods**

We harvested 291,728 scene records through SpatioTemporal Asset Catalogs and aggregated them onto an equal-area analysis grid (EASE-Grid 2.0, EPSG:6933) rather than onto sensor footprints, so that statistics are comparable across latitude and between missions. Products belonging to a single overpass were collapsed to one observation per cell. From the resulting 724,050 cell-observations we derived usable-observation counts, gap-length distributions, monthly usability, the lag-1 autocorrelation of cloud occurrence expressed as a lag-invariant decorrelation time, and phenological retrieval error simulated from the actual acquisition dates of each cell and year.

**Results**

Cloud persistence and cloud amount are distinct and inversely related: decorrelation time ranged from 13.1 days in tropical wet-dry climates to 0.7 days in the high Arctic and correlated −0.67 with cloud fraction, whereas mean cloudy-run length correlated +0.94 with cloud fraction and is therefore not evidence of clustering. Forty-two per cent of cells carry a seasonal blind spot of two months or more, and annual usability correlated −0.67 with the ratio between the best and worst month, so places that appear adequate annually are systematically those whose gap falls worst. The proportion of cells in which start of season was retrievable rose from 75.5% in 2013 to 100% in 2018. Reported cloud fraction diverged sharply between processing chains applied to identical cells and years: Sentinel-2 (Sen2Cor) +0.0168 yr⁻¹ (p = 0.0027), Landsat 8/9 (CFMask) +0.0020 yr⁻¹ (p = 0.078) and Landsat 7 (CFMask) −0.0049 yr⁻¹ (p = 0.039). Sentinel-2 reported 0.061 more cloud than Landsat on the same cells (95% CI 0.057–0.065, r = 0.834, n = 3,519 cell-years), an offset that varied with cloud amount (p = 8 × 10⁻²⁰) rather than being constant.

**Main conclusions**

Cloud statistics derived from producer metadata are not interchangeable between missions, and the disagreement is growing. Any multi-year trend computed from Sentinel-2 cloud metadata over the last decade contains roughly 0.15 of algorithmic drift, comparable in magnitude to plausible climatic signals. Annual cloud summaries should be replaced by seasonally resolved measures for study planning, because a favourable annual figure is a poor and negatively biased guide to when observations are actually available.

**Keywords**

cloud masking, data availability, equal-area analysis, land surface phenology, Landsat, processing baseline, Sentinel-2, time series

---

## 1 | INTRODUCTION

Optical satellite time series underpin much of what is known about terrestrial change, and cloud is the principal reason they are incomplete. The usual response is to report a cloud percentage — for a scene, a region or a year — and proceed. That number, however, answers a question nobody is really asking. What determines whether a time-series analysis succeeds is not the average fraction of the sky that is obscured but how many usable observations remain, when in the year they fall, and how long the intervals between them become.

The distinction is easy to state and easy to overlook. Two locations with identical annual cloud fractions can differ by an order of magnitude in whether a seasonal transition is observable, because one is cloudy in winter and the other in the growing season. Two sensors reporting different cloud fractions over the same ground on the same day are not necessarily observing different atmospheres; they may simply be running different algorithms. And a constellation that has grown from one satellite to six over a decade does not offer a stationary sampling density, so a trend computed across that decade partly measures the growth of the observing system.

Earlier assessments have quantified availability but have generally done so on the sensor's own footprint. Rahimi and Jung (2024b) compiled Landsat 8 image counts and mean cloud cover for every World Reference System-2 (WRS-2) path and row globally from 2014 to 2023 and distributed the result as shapefiles so that researchers could consult availability before beginning a study. That design, which we follow here in intent, has three limitations we set out to remove. Scene ground area falls with latitude and orbital side-lap grows towards the poles, so per-scene counts confound acquisition density with viewing geometry, most severely where availability is lowest. The same geometry prevents direct comparison with Sentinel-2, whose Military Grid Reference System tiles differ in size and placement. And scene-average cloud cover is a weak proxy for whether a particular location was usable, a point made at pixel scale by Zhang et al. (2022).

Cloud detection itself has a large and mature literature. Decision-cascade methods following Zhu and Woodcock (2012) underpin the operational Landsat quality layers distributed with Collection 2 (Crawford et al., 2023), thermal and cirrus information constrain thin and high cloud (Shen et al., 2015; Qiu et al., 2020), multi-temporal formulations exploit the regularity of clear-sky reflectance (Zhu and Helmer, 2018; Cao et al., 2020), and learned models now dominate published benchmarks (Li et al., 2019), supported by reference datasets of increasing scale (Aybar et al., 2022). Much less attention has been paid to whether the *statistics* these algorithms generate are mutually consistent when they are combined, as they routinely are in harmonised multi-sensor products.

We therefore ask four questions.

1. How is usable observation distributed with latitude and climate, on a unit that is comparable across both?
2. Is cloud persistence a separate property from cloud amount, and if so, does it run with or against it?
3. When did the growth of the constellation make land-surface phenology retrievable, and where is it still marginal?
4. Do the producer cloud statistics of Landsat and Sentinel-2 agree well enough to be combined into a single record?

The fourth turns out to be the consequential one.

## 2 | MATERIALS AND METHODS

All analyses were performed with **cloudscape**, a purpose-built R package released with this work under GPL-3 (Rahimi and Jung, in preparation). Code and the harvested records are available at https://github.com/ehsanrahimi666/cloudscape; every table and figure below is regenerated by a single script in that repository.

### 2.1 | Analysis unit

Statistics were aggregated onto EASE-Grid 2.0 global (EPSG:6933), a cylindrical equal-area projection on the WGS84 ellipsoid with standard parallel 30° (Brodzik et al., 2012, 2014). Every cell has identical true ground area by construction, so counts are comparable across latitude and between sensors with different footprint geometries. We verified the implementation against the WGS84 ellipsoid surface area to a relative error of 4.7 × 10⁻¹¹.

Cell size was 25 km. Each study site comprises a 4 × 4 block of cells (16 cells, 100 × 100 km, 10,000 km²), defined in cells rather than in degrees precisely because a fixed-degree box covers less ground towards the poles and would have reintroduced the bias the grid exists to remove.

### 2.2 | Sites

Twenty-four terrestrial sites were selected to span latitude from 54.8° S to 78.2° N and to represent 17 climate regimes, from hyper-arid through tropical rainforest to high Arctic (Table S1). Sites were chosen rather than sampled at random because the questions concern how availability varies *between* climate regimes, and a random sample of that size would have left several regimes unrepresented.

### 2.3 | Catalogue harvest

Scene metadata were obtained from the Element84 Earth Search SpatioTemporal Asset Catalog, which requires no authentication. Each mission was queried only over its own operational period: Landsat 7 from 2013, Landsat 8/9 from 2013, Sentinel-2 from 2015, all to the end of 2025. Because Element84 serves Landsat 4–7 and Landsat 8–9 from a single collection, queries were additionally filtered by platform so that the two drivers returned disjoint sets.

Each site-sensor-year was fetched in four quarterly windows, with per-page retry and up to four passes separated by escalating waits, because gateway errors under load are common and a query that fails at one moment commonly succeeds minutes later. All 888 site-sensor-years completed: 801 returned data and 87 were legitimately empty (Landsat 7 after the end of its imaging in 2024).

### 2.4 | From scenes to observations

Footprints were mapped to grid cells by centroid containment. Products belonging to a single overpass were then collapsed to one observation per cell. This step is necessary rather than cosmetic: a sensor tiles one overpass into several products — Sentinel-2 into MGRS tiles, Landsat into consecutive WRS-2 rows — and counting each tile that covers a cell as a separate observation of it inflated Sentinel-2 counts and shortened apparent gaps. Products acquired within 20 minutes of one another over the same cell were treated as one observation and their cloud fractions averaged; separate orbits on the same day are hours apart and remained distinct.

The harvest yielded 291,728 scene records and 724,050 cell-observations over 384 cells.

### 2.5 | Evidence tier

All statistics reported here derive from scene-level cloud cover in catalogue metadata, which is a footprint average rather than a measurement for the cell. Converting it to a per-cell usability requires an assumption, and the natural one — that cloud is spatially random within the footprint — is optimistic, because cloud is clustered. Counts of usable observations should therefore be read as upper bounds. We adopt a usability threshold of 0.2 scene cloud fraction throughout.

### 2.6 | Derived measures

**Gaps.** For each cell and year we computed the intervals between consecutive usable observations, including the intervals from 1 January to the first and from the last to 31 December, and report the longest. Cells with no usable observation in a year were retained and assigned a gap equal to the full year; excluding them would have removed exactly the cases of interest.

**Persistence.** Cloud occurrence was modelled as a two-state chain with marginal probability *p* and lag-1 autocorrelation *ρ*, for which *ρ* = *p*₁₁ − *p*₀₁; the estimator is the difference between the empirical probability that a cloudy acquisition is followed by another and that a clear one is. Because the lag is whatever the local acquisition interval happens to be, and orbits converge towards the poles, raw *ρ* is not comparable across latitude. We therefore report the decorrelation time *τ* = −Δ*t* / log *ρ*, the interval over which cloud state ceases to be informative about itself, which is independent of observation frequency.

**Seasonal blind spots.** For each cell we computed the probability that an acquisition is usable in each calendar month, and identified the longest run of consecutive months (treated circularly) below 0.15.

**Phenological feasibility.** A double-logistic reference trajectory was sampled only on the dates a cell was actually usable in a given year, observation noise added, the curve refitted, and the retrieval error recorded across replicates. We report the median absolute error of start of season and the fraction of replicates in which the fit failed to converge. To test whether a retrieval is supported by data or by the assumed shape, the same observations were also fitted with a spline and the two compared.

## 3 | RESULTS

### 3.1 | Observation density and its latitudinal structure

Combined acquisition density averaged 130 per cell-year across the record, rising from 45.8 in 2013 to a plateau above 190 after 2018 (Figure 1, Figure 7). Density increases towards the poles because orbits converge: Sentinel-2 delivered 369.5 acquisitions per cell-year above 75° N against 76.5 in the 0–15° band (Table 1). That gain does not translate proportionally into usable data, because the high-latitude bands are also the cloudiest: cloud fraction reached 0.678 above 75° N for Sentinel-2 against 0.241 in the 15–30° band.

The consequence is that usable observations are distributed far more evenly than acquisitions. Landsat 8/9 delivered 26.9 usable observations per cell-year in the 15–30° band from 37.8 acquisitions, and 17.3 above 75° N from 144.1 acquisitions — a fourfold difference in acquisitions producing a modest difference in usable data.

**Table 1.** Acquisitions, usable observations and mean cloud fraction per equal-area cell-year, by latitude band and sensor. Usability threshold 0.2 scene cloud fraction.

| Latitude band | Sensor | Cell-years | Acquisitions | Usable | Cloud fraction |
|---|---|---|---|---|---|
| 75–90° N | Sentinel-2 | 128 | 369.5 | 36.7 | 0.678 |
| 60–75° N | Sentinel-2 | 447 | 125.4 | 26.5 | 0.585 |
| 45–60° N | Sentinel-2 | 440 | 112.9 | 22.1 | 0.599 |
| 30–45° N | Sentinel-2 | 344 | 100.7 | 54.2 | 0.313 |
| 15–30° N | Sentinel-2 | 288 | 90.2 | 61.5 | 0.241 |
| 0–15° N | Sentinel-2 | 432 | 76.5 | 19.5 | 0.537 |
| 15–0° S | Sentinel-2 | 432 | 75.3 | 22.1 | 0.471 |
| 30–15° S | Sentinel-2 | 288 | 77.2 | 44.6 | 0.286 |
| 45–30° S | Sentinel-2 | 432 | 108.2 | 48.2 | 0.391 |
| 60–45° S | Sentinel-2 | 288 | 114.7 | 23.7 | 0.562 |
| 75–90° N | Landsat 8/9 | 208 | 144.1 | 17.3 | 0.631 |
| 60–75° N | Landsat 8/9 | 624 | 55.0 | 14.3 | 0.550 |
| 45–60° N | Landsat 8/9 | 572 | 47.4 | 10.0 | 0.557 |
| 30–45° N | Landsat 8/9 | 468 | 36.4 | 21.8 | 0.259 |
| 15–30° N | Landsat 8/9 | 416 | 37.8 | 26.9 | 0.208 |
| 0–15° N | Landsat 8/9 | 624 | 33.0 | 12.0 | 0.419 |
| 15–0° S | Landsat 8/9 | 624 | 34.7 | 13.2 | 0.393 |
| 30–15° S | Landsat 8/9 | 416 | 36.3 | 24.1 | 0.245 |
| 45–30° S | Landsat 8/9 | 624 | 41.6 | 17.7 | 0.357 |
| 60–45° S | Landsat 8/9 | 416 | 44.0 | 7.6 | 0.587 |

Gap lengths follow the same structure but more sharply (Figure 2). The median longest annual gap exceeded 90 days in six of seventeen regimes and reached 119.5 days in the high Arctic and 119.0 days in subpolar oceanic climates, with ninetieth percentiles of 151 and 237 days respectively (Table 2).

**Table 2.** Usable observations and longest annual gap by climate regime, ordered by median gap. Median across cell-years.

| Regime | Cell-years | Usable obs. | Median longest gap (d) | 90th percentile (d) |
|---|---|---|---|---|
| High Arctic | 208 | 26.0 | 119.5 | 151 |
| Subpolar oceanic | 208 | 6.0 | 119.0 | 237 |
| Tropical wet-dry | 208 | 55.0 | 96.0 | 130 |
| Tropical rainforest | 416 | 16.0 | 92.0 | 162 |
| Tropical monsoon | 416 | 18.0 | 91.0 | 174 |
| Arctic tundra | 208 | 34.5 | 90.0 | 149 |
| Subarctic | 208 | 30.0 | 74.0 | 118 |
| Humid continental | 208 | 31.0 | 66.0 | 115 |

### 3.2 | Cloud persistence is a separate axis from cloud amount

Decorrelation time varied by a factor of nineteen across climate regimes, from 13.1 days in tropical wet-dry climates to 0.7 days in the high Arctic (Figure 3, Table 3). Its ordering is not the ordering of cloud amount. Across regimes, *τ* correlated **−0.67** with cloud fraction: the cloudiest places are among the *least* persistently cloudy, because high-latitude cloud fields advect quickly and are resampled by converging orbits within a day.

Mean cloudy-run length behaves in exactly the opposite way, correlating **+0.94** with cloud fraction. This matters because run length is the intuitive measure of clustering and is sometimes used as one. It is not: a cell that is cloudy 94% of the time has long cloudy runs whatever its autocorrelation, because the marginal alone produces them. Reporting run length as evidence of clustering is circular, and the two panels of Figure 3 are included to make that explicit.

**Table 3.** Cloud persistence by climate regime. *ρ* is the lag-1 autocorrelation of cloud occurrence at the local acquisition interval; *τ* is the lag-invariant decorrelation time.

| Regime | Cells | \|lat\| | Cloud fraction | *ρ* | Lag (d) | *τ* (d) | Mean run |
|---|---|---|---|---|---|---|---|
| Tropical wet-dry | 32 | 16.7 | 0.48 | 0.244 | 3.0 | 13.10 | 4.62 |
| Tropical savanna | 96 | 15.9 | 0.34 | 0.213 | 2.0 | 7.72 | 2.19 |
| Hot semi-arid | 48 | 27.9 | 0.31 | 0.132 | 1.5 | 6.34 | 1.96 |
| Hot desert margin | 48 | 30.8 | 0.36 | 0.166 | 2.0 | 5.82 | 1.98 |
| Tropical monsoon | 96 | 8.7 | 0.59 | 0.185 | 2.0 | 5.62 | 2.94 |
| Tropical rainforest | 96 | 1.8 | 0.78 | 0.130 | 2.0 | 5.36 | 5.99 |
| Mediterranean | 48 | 32.1 | 0.35 | 0.147 | 2.0 | 4.63 | 1.83 |
| Cold semi-arid | 96 | 41.4 | 0.47 | 0.156 | 2.0 | 4.50 | 2.71 |
| Hyper-arid | 96 | 24.8 | 0.16 | 0.070 | 1.0 | 4.12 | 1.40 |
| Subarctic continental | 48 | 60.5 | 0.60 | 0.121 | 1.0 | 3.24 | 3.53 |
| Humid subtropical | 96 | 32.2 | 0.58 | 0.163 | 1.5 | 2.72 | 2.85 |
| Humid continental | 48 | 42.5 | 0.60 | 0.164 | 1.0 | 2.68 | 2.87 |
| Arctic tundra | 48 | 70.1 | 0.79 | 0.180 | 1.0 | 2.60 | 6.11 |
| Subpolar oceanic | 48 | 54.8 | 0.90 | 0.155 | 1.0 | 2.44 | 9.87 |
| Temperate oceanic | 96 | 48.5 | 0.77 | 0.152 | 1.0 | 2.01 | 5.85 |
| Subarctic | 48 | 62.1 | 0.80 | 0.128 | 1.0 | 1.96 | 6.79 |
| High Arctic | 48 | 78.2 | 0.93 | 0.088 | 1.0 | 0.74 | 22.27 |

### 3.3 | Seasonal blind spots, and why annual figures conceal them

Forty-two per cent of cells (139 of 328 with a complete monthly record) carry a blind spot of two consecutive months or longer in which fewer than 15% of acquisitions are usable. The median ratio between the best and worst month was 3.8-fold.

The important result is not the existence of blind spots but their relationship to annual statistics. Annual usability correlated **−0.67** with the seasonal ratio (Figure 12): the places that look adequate on an annual summary are systematically those whose observations are most concentrated into part of the year.

Tropical wet-dry climates illustrate this most sharply. Their annual usability of 0.512 is among the highest of any regime and would be judged unproblematic by any conventional screening. Yet their worst month, July, has a usability of 0.026, and they carry a three-month blind spot that falls across peak biomass (Table 4, Figure 11). A study of growing-season dynamics sited on that basis would find the archive blind precisely when the canopy is active.

**Table 4.** Seasonal blind spots by climate regime, ordered by blind-spot length. The seasonal ratio is best month to worst month, with the denominator floored at 0.01 to avoid dividing by sampling noise.

| Regime | Cells | Annual usable | Worst month | Worst month usable | Seasonal ratio | Blind months |
|---|---|---|---|---|---|---|
| Subpolar oceanic | 16 | 0.058 | December | 0.002 | 16.2 | 11.0 |
| Tropical rainforest | 32 | 0.164 | August | 0.038 | 8.9 | 6.5 |
| Tropical monsoon | 32 | 0.196 | May | 0.038 | 12.5 | 6.0 |
| Humid continental | 16 | 0.189 | December | 0.018 | 17.9 | 5.0 |
| Subarctic | 8 | 0.183 | January | 0.030 | 9.3 | 4.0 |
| **Tropical wet-dry** | **16** | **0.512** | **July** | **0.026** | **36.1** | **3.0** |
| Temperate oceanic | 32 | 0.202 | November | 0.111 | 2.3 | 2.0 |
| Tropical savanna | 32 | 0.515 | February | 0.186 | 4.4 | 0.0 |
| Hot semi-arid | 16 | 0.615 | August | 0.202 | 4.3 | 0.0 |
| Cold semi-arid | 32 | 0.414 | February | 0.215 | 3.3 | 0.0 |
| Hot desert margin | 16 | 0.674 | February | 0.434 | 2.2 | 0.0 |
| Humid subtropical | 32 | 0.432 | June | 0.309 | 2.0 | 0.0 |
| Mediterranean | 16 | 0.638 | June | 0.503 | 1.7 | 0.0 |
| Hyper-arid | 32 | 0.853 | July | 0.747 | 1.3 | 0.0 |

### 3.4 | When phenology became retrievable

Simulating start-of-season retrieval from the actual acquisition dates of each cell and year shows a clear transition (Figure 8, Table 5). In 2013, with Landsat 7 and Landsat 8 only, the median cell had 29 usable observations and start of season was retrievable within our criterion in 75.5% of cells. Usable observations rose to 62 by 2017 and to 102 in 2018, when Sentinel-2B reached full operations, and the proportion of retrievable cells reached 100% and remained there.

Regimes differ in when they crossed. Thirteen of seventeen were already retrievable in 2013; tropical monsoon crossed in 2015, subpolar oceanic and tropical rainforest in 2017, and the high Arctic in 2018 (Table S2). No regime failed to cross.

**Table 5.** Phenological feasibility by year. Usable observations and start-of-season error are medians across 384 cells; the final column is the proportion of cells meeting the criterion of ≤5 days error and ≤10% fit failure.

| Year | Usable obs. | SOS error (d) | Fit failure | Cells retrievable |
|---|---|---|---|---|
| 2013 | 29.0 | 1.05 | 0.078 | 75.5% |
| 2014 | 33.0 | 1.00 | 0.064 | 81.5% |
| 2015 | 36.0 | 0.80 | 0.038 | 86.5% |
| 2016 | 37.0 | 0.85 | 0.048 | 82.8% |
| 2017 | 62.0 | 0.70 | 0.015 | 95.8% |
| **2018** | **102.2** | **0.50** | **0.001** | **100.0%** |
| 2019 | 104.0 | 0.50 | 0.002 | 99.7% |
| 2020 | 103.5 | 0.50 | 0.004 | 99.7% |
| 2021 | 105.5 | 0.50 | 0.001 | 100.0% |
| 2022 | 116.5 | 0.50 | 0.001 | 100.0% |
| 2023 | 111.8 | 0.50 | 0.000 | 100.0% |
| 2024 | 99.2 | 0.50 | 0.001 | 100.0% |
| 2025 | 105.8 | 0.50 | 0.001 | 100.0% |

This result requires an important qualification, developed in Section 3.6: retrieval was performed with a parametric double-logistic curve, whose assumed shape can bridge a seasonal gap that the data do not cover.

### 3.5 | Three processing chains disagree, and increasingly

On identical cells and years, Sentinel-2 reported a mean cloud fraction 0.061 higher than Landsat (95% CI 0.057–0.065; r = 0.834; n = 3,519 cell-years; Figure 4). The correlation is high, so the two chains agree about *where* it is cloudy. They do not agree about how much.

The offset is not a constant that could simply be subtracted. Regressed on mean cloud amount, absolute latitude and year, it decreased by 0.096 per unit of cloud fraction (p = 8 × 10⁻²⁰), showed no latitude dependence (p = 0.396), and increased by 0.0115 per year (p = 9 × 10⁻⁶⁵). Binned by cloud amount (Figure 9), the offset is largest at low to moderate cloud and reverses sign in the cloudiest bin.

The temporal behaviour is the more consequential finding (Figure 10, Table 6). Fitting reported cloud fraction against year separately for each chain, restricted to years with adequate sampling, gives three different answers on the same ground:

**Table 6.** Trend in reported mean cloud fraction per year, by processing chain, on identical cells. Years with fewer than a quarter of that sensor's median sample were excluded; this removed Sentinel-2 2016, before global Level-2A production, and Landsat 7 2024, at the end of its imaging.

| Sensor | Processing chain | Years | Period | Trend (yr⁻¹) | *p* |
|---|---|---|---|---|---|
| Landsat 4–7 | CFMask | 11 | 2013–2023 | **−0.00494** | 0.039 |
| Landsat 8/9 | CFMask | 13 | 2013–2025 | +0.00198 | 0.078 |
| Sentinel-2 | Sen2Cor | 9 | 2017–2025 | **+0.01679** | 0.003 |

Sentinel-2 reports cloud increasing more than eight times faster than Landsat 8/9, and in the opposite direction to Landsat 7. Over the nine adequately sampled years this amounts to approximately 0.15 in cloud fraction. These three series describe the same cells over the same period. They cannot all be measuring the atmosphere.

The most parsimonious explanation is that the Sen2Cor scene classification changed across processing baselines during the period, and that reported cloud cover inherited those changes. We cannot demonstrate this directly from metadata alone, and note it as the leading hypothesis rather than a demonstrated mechanism.

### 3.6 | How much of a phenological retrieval is data, and how much is assumption?

Fitting the same usable observations with a parametric double logistic and with a spline gives a median disagreement of 2.2 days in start of season but **9.4 days in the timing of peak** (Figure 13). Disagreement increased with blind-spot length (Spearman 0.38).

The interpretation is direct. A double logistic can bridge a seasonal gap because its shape is assumed rather than observed; a spline cannot. Where the two agree, the retrieval is supported by the archive. Where they diverge, it is supported by the model. Start of season, which in most of our sites falls outside the blind spot, is comparatively robust. Peak timing, which frequently falls inside it, is not.

## 4 | DISCUSSION

### 4.1 | Cloud statistics are not interchangeable between missions

The clearest practical result of this work is that producer cloud statistics from Landsat and Sentinel-2 should not be pooled without correction, and that the correction is not a constant. The two chains agree about the spatial pattern (r = 0.834) and disagree about the level, by an amount that depends on how cloudy it is and that has grown steadily over the record.

The implication for harmonised multi-sensor products is uncomfortable. A decadal trend in cloudiness computed from Sentinel-2 metadata over 2017–2025 carries roughly 0.15 of drift that Landsat, processed differently over the same ground, does not show. That magnitude is comparable to plausible climatic signals, so a study designed to detect one could recover the other. We do not claim that Sen2Cor is wrong and CFMask right; we claim that they differ, that the difference is not stable, and that this is a property of the algorithms rather than of the sky.

This extends rather than contradicts previous cross-sensor work. Holden and Woodcock (2016) showed with underflight data that reflectance discrepancies between Landsat 7 and Landsat 8 must be reconciled before observations are treated as substitutable, and Xu et al. (2022) found that performance differences between PROBA-V, Landsat 8 and Sentinel-2 in land-cover change monitoring were driven substantially by differences in data availability. Our result is the cloud-statistic analogue: the availability itself is reported inconsistently.

### 4.2 | Persistence and amount are different questions

That decorrelation time runs opposite to cloud amount is, on reflection, physically reasonable. High-latitude cloud is frequent but mobile, and converging orbits resample the same ground within a day, so the state observed today carries little information about tomorrow. Seasonal tropical cloud is less frequent in the annual mean but organised into multi-week regimes, so it persists.

The practical consequence is that the two must be measured separately, and that the intuitive proxy is misleading. Mean cloudy-run length correlates 0.94 with cloud amount and therefore mostly restates it. Any assessment of clustering that uses run length is close to circular, and the lag-invariant decorrelation time we adopt here is, to our knowledge, the first such measure computed from archive metadata at global scope.

### 4.3 | Annual summaries should be replaced for study planning

The negative correlation between annual usability and seasonal concentration (−0.67) means an annual figure is not merely uninformative about timing; it is misleading in a systematic direction. Tropical wet-dry sites, with 51% annual usability, carry a three-month blind spot over peak growing season.

We therefore suggest that studies reporting land-surface phenology, crop mapping or any seasonally targeted retrieval report the usable-observation count, the longest gap and the monthly usability profile alongside their estimates, and that a favourable annual cloud statistic should not be treated as evidence that a site is suitable.

### 4.4 | Feasibility is recent, and the shape assumption is doing work

The transition to universal retrievability in 2018 places a bound on retrospective phenological analysis: before that date a quarter of our cells did not support a defensible start-of-season estimate, and time series that extend back to 2013 have non-stationary retrieval quality that is rarely acknowledged.

The parametric-versus-spline comparison qualifies this. A 9.4-day median disagreement in peak timing, increasing with blind-spot length, means that peak-related metrics from single-sensor optical records in monsoonal climates are substantially model-determined. Where the assumed shape is defensible this is legitimate inference; where it is not, it is an artefact that no accuracy statistic computed against the same fitted curve would reveal.

### 4.5 | Limitations

All results derive from **scene-level metadata**, not pixel measurements. Usable-observation counts are therefore upper bounds, and the difference between them and pixel-scale counts (Zhang et al., 2022) is itself informative but not quantified here.

**The sample is 24 sites.** Several regimes rest on a single location, so regime-level values should be read as indicative. The supplementary global land sample extends spatial coverage but at one year and coarse spacing.

**Cross-sensor comparison compares algorithms and sampling jointly.** Sentinel-2 and Landsat do not observe at the same time of day or the same viewing geometry, and part of the offset may reflect diurnal cloud development rather than algorithm alone. Disentangling these would require coincident acquisitions, which are rare.

**The reprocessing hypothesis is not demonstrated.** We show that three chains diverge; attributing that to specific baseline transitions requires reprocessing history that metadata does not carry.

**Phenological simulation assumes a double-logistic seasonality.** Sites with multiple growing seasons or evergreen canopies are not well represented, and the errors reported are lower bounds on real retrieval error, which additionally includes atmospheric residual, bidirectional reflectance effects and geolocation error.

## 5 | CONCLUSIONS

Optical observation of the land surface is far more abundant than it was a decade ago, and by 2018 the Landsat–Sentinel-2 constellation had made start-of-season retrieval possible at every site we examined. But abundance is not the whole story. Forty-two per cent of cells carry a multi-month seasonal blind spot, and annual cloud statistics conceal them in a systematically misleading direction. Cloud persistence is a distinct property from cloud amount and runs opposite to it, so the cloudiest places are not the most persistently cloudy.

Most importantly, the cloud statistics that describe all of this are not consistent between missions. On identical cells over the same years, Sen2Cor reports cloud increasing at more than eight times the rate CFMask does on Landsat 8/9, and in the opposite direction to CFMask on Landsat 7. Combining these records without accounting for that difference will produce trends that are partly algorithmic. We suggest that any multi-sensor cloud or availability analysis report each chain separately before combining them, and that the divergence documented here be treated as a floor on the uncertainty of harmonised products.

## DATA AND CODE AVAILABILITY

The **cloudscape** R package, all analysis scripts and the harvested records are at https://github.com/ehsanrahimi666/cloudscape under GPL-3. Every table and figure is regenerated by `paper/make-figures.R` from the harvested CSVs.

## AUTHOR CONTRIBUTIONS

**ER**: Conceptualisation, Methodology, Software, Validation, Formal analysis, Writing — original draft. **CJ**: Conceptualisation, Supervision, Funding acquisition, Writing — review and editing.

## CONFLICT OF INTEREST

The authors declare no conflict of interest.

## REFERENCES

Aybar, C., Ysuhuaylas, L., Loja, J., Gonzales, K., Herrera, F., Bautista, L., Yali, R., Flores, A., Diaz, L., Cuenca, N., Espinoza, W., Prudencio, F., Llactayo, V., Montero, D., Sudmanns, M., Tiede, D., Mateo-García, G., & Gómez-Chova, L. (2022). CloudSEN12, a global dataset for semantic understanding of cloud and cloud shadow in Sentinel-2. *Scientific Data*, 9, 782. https://doi.org/10.1038/s41597-022-01878-2

Brodzik, M. J., Billingsley, B., Haran, T., Raup, B., & Savoie, M. H. (2012). EASE-Grid 2.0: Incremental but significant improvements for Earth-gridded data sets. *ISPRS International Journal of Geo-Information*, 1(1), 32–45. https://doi.org/10.3390/ijgi1010032

Brodzik, M. J., Billingsley, B., Haran, T., Raup, B., & Savoie, M. H. (2014). Correction: EASE-Grid 2.0. *ISPRS International Journal of Geo-Information*, 3(3), 1154–1156. https://doi.org/10.3390/ijgi3031154

Cao, R., Chen, Y., Chen, J., Zhu, X., & Shen, M. (2020). Thick cloud removal in Landsat images based on autoregression of Landsat time-series data. *Remote Sensing of Environment*, 249, 112001. https://doi.org/10.1016/j.rse.2020.112001

Crawford, C. J., Roy, D. P., Arab, S., Barnes, C., Vermote, E., Hulley, G., et al. (2023). The 50-year Landsat collection 2 archive. *Science of Remote Sensing*, 8, 100103. https://doi.org/10.1016/j.srs.2023.100103

Holden, C. E., & Woodcock, C. E. (2016). An analysis of Landsat 7 and Landsat 8 underflight data and the implications for time series investigations. *Remote Sensing of Environment*, 185, 16–36. https://doi.org/10.1016/j.rse.2016.02.052

Li, Z., Shen, H., Cheng, Q., Liu, Y., You, S., & He, Z. (2019). Deep learning based cloud detection for medium and high resolution remote sensing images of different sensors. *ISPRS Journal of Photogrammetry and Remote Sensing*, 150, 197–212. https://doi.org/10.1016/j.isprsjprs.2019.02.017

Qiu, S., Zhu, Z., & Woodcock, C. E. (2020). Cirrus clouds that adversely affect Landsat 8 images: What are they and how to detect them? *Remote Sensing of Environment*, 246, 111884. https://doi.org/10.1016/j.rse.2020.111884

Rahimi, E., & Jung, C. (2024b). Evaluating the applicability of Landsat 8 data for global time series analysis. *Frontiers in Remote Sensing*, 5, 1492534. https://doi.org/10.3389/frsen.2024.1492534

Shen, Y., Wang, Y., Lv, H., & Li, H. (2015). Removal of thin clouds using cirrus and QA bands of Landsat-8. *Photogrammetric Engineering & Remote Sensing*, 81(9), 721–731. https://doi.org/10.14358/pers.81.9.721

Whitcraft, A. K., Vermote, E. F., Becker-Reshef, I., & Justice, C. O. (2015). Cloud cover throughout the agricultural growing season: Impacts on passive optical Earth observations. *Remote Sensing of Environment*, 156, 438–447. https://doi.org/10.1016/j.rse.2014.10.009

Xu, L., Herold, M., Tsendbazar, N.-E., Masiliūnas, D., Li, L., Lesiv, M., et al. (2022). Time series analysis for global land cover change monitoring: A comparison across sensors. *Remote Sensing of Environment*, 271, 112905. https://doi.org/10.1016/j.rse.2022.112905

Zhang, Y., Woodcock, C. E., Arévalo, P., Olofsson, P., Tang, X., Stanimirova, R., et al. (2022). A global analysis of the spatial and temporal variability of useable Landsat observations at the pixel scale. *Frontiers in Remote Sensing*, 3, 894618. https://doi.org/10.3389/frsen.2022.894618

Zhu, X., & Helmer, E. H. (2018). An automatic method for screening clouds and cloud shadows in optical satellite image time series in cloudy regions. *Remote Sensing of Environment*, 214, 135–153. https://doi.org/10.1016/j.rse.2018.05.024

Zhu, Z., & Woodcock, C. E. (2012). Object-based cloud and cloud shadow detection in Landsat imagery. *Remote Sensing of Environment*, 118, 83–94. https://doi.org/10.1016/j.rse.2011.10.028

---

## FIGURE CAPTIONS

**Figure 1.** Acquisition density against latitude. Each point is one cell-year; the line is a locally weighted regression and the dashed line the nominal constellation expectation of 192 acquisitions per year. Density rises steeply above 70° N as orbits converge.

**Figure 2.** Cloud amount (left) and the longest annual gap without a usable observation (right) against latitude. Red lines are locally weighted regressions.

**Figure 3.** Cloud persistence. Upper: decorrelation time by climate regime. Lower left: mean cloudy-run length against cloud fraction, Spearman +0.94 — run length restates cloud amount. Lower right: decorrelation time against cloud fraction, Spearman −0.67 — persistence runs opposite to amount.

**Figure 4.** Sentinel-2 against Landsat cloud fraction on identical cells and years (left), and the distribution of their difference (right). The chains agree about pattern (r = 0.834) but not level.

**Figure 5.** Start-of-season error and fit-failure rate against the number of usable observations per year.

**Figure 6.** Day of year of clearest conditions against latitude.

**Figure 7.** Measured acquisition density, measured usable observations and the nominal constellation model, 2013–2025.

**Figure 8.** Usable observations per year (left) and the proportion of cells in which start of season is retrievable (right). The transition to universal retrievability occurs in 2018.

**Figure 9.** Sentinel-2 minus Landsat cloud fraction, binned by mean cloud amount, with 95% confidence intervals. The offset is largest at low to moderate cloud and reverses in the cloudiest bin.

**Figure 10.** Mean reported cloud fraction by year for three processing chains on identical cells. Error bars are ±2 standard errors. Years with fewer than a quarter of that sensor's median sample are omitted.

**Figure 11.** Probability that an acquisition is usable, by climate regime and calendar month. Crosses mark months below 0.15.

**Figure 12.** The ratio between the best and worst month against annual usability. Spearman −0.50 across cells (−0.67 across regimes): sites that appear adequate annually are systematically those whose observations are most seasonally concentrated.

**Figure 13.** Peak timing from a parametric double logistic against a spline fitted to the same observations. Median disagreement 9.4 days.

**Figure 14.** Global land sample. Mean reported cloud fraction per sensor (a–c), usable observations per sensor (d–f), combined acquisition and usable density (g–h), and the Sentinel-2 minus Landsat difference on identical points (i).
