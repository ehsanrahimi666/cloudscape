# cloudscape: an R framework for translating cloud statistics into the feasibility of optical satellite time-series analysis

**Ehsan Rahimi**^1\*^ and **Chuleui Jung**^1,2^

^1^ Agricultural Science and Technology Institute, Gyeongkuk National University, Andong, Republic of Korea
^2^ Department of Plant Medical, Gyeongkuk National University, Andong, Republic of Korea

\* Correspondence: ehsanrahimi666@gmail.com

---

## Abstract

Cloud contamination is the principal constraint on optical satellite time-series analysis, yet the software available to researchers answers a narrower question than the one they usually have. Cloud-masking tools identify contaminated pixels; what an ecologist, agronomist or phenologist needs to know before committing to a study is whether enough usable observations will remain, when they will fall, and how large the resulting error in a derived quantity will be. We present **cloudscape**, an R package that closes this gap. It makes three methodological contributions. First, statistics are aggregated onto an equal-area analysis grid rather than onto sensor footprints, removing a latitude bias that is largest precisely where data availability is lowest, and making Landsat and Sentinel-2 directly comparable. Second, the evidence tier of every statistic is explicit: scene-level catalogue metadata yields an upper bound on usable observations, and the package states this rather than leaving it implicit. Third, observation loss is propagated into the units in which conclusions are actually stated, returning phenological retrieval error in days and a retrieval failure rate alongside it. The package provides interchangeable cloud-probability algorithms behind one interface, a geometric cloud-shadow projection engine that shares its kernel with a synthetic cloud simulator, and a statistics class that validates units, sample sizes and denominators on construction. Validation against analytical identities and controlled simulation shows the equal-area projection reproduces the WGS84 ellipsoid surface area to a relative error of 4.7 × 10⁻¹¹, shadow displacement matches the *h*·tan(*θ*) identity to below 10⁻⁸ m, and cloud-top height is recovered exactly in 36 of 36 configurations when the analysis window spans the displacement. We further show that cloud clustering degrades phenological retrieval independently of cloud amount: at a fixed 70 % cloud fraction, raising the lag-1 autocorrelation of observation loss from 0 to 0.7 changes the number of usable observations by under 5 % but raises the fit failure rate from 10.5 % to 29.0 %. Feasibility assessments that assume independent cloud loss are therefore systematically optimistic. cloudscape is released under GPL-3 at https://github.com/ehsanrahimi666/cloudscape.

**Keywords:** cloud detection; cloud shadow; data availability; equal-area grid; land surface phenology; Landsat; Sentinel-2; reproducible research; R package; SpatioTemporal Asset Catalog

---

## 1. Introduction

Detecting and describing change over time is the first step in identifying its causes, and satellite remote sensing has long been the principal tool for doing so at regional to global scales (Verbesselt et al., 2010; Orusa et al., 2023a). Continuous Earth observation time series underpin work on vegetation dynamics, land-cover change, crop monitoring and land-surface phenology. The reliability of any such analysis, however, depends on the length of the series, its temporal and spatial resolution, and the quality of the observations that compose it (Forkel et al., 2013; Huang et al., 2021).

For optical sensors, the dominant threat to that reliability is cloud. Clouds and their shadows obscure the surface, break time series into irregular fragments, and do so with strong spatial and seasonal structure (Hu et al., 2019; Jain et al., 2013). Using MODIS observations from Terra and Aqua, King et al. (2013) estimated a global cloud fraction near 67 %, with land averaging about 55 % and a pronounced seasonal cycle. Whitcraft et al. (2015a) showed that the cloudiest part of the year over many agricultural regions coincides with the early-to-mid growing season, the period when observations are most valuable. The problem is therefore not merely that data are lost, but that they are lost non-randomly, and preferentially when they matter.

Two distinct constraints follow, and they are often conflated. The first is **availability**: how many acquisitions exist for a location. The second is **usability**: how many of those acquisitions are actually clear enough to use. Landsat, the longest-running moderate-resolution programme, revisits a given path/row every 16 days, but weather and operational factors reduce the realised count (Tolnai et al., 2016; Rahimi et al., 2022). Landsat 8, launched in February 2013 with the Operational Land Imager and Thermal Infrared Sensor, improved radiometric resolution, added a cirrus band at 1370 ± 10 nm for thin-cloud detection, and increased daily acquisition capacity relative to its predecessors (Roy et al., 2014; Loveland and Irons, 2016; Shen et al., 2015). Sentinel-2 added a second constellation with a shorter revisit. Yet the joint question — given the acquisitions that exist and the clouds that fall on them, is a given analysis possible here? — remains one that researchers answer informally, if at all.

The software landscape reflects this. A large literature addresses cloud *detection*, and mature implementations exist in several languages (Section 2). Comparatively little addresses cloud *consequences* in a form a study designer can act on. Rahimi and Jung (2024b) took a step in this direction by compiling Landsat 8 image counts and mean cloud cover for every World Reference System-2 (WRS-2) path and row globally from 2014 to 2023, distributing the result as shapefiles so that researchers could consult availability before beginning a study. That work exposed three methodological issues that motivate the present paper.

First, the WRS-2 path/row is not a sound unit for spatial statistics. Scene ground area falls with latitude and orbital side-lap grows from roughly 7 % at the equator to more than 50 % near the poles, so per-scene counts confound acquisition density with viewing geometry — and do so most severely at high latitudes, exactly where availability is lowest and the conclusion most consequential. The same problem prevents direct comparison with Sentinel-2, whose Military Grid Reference System (MGRS) tiles have a different geometry.

Second, scene-average cloud cover is a weak proxy for usability. A scene reported as 50 % cloudy is far more often half-covered by a single cloud deck than uniformly half-obscured, so the probability that a *particular* location is clear is not 1 − *f*. Zhang et al. (2022) demonstrated the pixel-scale analysis that this argument implies, quantifying the spatial and temporal variability of useable Landsat observations directly.

Third, and most importantly, a cloud percentage is not an answer. A phenologist told that a site averages 42 % cloud cover cannot determine whether green-up will be retrievable there. That determination requires knowing when the clear observations fall relative to the phenological transition, how long the gaps are, and what error the resulting sampling induces.

We therefore developed **cloudscape**, an R package built around a single organising idea: *cloud statistics should be reported in the units in which decisions are made*. The package contributes:

1. **An equal-area analysis grid** as the internal statistical unit, removing the latitude bias of footprint-based counting and making sensors comparable (Section 3.3).
2. **Explicit evidence tiers**, so that a statistic derived from catalogue metadata is labelled as the upper bound it is, with a clustered alternative available (Section 3.5).
3. **A shared shadow-geometry kernel** used in both directions — inverted by the detector, applied forwards by the simulator — so that synthetic benchmarks cannot reward a detector for a geometry the simulator itself got wrong (Section 3.6).
4. **Propagation into decision units**, converting acquisition patterns into phenological retrieval error in days together with a retrieval failure rate (Section 3.9).
5. **Structural enforcement of units**, with every statistic carrying a validated unit, sample size, denominator and combination rule (Section 3.8).

We describe the design, validate each component against analytical identities or controlled simulation, and report a result of independent interest: temporal clustering of cloud degrades phenological retrieval largely independently of cloud amount.

---

## 2. Background and related work

### 2.1 Families of cloud-detection algorithm

Cloud-detection methods fall into recognisable families, each with characteristic assumptions, strengths and computational profiles.

**Threshold and spectral-index methods** exploit the fact that clouds are bright and spectrally flat across the visible range. Simple brightness and whiteness tests are inexpensive and require only visible bands, making them the only option for four-band sensors such as most unmanned aerial vehicle (UAV) cameras and some commercial constellations. Their weakness is well known: bright bare soil, snow, sand and building roofs are also bright and comparatively flat, producing systematic commission errors over exactly the surfaces where cloud statistics are most often needed.

**Decision-cascade methods** combine multiple physically motivated tests. The Function of Mask (Fmask) algorithm is the reference implementation of this family, combining brightness, whiteness, a haze-optimised transform, near-infrared to shortwave-infrared ratios, normalised difference vegetation and snow indices, and thermal information into a sequence of conjunctive tests, followed by a geometric cloud-shadow projection (Zhu and Woodcock, 2012). Subsequent revisions extended it to Sentinel-2 and improved cirrus handling. The operational US Geological Survey (USGS) implementation, CFMask, populates the `QA_PIXEL` band of Landsat Collection 2 (Foga et al., 2017; Crawford et al., 2023). The family's strength is interpretability and the absence of training data; its weakness is that thresholds are globally fixed and therefore perform unevenly across biomes, and that thermal-dependent components degrade or vanish on sensors without a thermal band.

**Thermal approaches** exploit the temperature contrast between cloud tops and the surface, and additionally permit cloud-top height retrieval via an assumed lapse rate, which constrains shadow projection. They fail where thermal contrast collapses — over snow, ice and at night — and are unavailable on Sentinel-2, PlanetScope, RapidEye and most UAV payloads.

**Cirrus-band methods** exploit strong water-vapour absorption near 1.38 µm, where the surface signal is extinguished and only high thin cloud is visible. Landsat 8 band 9 and Sentinel-2 band 10 are designed for this purpose (Shen et al., 2015). Qiu et al. (2020) developed a dedicated cirrus mask (Cmask) using time series of the Landsat 8 cirrus band, reporting an error rate of 8 % in distinguishing cirrus from clear observations against 15 % for prior methods. Cirrus detection is diagnostic when present but does not address low or mid-level cloud.

**Temporal and multi-temporal approaches** treat cloud as an anomaly against an expected surface trajectory. Because clear-sky reflectance varies smoothly and seasonally while cloud does not, deviation from a fitted temporal model is informative. Zhu and Helmer (2018) introduced Automatic Time-Series Analysis (ATSA), a five-step procedure combining cloud and shadow indices, unsupervised initial classification, refinement using the time series of the cloud index, geometric shadow estimation, and refinement of the shadow mask, validated across Landsat-8 OLI, Landsat-4 MSS and Sentinel-2. Cao et al. (2020) exploited autocorrelation in Landsat time series for thick-cloud removal (AutoRegression to Remove Clouds), explicitly handling the case where genuine land-cover change would otherwise corrupt the autocorrelation structure. Multi-temporal methods are powerful but require a sufficiently dense archive — a circularity that matters here, since the regions where availability is lowest are precisely those where temporal methods are least applicable.

**Machine-learning and deep-learning approaches** learn the decision boundary from labelled data. Gradient-boosted trees underpin `s2cloudless`, a widely used per-pixel Sentinel-2 cloud probability product. Convolutional architectures, particularly U-Net variants, now dominate published benchmarks; Li et al. (2019) demonstrated deep-learning cloud detection across sensors of differing resolution. These methods achieve the best reported accuracies but carry three practical costs: dependence on labelled data whose geographic distribution constrains generalisation, model weights too large to distribute through conventional package channels, and reduced interpretability when a mask must be defended in a scientific argument.

**Probabilistic and object-based methods** return continuous cloud probability or operate on segmented objects rather than pixels, improving edge behaviour and enabling downstream uncertainty propagation. **Physical and radiative-transfer approaches** invert an atmospheric model and are the most principled but the most computationally demanding, and are typically embedded within atmospheric-correction chains rather than exposed as standalone masks.

A recurring finding across comparative studies is that published masks disagree with one another considerably more than any of them disagrees with its own validation set. This is a consequence of validation sets being drawn from scenes that are convenient to label rather than from the surfaces where masks fail: snow and ice, bright bare soil, sun glint, coastal water and thin cirrus edges.

### 2.2 Operational products and processing chains

**CFMask / Landsat Collection 2.** The USGS distributes per-pixel quality assessment as bit-packed `QA_PIXEL` layers, with confidence gradations for cloud, cloud shadow, snow and cirrus. Collection 2 improved geolocation and radiometric calibration relative to Collection 1 (Crawford et al., 2023). Crucially for time-series work, the cloud algorithm differs between collections, so statistics computed on the same nominal scenes differ between reprocessing generations.

**Sen2Cor and the Sentinel-2 Scene Classification Layer.** Sen2Cor performs atmospheric correction and produces a categorical scene classification (SCL) distinguishing cloud at medium and high probability, cirrus, cloud shadow, snow, water, vegetation and bare soil. Its behaviour has changed across processing baselines, meaning SCL-derived statistics are not homogeneous through time — a point that any decadal analysis must confront.

**MAJA** takes a multi-temporal approach to cloud screening and atmospheric correction, using the previous clear observation of the same site as a reference. Comparative validation of MAJA, Sen2Cor and Fmask against expertly generated reference masks has become a standard benchmark exercise.

**LaSRC** provides the Landsat 8 surface reflectance algorithm and includes aerosol and cloud handling. **FORCE** provides an end-to-end Landsat and Sentinel-2 processing framework including cloud and shadow masking, compositing and time-series analysis.

**Google Earth Engine** hosts these products at planetary scale and has become the default environment for large-area availability studies (Zhao et al., 2022; Viani et al., 2024). Its convenience is considerable, but it introduces dependencies that matter for reproducibility: interactive authentication, a proprietary backend, and computation that cannot be reproduced offline or archived alongside a manuscript.

### 2.3 Benchmark datasets

Progress on cloud detection has been limited less by algorithms than by reference data. CloudSEN12 (Aybar et al., 2022) addressed this directly, providing 49,400 Sentinel-2 image patches distributed across all continents except Antarctica, with hand-crafted annotations for thick cloud, thin cloud and cloud shadow, auxiliary layers, and the outputs of eight state-of-the-art detection algorithms. Its design deliberately samples across cloud-cover strata, from cloud-free to greater than 65 % cover. The authors subsequently documented incorrect annotations in existing cloud segmentation datasets, underlining the difficulty of the labelling task itself, and released an expanded version. Cloud shadow remains the weakest-labelled class across all such datasets, which is why simulation-based evaluation (Section 3.7) is complementary rather than redundant.

### 2.4 Software ecosystems in R and Python

The R geospatial ecosystem provides strong foundations — `terra` for raster computation and `sf` for vector data — and several packages address satellite data access, including `rgee` for Google Earth Engine (Aybar et al., 2020), `sen2r` for Sentinel-2 processing, `rstac` for SpatioTemporal Asset Catalog (STAC) queries and `gdalcubes` for on-demand data cubes. Python offers comparable and in places deeper coverage, including direct implementations of `s2cloudless` and Fmask.

What is missing in both ecosystems is not another cloud mask but a layer above the masks: a consistent interface across detection algorithms, an unbiased spatial unit for aggregating their outputs, and machinery for converting the result into a statement about study feasibility. Multi-sensor comparison studies illustrate the need — Xu et al. (2022) compared PROBA-V, Landsat 8 OLI and Sentinel-2 MSI for land-cover change monitoring over four years of global reference data, finding that performance differences among sensors were consistent and driven substantially by differences in data availability rather than by spectral capability alone. Holden and Woodcock (2016) similarly showed, using Landsat 7 and Landsat 8 underflight data, that discrepancies between sensors must be reconciled before observations can be treated as substitutable within a long-term archive.

### 2.5 Studies of observation availability

A smaller literature addresses availability directly. Tolnai et al. (2016) mapped the spatiotemporal distribution of Landsat imagery over Europe using cloud-cover-weighted metadata. Whitcraft et al. (2015b) evaluated the combined revisit capability of current and planned moderate-resolution missions against agricultural monitoring requirements, concluding that no single observatory could deliver the required frequency of sufficiently clear views and that a multi-mission constellation approach was necessary. Zhang et al. (2022) provided the pixel-scale global analysis of useable Landsat observations. Rahimi and Jung (2024b) provided per-path/row image counts and mean cloud cover globally for Landsat 8.

These studies establish where and when observations are scarce. None provides software that lets a researcher pose the inverse question for their own site, sensor combination and target variable — which is the gap cloudscape addresses.

---

## 3. Design and implementation

### 3.1 Design principles

Four principles governed the design.

**P1 — The spatial unit must be unbiased.** Sensor footprints are import geometries, not analysis units.

**P2 — Evidence tiers must be explicit.** A statistic derived from scene metadata is not the same as one derived from pixels, and the software should not allow the difference to be forgotten.

**P3 — Units belong in the data structure.** Denominator confusion is a silent failure mode in aggregate statistics; it should be a validation error, not a published table.

**P4 — The core must be installable without a geospatial toolchain.** The statistical machinery is arithmetic on tables; requiring GDAL to run it excludes users unnecessarily and makes continuous integration fragile.

### 3.2 Architecture

The package comprises 16 modules organised into five layers, with the rule that a lower layer never calls into a higher one (Table 1). The constraint is enforced mechanically by a static call-graph analyser that is executed as part of the test suite, rather than being documented and hoped for.

**Table 1.** Module layers. A lower layer must never depend on a higher one.

| Layer | Modules | Role |
|---|---|---|
| 0 | `aaa-config`, `sensors`, `grid` | Foundation; no intra-package dependencies |
| 1 | `classes`, `catalog` | Data representation and access |
| 2 | `preprocess`, `shadow`, `probability`, `uncertainty` | Pixel-level processing |
| 3 | `availability`, `simulate`, `evaluate`, `phenology` | Analysis |
| 4 | `engine`, `viz` | Orchestration and output |

Heavy dependencies (`terra`, `sf`, `httr2`) are suggested rather than imported and are gated behind a guard function that raises a single actionable error at point of use, satisfying P4. The test suite makes no network calls.

### 3.3 The equal-area analysis grid

Statistics are aggregated onto EASE-Grid 2.0 global (EPSG:6933), a cylindrical equal-area projection on the WGS84 ellipsoid with standard parallel 30° (Brodzik et al., 2012). Every cell has identical true ground area by construction, so counts are comparable across latitude and across sensors with different footprint geometries.

The forward projection uses the authalic formulation, with

*x* = *a k*₀ *λ*,  *y* = *a q*(*φ*) / (2*k*₀),

where *q*(*φ*) is the authalic function, *k*₀ = cos *φ*ₜₛ / √(1 − *e*² sin² *φ*ₜₛ), and the inverse is obtained by Newton iteration on *q*. This is implemented in closed form within the package rather than delegated to PROJ, so that grid arithmetic — and the tests that verify it — run without a geospatial installation.

Footprints are mapped to cells by one of two methods. The centroid method assigns a cell when its centroid falls within the footprint; it is unbiased in expectation, requires no dependencies, and is accurate when cells are much smaller than footprints, which is the usual case (25 km cells against 180 km Landsat scenes). The area method computes exact fractional overlap and requires `sf`.

### 3.4 Sensor drivers

Sensor-specific knowledge is confined to driver objects. A driver declares the mapping from standardised band names (`blue`, `nir`, `swir16`, `cirrus`, `tir1`, …) to the asset names used by a given catalogue, native resolutions, the quality-layer specification (bit-packed or categorical), scaling coefficients, catalogue collection identifiers, capability flags, and the commissioning and decommissioning dates of every platform in the constellation. Algorithms address bands by standardised name only. Adding a sensor is therefore a driver entry, not a code change. Drivers ship for Landsat 4–9, Sentinel-2, MODIS, and a generic driver covering PlanetScope, WorldView, SPOT, RapidEye and UAV imagery.

The capability flags have a functional role: `cl_methods(sensor = ...)` reports which algorithms are applicable before any data are downloaded, so that a method requiring a shortwave-infrared band fails informatively on a four-band UAV camera rather than producing a plausible but meaningless mask.

### 3.5 Evidence tiers

Three tiers are distinguished. **Tier A** derives cloud fractions from scene-level catalogue properties; it is fast and globally available but is a footprint average. **Tier B** aggregates producer quality layers over the cell. **Tier C** computes masks directly.

Converting a tier-A scene cloud fraction *f* into a per-pixel clear probability requires an assumption. Under independence, P(clear) = 1 − *f*. Because cloud is spatially clustered, this systematically overestimates usable observations for a specific location. The package therefore offers an alternative in which pixel-level clear fraction follows a Beta mixture with mean 1 − *f* and concentration *κ*, preserving the mean while reproducing the observed U-shaped distribution of pixel cloud occurrence within partly cloudy scenes. Requesting the empirical model on tier-A data raises an error rather than silently returning the naive value, and requesting the independent model emits a note that the result is an upper bound.

### 3.6 Shadow geometry

For a cloud top at height *h* with solar zenith *θₛ* and azimuth *φₛ*, the ground displacement of its shadow is *d* = *h* tan *θₛ* in direction *φₛ* + 180°, giving

Δ*x* = −*h* tan *θₛ* sin *φₛ*,  Δ*y* = −*h* tan *θₛ* cos *φₛ*.

A second, smaller displacement arises because an elevated cloud is imaged away from the ground point beneath it; this parallax term, *h* tan *θᵥ*, is negligible for Landsat but reaches roughly 0.19 *h* across a Sentinel-2 swath and is corrected optionally.

Detection sweeps candidate heights, displaces the cloud mask by the corresponding offset at each, and selects the height maximising the fraction of projected pixels that are genuinely dark. Darkness is expressed as *relative darkening against the clear-sky reference* — the fractional reflectance loss relative to the median of non-cloud pixels — rather than as a scene-wide contrast stretch. This distinction is not cosmetic: a stretch over a scene containing bright cloud pushes ordinary clear land towards the dark end of the range, causing most non-cloud pixels to score as shadow.

The method has a hard identifiability limit that is a property of geometry rather than of the algorithm. A shadow displaced beyond the analysis window cannot be found in it, so heights above approximately 0.5 *W* / tan *θₛ*, for a window of width *W*, are indistinguishable from lower ones. The implementation computes this bound a priori and warns, rather than silently returning the shortest candidate height (Section 4.2).

Terrain shadow is computed separately by ray-marching the solar vector across a digital elevation model. In rugged terrain both cloud shadow and topographic shadow are dark and both correlate with aspect; neither Fmask, the Sentinel-2 SCL nor single-date neural masks separate them explicitly, so topographic shadow is routinely absorbed into cloud-shadow statistics.

### 3.7 Simulation

The simulator generates fractal cloud fields thresholded to a requested coverage, with controllable characteristic size, edge softness and opacity, and casts a geometrically consistent shadow using the *same* offset function that the detector inverts. This shared kernel is a deliberate safeguard: a simulator with independent geometry could reward a detector for reproducing an error.

Opacity is the principal difficulty control. Fully opaque cloud is easy for every method; discrimination among methods occurs between roughly 0.2 and 0.6 opacity, where thin cirrus and cloud edges lie.

Temporal simulation uses a two-state Markov chain parameterised by marginal cloud probability *p* and lag-1 autocorrelation *ρ*:

*p*₁₁ = *p* + (1 − *p*)*ρ*,  *p*₀₁ = *p*(1 − *ρ*),

whose stationary probability is exactly *p* for every *ρ* ∈ [0, 1). This parameterisation was chosen over a transition-multiplier formulation, which must be clamped at high cloud fractions and whose clamped chain mixes so slowly that a one-year series never departs from its initial state.

### 3.8 Unit-validated statistics

The `cl_stats` class is a long-format table in which every row carries the metric, its value, its unit, its sample size and its **denominator**, validated against a controlled vocabulary on construction. Each metric additionally declares how two values *combine*: counts add, fractions and rates combine as sample-size-weighted means, and maximum gap takes the maximum. Combining a fraction without weighting by sample size yields the mean of means, which is not the mean: merging 0.20 (*n* = 90) with 0.80 (*n* = 10) gives 0.26, not 0.50.

This design exists because denominator confusion is a silent and consequential failure. A count summed across ten years and divided by ten is a mean *per year*; presenting it as a mean per scene footprint yields values that are physically impossible for the stated unit, since a WRS-2 path/row can receive at most about 23 Landsat acquisitions annually. Encoding the denominator makes such a relabelling a validation failure.

### 3.9 Availability, gaps and phenological feasibility

Availability functions operate on an observation table — one row per acquisition intersecting a cell — and are tier-agnostic. Beyond counts, the package reports the **distribution of gaps** between usable observations, including the intervals from period start to first clear observation and from last clear observation to period end. Cells with no usable observation in a period are retained and reported as having a gap equal to the full period; excluding them, as a naive implementation does, removes exactly the cases the analysis exists to identify and biases every summary optimistically.

Phenological feasibility is assessed by simulation. A known double-logistic trajectory is sampled only on dates when the cell was usable, observation noise is added, the curve is refitted, and the retrieval error is recorded across replicates. The output is the median absolute error of start-of-season (SOS), end-of-season and length-of-season in days, together with the **retrieval failure rate**: the fraction of replicates in which the fit did not converge at all. In heavily clouded regions the failure rate is the more consequential quantity, because a study there does not return a biased estimate; it returns none.

Constellation synergy accounts for platform commissioning dates, so that the changing effective revisit of a multi-mission archive is represented explicitly.

---

## 4. Validation and results

All results in this section derive from analytical identities or from controlled simulation with known truth. No result depends on a live satellite archive. This is a deliberate scope decision: the components validated here are those whose correctness can be established exactly, and establishing them is a precondition for trusting any subsequent archive analysis. The archive-dependent global product is described in Section 5.4 and has not yet been executed. The complete analysis is reproducible from `paper/analysis.R` in the repository.

### 4.1 Grid and projection

The closed-form projection round-trips to 1.4 × 10⁻¹⁴ degrees in longitude and 1.3 × 10⁻¹³ degrees in latitude across the range −179° to 179° and −85° to 82°. The critical test is whether the projection is genuinely equal-area: the projected plane area of the globe is 510,065,621,724,089 m² against a true WGS84 ellipsoid surface area of 510,065,621,700,000 m², a relative error of **4.7 × 10⁻¹¹** (Table 2). Cell area does not vary with latitude by construction.

**Table 2.** Grid and projection validation.

| Property | Value |
|---|---|
| Longitude round-trip error | 1.4 × 10⁻¹⁴ ° |
| Latitude round-trip error | 1.3 × 10⁻¹³ ° |
| Projected plane area | 510,065,621,724,089 m² |
| True WGS84 ellipsoid area | 510,065,621,700,000 m² |
| Relative area error | 4.7 × 10⁻¹¹ |
| Cell area variation with latitude | 0 (exact by construction) |

The consequence for availability statistics is shown in Figure 1 and Table 3. A 2° × 2° box covers 49,227 km² at the equator but only 12,062 km² at 75° N — 24.5 % of its equatorial area. Counted in equal-area cells, the same box occupies 80 cells at the equator and 16 at 75° N. Any statistic reported per fixed-degree or per-scene unit therefore embeds a factor-of-four latitude gradient that has nothing to do with the phenomenon being measured.

**Table 3.** Latitude dependence of a fixed-degree spatial unit (2° × 2° box), and its representation on a 25 km equal-area grid. Selected rows.

| Latitude (°) | True ground area (km²) | Equal-area cells | Relative to equator |
|---|---|---|---|
| 0 | 49,227 | 80 | 1.000 |
| 20 | 46,043 | 80 | 0.935 |
| 40 | 37,372 | 64 | 0.759 |
| 55 | 27,786 | 48 | 0.564 |
| 65 | 20,251 | 32 | 0.411 |
| 75 | 12,062 | 16 | 0.245 |

### 4.2 Shadow geometry and identifiability

Computed shadow displacement matches the analytical identity *d* = *h* tan *θₛ* to below 10⁻⁸ m across solar zenith angles from 0° to 75°, and the azimuthal direction is correct in all four cardinal cases (sun in the south places the shadow to the north; sun in the east places it to the west).

Cloud-top height recovery was tested across 36 configurations spanning four true heights (600–4800 m), three solar zenith angles (25°, 45°, 65°) and three azimuths. When the analysis window was sized to the geometry, the true height was recovered in **36 of 36 cases** to within one search step (50 m), with a median matching score of 1.00 (Table 4).

The same experiment run on a fixed 96 × 96 pixel window (2.9 km at 30 m resolution) recovered the height in only 24 of 36 cases, with errors up to 4600 m. Investigation established the cause unambiguously: recovery succeeded in 25 of 27 cases where the displacement fitted within the window and in **0 of 9** where it did not. This is not an algorithmic failure but an identifiability limit, and it is deterministic. The maximum resolvable cloud-top height for a window of width *W* is approximately 0.5 *W* / tan *θₛ* (Table 5). At a 55° solar zenith, a 3 km processing tile resolves cloud tops only to about 1050 m — well below typical convective cloud — so an operational tiling scheme at that size would silently misestimate shadow position for most clouds. The package computes this bound and warns.

**Table 4.** Shadow geometry validation.

| Test | *n* | Correct | Max absolute error | Median score |
|---|---|---|---|---|
| Displacement vs *h*·tan(*θ*) identity | 6 | 6/6 | < 10⁻⁸ m | — |
| Height recovery, window sized to geometry | 36 | 36/36 | 50 m | 1.00 |
| Height recovery, fixed 96 × 96 window (2.9 km) | 36 | 24/36 | 4600 m | — |

**Table 5.** Maximum resolvable cloud-top height (m) as a function of analysis-window width and solar zenith angle.

| Window (km) | 25° | 40° | 55° | 70° |
|---|---|---|---|---|
| 3 | 3,217 | 1,788 | 1,050 | 546 |
| 10 | 10,723 | 5,959 | 3,501 | 1,820 |
| 30 | 32,168 | 17,876 | 10,503 | 5,460 |
| 100 | 107,225 | 59,588 | 35,010 | 18,199 |

### 4.3 Detector benchmarking across a difficulty gradient

Two implemented methods — a brightness/whiteness threshold baseline and a decision-cascade Fmask-style formulation — were evaluated across six opacity levels with 12 replicates each (Table 6, Figure 2). Both discriminate essentially perfectly on this controlled background (AUC ≈ 1.00 throughout), confirming that ranking is not the discriminating axis. Intersection over union and expected calibration error are.

The cascade method outperforms the baseline at every opacity, with the gap widening as cloud becomes more transparent — the regime where operational masks disagree most. In a paired comparison on the hardest setting (opacity 0.25) using 1000 bootstrap replicates, the cascade achieved an accuracy of 0.925 (95 % CI 0.923–0.927) against 0.822 (0.819–0.825) for the baseline, with McNemar's *χ*² = 3783 (*p* < 10⁻¹⁵).

The value of reporting calibration separately from discrimination was demonstrated during development. An earlier implementation combined the cascade's tests as a weighted sum with a constant floor rather than as the conjunction the algorithm specifies. That version achieved AUC = 1.000 — a perfect ranking — while its expected calibration error was 0.373 and its accuracy at the default threshold was 0.611, because clear land accumulated a score of 0.627, above the 0.5 threshold. Reporting AUC alone would have concealed a method that was, operationally, worse than useless. Correcting the composite to a conjunction raised accuracy to 0.986 and reduced calibration error to 0.094.

**Table 6.** Detector performance across an opacity gradient (coverage 0.30, 12 replicates per cell). IoU: intersection over union; ECE: expected calibration error.

| Opacity | Method | Precision | Recall | F1 | IoU | AUC | ECE |
|---|---|---|---|---|---|---|---|
| 0.15 | fmask | 1.000 | 0.458 | 0.627 | 0.458 | 0.999 | 0.205 |
| 0.15 | threshold | — | 0.000 | — | 0.000 | 0.986 | 0.226 |
| 0.25 | fmask | 1.000 | 0.679 | 0.808 | 0.679 | 1.000 | 0.144 |
| 0.25 | threshold | 1.000 | 0.317 | 0.480 | 0.317 | 0.999 | 0.179 |
| 0.40 | fmask | 1.000 | 0.790 | 0.882 | 0.790 | 1.000 | 0.107 |
| 0.40 | threshold | 1.000 | 0.608 | 0.755 | 0.608 | 1.000 | 0.152 |
| 0.60 | fmask | 1.000 | 0.978 | 0.989 | 0.978 | 1.000 | 0.089 |
| 0.60 | threshold | 1.000 | 0.783 | 0.878 | 0.783 | 1.000 | 0.107 |
| 0.80 | fmask | 1.000 | 1.000 | 1.000 | 1.000 | 1.000 | 0.081 |
| 0.80 | threshold | 1.000 | 0.776 | 0.873 | 0.776 | 1.000 | 0.086 |
| 1.00 | fmask | 1.000 | 1.000 | 1.000 | 1.000 | 1.000 | 0.081 |
| 1.00 | threshold | 1.000 | 0.938 | 0.968 | 0.938 | 1.000 | 0.068 |

Two features deserve comment. At the lowest opacity the threshold baseline detects **nothing at all** (recall 0.000), while the cascade still recovers 46 % of cloud pixels; a single accuracy figure quoted at one opacity would conceal this entirely. Precision is 1.000 throughout because the synthetic background is spectrally uniform, so no clear pixel can be mistaken for cloud. This benchmark therefore measures sensitivity to thin cloud, not commission error over heterogeneous surfaces, and the two methods should not be assumed to rank identically on real imagery containing snow, bright soil or glint. Evaluation against CloudSEN12 is required to test the latter (Section 5.4).

### 4.4 Phenological feasibility

Retrieval error was simulated across eight cloud fractions and three levels of temporal autocorrelation, with 400 replicates per combination and 73 acquisition opportunities per year (Table 7, Figure 3).

The dependence on cloud amount is steep and non-linear. At a cloud fraction of 0.2, all 73 acquisitions remain usable and SOS is recovered with a median absolute error of 1 day and no fit failures. At 0.8, the median usable count falls to 15, SOS error rises to 2 days but its interquartile range widens to 3 days, and 21 % of fits fail. At 0.95, only 3 observations remain, the SOS interquartile range reaches 15–45 days, and 91–96 % of fits fail depending on clustering. The failure rate rises faster than the error, which is the practically important asymmetry: as conditions deteriorate, a study stops producing estimates before it starts producing badly wrong ones.

**Table 7.** Phenological retrieval performance. Selected rows; *ρ* is the lag-1 autocorrelation of observation loss.

| Cloud fraction | *ρ* | Usable obs (median) | SOS MAE (days) | SOS IQR (days) | Failure rate |
|---|---|---|---|---|---|
| 0.2 | 0.00 | 73 | 1 | 1 | 0.000 |
| 0.2 | 0.70 | 73 | 1 | 1 | 0.000 |
| 0.4 | 0.00 | 44 | 1 | 1 | 0.002 |
| 0.4 | 0.70 | 45 | 1 | 2 | 0.035 |
| 0.5 | 0.00 | 37 | 1 | 2 | 0.002 |
| 0.5 | 0.70 | 36 | 1 | 3 | 0.082 |
| 0.6 | 0.00 | 29 | 1 | 3 | 0.030 |
| 0.6 | 0.70 | 28 | 2 | 3 | 0.192 |
| 0.7 | 0.00 | 22 | 1 | 3 | 0.105 |
| 0.7 | 0.70 | 21 | 3 | 5 | 0.290 |
| 0.8 | 0.00 | 15 | 2 | 3 | 0.210 |
| 0.8 | 0.70 | 14 | 8 | 15 | 0.455 |
| 0.9 | 0.00 | 7 | 5 | 12 | 0.605 |
| 0.9 | 0.70 | 6 | 13 | 26 | 0.820 |
| 0.95 | 0.00 | 4 | 3 | 7 | 0.938 |
| 0.95 | 0.35 | 3 | 5 | 15 | 0.912 |
| 0.95 | 0.70 | 2 | 18 | 20 | 0.958 |

The clustering result is the more novel finding. Comparing *ρ* = 0 with *ρ* = 0.7 at matched cloud fractions (Table 8), the number of usable observations changes by less than 7 % — clustering does not appreciably reduce how much data one obtains. The failure rate, however, rises by a factor of 2.2 to 6.4. Clustering does not remove observations; it removes them from where they matter, concentrating loss into contiguous stretches that can eliminate an entire phenological transition while leaving the annual observation count nearly unchanged.

**Table 8.** Effect of temporal clustering at matched cloud fractions.

| Cloud fraction | Usable, *ρ* = 0 | Usable, *ρ* = 0.7 | Change | Failure, *ρ* = 0 | Failure, *ρ* = 0.7 | Ratio |
|---|---|---|---|---|---|---|
| 0.6 | 29 | 28 | −3.4 % | 0.030 | 0.192 | 6.40 |
| 0.7 | 22 | 21 | −4.5 % | 0.105 | 0.290 | 2.76 |
| 0.8 | 15 | 14 | −6.7 % | 0.210 | 0.455 | 2.17 |

The implication is direct: any feasibility assessment, power calculation or sampling design that assumes independent observation loss will be optimistic, and increasingly so in regions with persistent synoptic cloud regimes. Since cloud persistence is itself geographically structured, the bias is spatially systematic rather than random.

### 4.5 Constellation synergy

Effective revisit interval for a combined Landsat 8/9 and Sentinel-2 constellation is strongly non-stationary (Table 9, Figure 4). It falls from 22.1 days in 2013 to 8.7 days in 2015 after Sentinel-2A, 3.8 days by 2018 after Sentinel-2B, 3.1 days in 2022 after Landsat 9 became operational, and 2.4 days by 2025 after Sentinel-2C — a nine-fold change across the period.

**Table 9.** Effective revisit interval for a combined Landsat 8/9 and Sentinel-2 constellation. Selected years.

| Year | Active platforms | Observations yr⁻¹ | Effective revisit (days) |
|---|---|---|---|
| 2013 | 0.73 | 16.6 | 22.1 |
| 2015 | 1.53 | 42.0 | 8.7 |
| 2018 | 3.00 | 95.8 | 3.8 |
| 2021 | 3.17 | 99.6 | 3.7 |
| 2022 | 4.00 | 118.6 | 3.1 |
| 2025 | 5.00 | 155.1 | 2.4 |

This has an under-appreciated consequence for long time series. A trend computed over 2013–2025 without accounting for changing acquisition density partly measures the growth of the constellation rather than change in the environment. Studies reporting decadal trends in vegetation metrics derived from optical composites should either restrict to a period of stable acquisition capacity or model the change explicitly.

### 4.6 Software quality

The equal-area projection, cell indexing, shadow displacement, height recovery, terrain shadow directionality, thermal height estimation, simulator coverage, Markov marginal preservation and accuracy metrics were each verified against an exact reference (Table 10). The layer contract is verified by static call-graph analysis, and documentation completeness by roxygen block parsing. The suite comprises 110 assertions across nine files and makes no network calls.

**Table 10.** Software validation summary.

| Component | Verified against | Result |
|---|---|---|
| Equal-area projection | WGS84 ellipsoid surface area | 4.7 × 10⁻¹¹ relative error |
| Grid cell indexing | closed-form cell geometry | exact |
| Shadow displacement | *h*·tan(*θ*) identity | < 10⁻⁸ m (6/6 zenith angles) |
| Cloud-top height recovery | known simulated height | 36/36 (window sized to geometry) |
| Terrain shadow | sun-direction reversal | 0 shadowed pixels when reversed |
| Thermal height estimate | lapse-rate identity | exact |
| Simulator coverage | requested coverage | within 0.05 of target |
| Markov cloud marginal | stationary distribution | within 0.04 of target |
| Accuracy metrics | hand-computed confusion matrix | exact |
| Unit validation | controlled vocabulary | 12 metrics, 6 denominators |
| Layer contract | static call graph | 0 violations |
| Documentation completeness | roxygen block parse | 0 gaps |

The catalogue parser is tested against fixtures constructed from real STAC responses, including cases that broke earlier implementations: datetimes with fractional seconds; Landsat items carrying no MGRS fields, for which naive string concatenation produced the identical literal tile identifier `"NANANA"` across unrelated scenes; antimeridian tiles returned as MultiPolygon rather than Polygon, which an implementation handling only Polygon dropped entirely — removing precisely the high-latitude scenes that availability analysis most needs; and items lacking a cloud-cover property, which are now excluded with a warning rather than treated as clear.

---

## 5. Discussion

### 5.1 What changes when statistics are reported in decision units

The results of Section 4.4 illustrate the argument. Two sites with a 70 % annual cloud fraction are indistinguishable under conventional reporting. Under cloudscape they may differ by a factor of nearly three in the probability that a phenological study succeeds at all, depending on the temporal structure of their cloud. A reviewer given only the mean cannot assess whether the phenological conclusions are supportable; a reviewer given the usable-observation count, maximum gap, simulated retrieval error and failure rate can.

This reframing also clarifies what additional sensors buy. Table 9 shows effective revisit falling nine-fold across the study period. Whether that converts into usable observations depends on whether the constellations are clouded at the same times, which they largely are. The gain is real but smaller than revisit numbers alone imply, and the package makes the distinction computable rather than rhetorical.

### 5.2 Relationship to existing tools

cloudscape is not a competitor to Fmask, Sen2Cor, MAJA or s2cloudless, and deliberately does not introduce a new detection algorithm. It is a layer above them: a consistent interface through which any of them can be invoked, an unbiased unit onto which their outputs are aggregated, and machinery for converting the aggregate into a feasibility statement. Its `qa` method reads producer masks directly and translates bit-packed Landsat `QA_PIXEL` and categorical Sentinel-2 SCL into one class vocabulary, which is what makes CFMask, Sen2Cor and a neural mask directly comparable.

Relative to Google Earth Engine implementations, the trade-off is explicit. GEE offers planetary-scale compute; cloudscape offers reproducibility without authentication, a proprietary backend or an internet connection, and provenance recorded per object. For the specific task of establishing what a published statistic was computed from, the latter matters more.

### 5.3 A methodological caution about archive-derived cloud statistics

Three cautions apply to any statistic derived from archive metadata, and the package records them in the provenance manifest attached to every object.

First, **an archive is not a climatology**. Acquisition is scheduled, not random, and mask commission errors over snow, bright soil and sun glint are systematic rather than noise. Archive-derived cloud fractions should not be interpreted as cloud climatology without independent validation against a dedicated cloud product such as MODIS MOD35 or CALIPSO.

Second, **cross-sensor comparisons compare algorithms as much as atmospheres**. Landsat `CLOUD_COVER` is produced by CFMask; Sentinel-2 `eo:cloud_cover` by Sen2Cor. A difference between them is not evidence of a difference in cloudiness.

Third, **processing baselines changed during the period most studies cover**. Sen2Cor baselines and the Collection 1 to Collection 2 transition both altered cloud masks, so apparent temporal trends in archive-derived cloud statistics are partly reprocessing artefacts. This is why every cloudscape object carries a manifest recording the endpoint, collection, algorithm and access time.

We note that these cautions apply to our own prior work (Rahimi and Jung, 2024b) as much as to any other.

### 5.4 Limitations

**No component has yet been evaluated against real satellite scenes.** All validation reported here is against analytical identities and synthetic truth. This catches geometry and statistical errors — it caught eleven during development, including two that would have produced silently wrong published numbers — but it cannot catch a wrong band mapping or a misread quality bit. An integration script exercising live catalogue access is provided but must be run by the user; results against CloudSEN12 and the Landsat 8 Biome dataset are required before the detection components should be relied upon operationally.

**The global pre-computed dataset has not been produced.** The harvest script is written and resumable, but a global tier-A harvest is tens of millions of paged catalogue requests over days against provider rate limits. It is deliberately not exposed as a function call, both to avoid accidental launches and because a statistic that samples a shifting archive on every run is not reproducible.

**The phenology module assumes a double-logistic trajectory.** Sites with multiple growing seasons, evergreen canopies or strong management signals will not be well represented, and the reported errors are therefore lower bounds on real-world retrieval error, which additionally includes atmospheric residual, bidirectional reflectance effects and geolocation error.

**The clustering result is derived from a two-state Markov model**, which reproduces observed run-length behaviour but does not capture seasonal modulation of persistence. Estimating *ρ* directly from archive quality layers is a natural next step and would convert Table 8 from a sensitivity analysis into a map.

**Learned detection methods are registered but not implemented in v0.1.0**, pending distribution of model weights through the companion data package.

### 5.5 Future work

Priorities are, in order: validation against CloudSEN12 and Biome; execution and deposition of the global tier-A product with a persistent identifier; estimation of cloud persistence *ρ* from quality layers to produce a global map of clustering-adjusted feasibility; and inter-method disagreement mapping, which requires no reference labels and identifies where cloud statistics from any source should be treated with caution.

---

## 6. Conclusions

Cloud-masking software answers the question "which pixels are cloudy". Researchers designing optical time-series studies are usually asking a different question: "will this work here". We have presented cloudscape, an R framework built to answer the second question, and shown that doing so requires three changes to how cloud statistics are handled.

The spatial unit must be equal-area. Sensor footprints embed a latitude gradient of more than a factor of four between the equator and 75°, and that gradient is largest exactly where availability is lowest, so per-scene statistics are least trustworthy where they are most consequential.

The evidence tier must be explicit. Scene-level cloud cover is a footprint average, and converting it to a per-pixel clear probability under independence overestimates usable observations. Software should label this as the upper bound it is.

Statistics must be reported in decision units. A cloud percentage does not tell a phenologist whether green-up is retrievable; a retrieval error in days and a failure rate do.

In demonstrating the third point we obtained a result of independent interest. Temporal clustering of cloud degrades phenological retrieval largely independently of cloud amount: at a fixed 70 % cloud fraction, raising the lag-1 autocorrelation of observation loss from 0 to 0.7 changes usable observation count by under 5 % but raises the fit failure rate from 10.5 % to 29.0 %. Because cloud persistence is geographically structured, feasibility assessments assuming independent loss are optimistic in a spatially systematic way. We suggest that studies reporting land-surface phenology from optical imagery report the usable observation count, the maximum gap and a simulated retrieval failure rate alongside their estimates, and that cloudscape or an equivalent be used to compute them.

The package is released under GPL-3 with a complete test suite, a mechanically enforced architecture contract, and provenance recorded on every object.

---

## Software and data availability

**Name:** cloudscape
**Developers:** Ehsan Rahimi, Chuleui Jung
**Contact:** ehsanrahimi666@gmail.com
**Year first available:** 2026
**Hardware required:** None beyond a standard workstation
**Software required:** R ≥ 4.1. Optional: `terra`, `sf`, `httr2`, `jsonlite`
**Program language:** R
**Program size:** approximately 3,900 lines of R source
**Availability:** https://github.com/ehsanrahimi666/cloudscape
**Licence:** GPL-3

All tables and figures in this manuscript are reproduced by `paper/analysis.R`. The test suite runs via `Rscript tools/offline-check.R` using base R only.

## Author contributions

**ER:** Conceptualisation, Methodology, Software, Validation, Formal analysis, Writing — original draft. **CJ:** Conceptualisation, Supervision, Funding acquisition, Writing — review and editing.

## Declaration of competing interests

The authors declare no competing interests.

## Acknowledgements

*[Funding statement to be inserted, following the pattern of prior work: National Research Foundation of Korea and Rural Development Administration support.]*

---

## References

Aybar, C., Wu, Q., Bautista, L., Yali, R., Barja, A., 2020. rgee: An R package for interacting with Google Earth Engine. Journal of Open Source Software 5 (51), 2272.

Aybar, C., Ysuhuaylas, L., Loja, J., Gonzales, K., Herrera, F., Bautista, L., Yali, R., Flores, A., Diaz, L., Cuenca, N., Espinoza, W., Prudencio, F., Llactayo, V., Montero, D., Sudmanns, M., Tiede, D., Mateo-García, G., Gómez-Chova, L., 2022. CloudSEN12, a global dataset for semantic understanding of cloud and cloud shadow in Sentinel-2. Scientific Data 9, 782. https://doi.org/10.1038/s41597-022-01878-2

Brodzik, M.J., Billingsley, B., Haran, T., Raup, B., Savoie, M.H., 2012. EASE-Grid 2.0: Incremental but significant improvements for Earth-gridded data sets. ISPRS International Journal of Geo-Information 1 (1), 32–45. https://doi.org/10.3390/ijgi1010032

Brodzik, M.J., Billingsley, B., Haran, T., Raup, B., Savoie, M.H., 2014. Correction: EASE-Grid 2.0. ISPRS International Journal of Geo-Information 3 (3), 1154–1156. https://doi.org/10.3390/ijgi3031154

Cao, R., Chen, Y., Chen, J., Zhu, X., Shen, M., 2020. Thick cloud removal in Landsat images based on autoregression of Landsat time-series data. Remote Sensing of Environment 249, 112001. https://doi.org/10.1016/j.rse.2020.112001

Crawford, C.J., Roy, D.P., Arab, S., Barnes, C., Vermote, E., Hulley, G., et al., 2023. The 50-year Landsat collection 2 archive. Science of Remote Sensing 8, 100103. https://doi.org/10.1016/j.srs.2023.100103

Forkel, M., Carvalhais, N., Verbesselt, J., Mahecha, M.D., Neigh, C.S., Reichstein, M., 2013. Trend change detection in NDVI time series: Effects of inter-annual variability and methodology. Remote Sensing 5 (5), 2113–2144. https://doi.org/10.3390/rs5052113

Guyet, T., Nicolas, H., 2016. Long term analysis of time series of satellite images. Pattern Recognition Letters 70, 17–23. https://doi.org/10.1016/j.patrec.2015.11.005

Holden, C.E., Woodcock, C.E., 2016. An analysis of Landsat 7 and Landsat 8 underflight data and the implications for time series investigations. Remote Sensing of Environment 185, 16–36. https://doi.org/10.1016/j.rse.2016.02.052

Hu, C., Huo, L.-Z., Zhang, Z., Tang, P., 2020. Multi-temporal Landsat data automatic cloud removal using Poisson blending. IEEE Access 8, 46151–46161. https://doi.org/10.1109/access.2020.2979291

Hu, Q., Sulla-Menashe, D., Xu, B., Yin, H., Tang, H., Yang, P., et al., 2019. A phenology-based spectral and temporal feature selection method for crop mapping from satellite time series. International Journal of Applied Earth Observation and Geoinformation 80, 218–229. https://doi.org/10.1016/j.jag.2019.04.014

Huang, S., Tang, L., Hupy, J.P., Wang, Y., Shao, G., 2021. A commentary review on the use of normalized difference vegetation index (NDVI) in the era of popular remote sensing. Journal of Forestry Research 32 (1), 1–6. https://doi.org/10.1007/s11676-020-01155-1

Jain, M., Mondal, P., DeFries, R.S., Small, C., Galford, G.L., 2013. Mapping cropping intensity of smallholder farms: A comparison of methods using multiple sensors. Remote Sensing of Environment 134, 210–223. https://doi.org/10.1016/j.rse.2013.02.029

King, M.D., Platnick, S., Menzel, W.P., Ackerman, S.A., Hubanks, P.A., 2013. Spatial and temporal distribution of clouds observed by MODIS onboard the Terra and Aqua satellites. IEEE Transactions on Geoscience and Remote Sensing 51 (7), 3826–3852. https://doi.org/10.1109/tgrs.2012.2227333

Li, Z., Shen, H., Cheng, Q., Liu, Y., You, S., He, Z., 2019. Deep learning based cloud detection for medium and high resolution remote sensing images of different sensors. ISPRS Journal of Photogrammetry and Remote Sensing 150, 197–212. https://doi.org/10.1016/j.isprsjprs.2019.02.017

Liu, J., Zhu, W., Atzberger, C., Zhao, A., Pan, Y., Huang, X., 2018. A phenology-based method to map cropping patterns under a wheat-maize rotation using remotely sensed time-series data. Remote Sensing 10 (8), 1203. https://doi.org/10.3390/rs10081203

Loveland, T.R., Irons, J.R., 2016. Landsat 8: The plans, the reality, and the legacy. Remote Sensing of Environment 185, 1–6. https://doi.org/10.1016/j.rse.2016.07.033

Lymburner, L., Botha, E., Hestir, E., Anstee, J., Sagar, S., Dekker, A., et al., 2016. Landsat 8: Providing continuity and increased precision for measuring multi-decadal time series of total suspended matter. Remote Sensing of Environment 185, 108–118. https://doi.org/10.1016/j.rse.2016.04.011

Orusa, T., Cammareri, D., Freppaz, D., Vuillermoz, P., Borgogno Mondino, E., 2023a. Sen4MUN: A prototypal service for the distribution of contributions to the European municipalities from Copernicus satellite imagery. In: Italian Conference on Geomatics and Geospatial Technologies. Springer, pp. 109–125.

Orusa, T., Viani, A., Moyo, B., Cammareri, D., Borgogno-Mondino, E., 2023b. Risk assessment of rising temperatures using Landsat 4–9 LST time series and Meta population dataset: An application in Aosta Valley, NW Italy. Remote Sensing 15 (9), 2348. https://doi.org/10.3390/rs15092348

Petitjean, F., Kurtz, C., Passat, N., Gançarski, P., 2012. Spatio-temporal reasoning for the classification of satellite image time series. Pattern Recognition Letters 33 (13), 1805–1815. https://doi.org/10.1016/j.patrec.2012.06.009

Qiu, B., Li, W., Tang, Z., Chen, C., Qi, W., 2015. Mapping paddy rice areas based on vegetation phenology and surface moisture conditions. Ecological Indicators 56, 79–86. https://doi.org/10.1016/j.ecolind.2015.03.039

Qiu, S., Lin, Y., Shang, R., Zhang, J., Ma, L., Zhu, Z., 2018. Making Landsat time series consistent: Evaluating and improving Landsat analysis ready data. Remote Sensing 11 (1), 51. https://doi.org/10.3390/rs11010051

Qiu, S., Zhu, Z., Woodcock, C.E., 2020. Cirrus clouds that adversely affect Landsat 8 images: What are they and how to detect them? Remote Sensing of Environment 246, 111884. https://doi.org/10.1016/j.rse.2020.111884

Rahimi, E., 2024. The efficiency of long short-term memory (LSTM) in phenology-based crop classification. Korean Journal of Remote Sensing 40 (1), 57–69. https://doi.org/10.7780/kjrs.2024.40.1.6

Rahimi, E., Barghjelveh, S., Dong, P., 2022. A comparison of discrete and continuous metrics for measuring landscape changes. Journal of the Indian Society of Remote Sensing 50 (7), 1257–1273. https://doi.org/10.1007/s12524-022-01526-7

Rahimi, E., Jung, C., 2024a. Comparative analysis of supervised and phenology-based approaches for crop mapping: A case study in South Korea. Korean Journal of Remote Sensing 40 (2), 179–190. https://doi.org/10.7780/kjrs.2024.40.2.5

Rahimi, E., Jung, C., 2024b. Evaluating the applicability of Landsat 8 data for global time series analysis. Frontiers in Remote Sensing 5, 1492534. https://doi.org/10.3389/frsen.2024.1492534

Roy, D.P., Wulder, M.A., Loveland, T.R., Woodcock, C.E., Allen, R.G., Anderson, M.C., et al., 2014. Landsat-8: Science and product vision for terrestrial global change research. Remote Sensing of Environment 145, 154–172. https://doi.org/10.1016/j.rse.2014.02.001

Shen, Y., Wang, Y., Lv, H., Li, H., 2015. Removal of thin clouds using cirrus and QA bands of Landsat-8. Photogrammetric Engineering & Remote Sensing 81 (9), 721–731. https://doi.org/10.14358/pers.81.9.721

Simoes, R., Camara, G., Queiroz, G., Souza, F., Andrade, P.R., Santos, L., et al., 2021. Satellite image time series analysis for big Earth observation data. Remote Sensing 13 (13), 2428. https://doi.org/10.3390/rs13132428

Tian, H., Huang, N., Niu, Z., Qin, Y., Pei, J., Wang, J., 2019. Mapping winter crops in China with multi-source satellite imagery and phenology-based algorithm. Remote Sensing 11 (7), 820. https://doi.org/10.3390/rs11070820

Tolnai, M., Nagy, J.G., Bakó, G., 2016. Spatiotemporal distribution of Landsat imagery of Europe using cloud cover-weighted metadata. Journal of Maps 12 (5), 1084–1088. https://doi.org/10.1080/17445647.2015.1125308

Verbesselt, J., Hyndman, R., Newnham, G., Culvenor, D., 2010. Detecting trend and seasonal changes in satellite image time series. Remote Sensing of Environment 114 (1), 106–115. https://doi.org/10.1016/j.rse.2009.08.014

Viani, A., Orusa, T., Borgogno-Mondino, E., Orusa, R., 2024. A One Health Google Earth Engine web-GIS application to evaluate and monitor water quality worldwide. Euro-Mediterranean Journal for Environmental Integration, 1–14. https://doi.org/10.1007/s41207-024-00528-w

Waldner, F., Canto, G.S., Defourny, P., 2015. Automated annual cropland mapping using knowledge-based temporal features. ISPRS Journal of Photogrammetry and Remote Sensing 110, 1–13. https://doi.org/10.1016/j.isprsjprs.2015.09.013

Whitcraft, A.K., Vermote, E.F., Becker-Reshef, I., Justice, C.O., 2015a. Cloud cover throughout the agricultural growing season: Impacts on passive optical Earth observations. Remote Sensing of Environment 156, 438–447. https://doi.org/10.1016/j.rse.2014.10.009

Whitcraft, A.K., Becker-Reshef, I., Killough, B.D., Justice, C.O., 2015b. Meeting Earth observation requirements for global agricultural monitoring: An evaluation of the revisit capabilities of current and planned moderate resolution optical Earth observing missions. Remote Sensing 7 (2), 1482–1503. https://doi.org/10.3390/rs70201482

Xu, L., Herold, M., Tsendbazar, N.-E., Masiliūnas, D., Li, L., Lesiv, M., et al., 2022. Time series analysis for global land cover change monitoring: A comparison across sensors. Remote Sensing of Environment 271, 112905. https://doi.org/10.1016/j.rse.2022.112905

Zhang, Y., Woodcock, C.E., Arévalo, P., Olofsson, P., Tang, X., Stanimirova, R., et al., 2022. A global analysis of the spatial and temporal variability of useable Landsat observations at the pixel scale. Frontiers in Remote Sensing 3, 894618. https://doi.org/10.3389/frsen.2022.894618

Zhao, F., Xia, L., Kylling, A., Shang, H., Yang, P., 2022. Mapping global flying aircraft activities using Landsat 8 and cloud computing. ISPRS Journal of Photogrammetry and Remote Sensing 184, 19–30. https://doi.org/10.1016/j.isprsjprs.2021.12.003

Zhu, X., Helmer, E.H., 2018. An automatic method for screening clouds and cloud shadows in optical satellite image time series in cloudy regions. Remote Sensing of Environment 214, 135–153. https://doi.org/10.1016/j.rse.2018.05.024

Zhu, Z., Woodcock, C.E., 2012. Object-based cloud and cloud shadow detection in Landsat imagery. Remote Sensing of Environment 118, 83–94. https://doi.org/10.1016/j.rse.2011.10.028

---

### Reference verification note

References marked below were verified against primary sources during preparation. **All remaining references are taken verbatim from the reference list of Rahimi and Jung (2024b)** and were therefore already through peer review, but volume and page numbers should be re-checked at proof stage.

**Verified in preparation:** Brodzik et al. (2012, 2014); Aybar et al. (2022); Aybar et al. (2020); Whitcraft et al. (2015a, 2015b).

**Requires verification before submission:** Zhu and Woodcock (2012) — volume and pages stated from memory. The following works are cited in the text by name but are **not yet in the reference list and must be added with verified details**: Foga et al. (2017) on CFMask validation; Main-Knorn et al. (2017) on Sen2Cor; Hagolle et al. on MAJA; Vermote et al. (2016) on LaSRC; Frantz (2019) on FORCE; Gorelick et al. (2017) on Google Earth Engine; Claverie et al. (2018) on Harmonized Landsat Sentinel-2; Drusch et al. (2012) on Sentinel-2; Baetens et al. (2019) on comparative mask validation; Ranghetti et al. (2020) on sen2r; Appel and Pebesma (2019) on gdalcubes; Hijmans on terra; Pebesma (2018) on sf; Zupanc (2017) on s2cloudless.
