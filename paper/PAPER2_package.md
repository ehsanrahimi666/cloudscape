# cloudscape: an R package for assessing whether an optical satellite time-series analysis is possible before undertaking it

**Ehsan Rahimi**^1\*^ and **Chuleui Jung**^1,2^

^1^ Agricultural Science and Technology Institute, Gyeongkuk National University, Andong, Republic of Korea
^2^ Department of Plant Medical, Gyeongkuk National University, Andong, Republic of Korea

\* Correspondence: ehsanrahimi666@gmail.com

## ABSTRACT

**Aim**

Cloud-masking software identifies contaminated pixels. Researchers designing optical time-series studies need something different: an answer to whether enough usable observation will remain at their site, when in the year it will fall, and how large the resulting error in a derived quantity will be. We present **cloudscape**, an R package built to answer that question.

**Location**

Global. Demonstrated in detail at Andong, Republic of Korea (128.73° E, 36.57° N), and applied across 24 sites spanning 17 climate regimes.

**Time period**

Applicable to the full Landsat record from 1982 and the Sentinel-2 record from 2015. The worked example covers 2019–2024.

**Major taxa studied**

Not applicable; the package serves any discipline using optical satellite time series, with land-surface phenology as the demonstration application.

**Methods**

The package aggregates archive statistics onto an equal-area analysis grid rather than onto sensor footprints, so that results are comparable across latitude and between missions. It provides interchangeable cloud-probability algorithms behind one interface, a geometric cloud-shadow projection engine that shares its kernel with a synthetic cloud simulator, an estimator of cloud persistence expressed as a lag-invariant decorrelation time, and a facility that propagates an acquisition pattern into phenological retrieval error in days. Every statistic carries a validated unit, sample size, denominator and combination rule. Data are obtained through SpatioTemporal Asset Catalogs, requiring no account.

**Results**

The equal-area projection reproduces the WGS84 ellipsoid surface area to a relative error of 4.7 × 10⁻¹¹, and shadow displacement matches the analytical identity to below 10⁻⁸ m; cloud-top height is recovered exactly in 36 of 36 configurations when the analysis window spans the displacement, and the package reports the identifiability limit when it does not. In the worked example, 6,167 scenes over six years yielded 19,366 cell-observations, of which 34% were usable; the archive was 44% usable in the dormant season but 12% in July and August, a 6.9-fold seasonal swing with its minimum at peak biomass. The full test suite comprises 136 assertions with no network calls, and a static call-graph analyser enforces the module layer contract.

**Main conclusions**

Making the spatial unit equal-area, making the evidence tier explicit and expressing results in decision units are three changes that can be implemented in software and that materially alter the conclusions a user draws. The package is released under GPL-3 with complete documentation, four vignettes and a reproducible worked example.

**Keywords**

cloud masking, data availability, equal-area grid, land surface phenology, R package, reproducible research, Sentinel-2, SpatioTemporal Asset Catalog

---

## 1 | INTRODUCTION

A researcher planning to map crop phenology, detect deforestation or track surface water from optical imagery faces a question before any processing begins: is there enough usable data at this site to support the analysis? The question is routinely answered informally — by consulting a cloud climatology, by inspecting a few scenes, or by proceeding and discovering the answer afterwards.

The available software does not help much, because it addresses an adjacent problem. Cloud detection is mature: decision-cascade methods following Zhu and Woodcock (2012) underpin the operational Landsat quality layers (Crawford et al., 2023), thermal and cirrus bands constrain difficult cases (Shen et al., 2015; Qiu et al., 2020), multi-temporal methods exploit the regularity of clear-sky reflectance (Zhu and Helmer, 2018; Cao et al., 2020), and learned models dominate recent benchmarks (Li et al., 2019) supported by large reference datasets (Aybar et al., 2022). All of these tell a user which pixels are cloudy. None tells them whether their study will work.

Bridging that gap requires three things that existing tools leave to the user, and each is a design decision rather than an algorithm.

**The spatial unit must be unbiased.** World Reference System-2 scene area falls with latitude and orbital side-lap grows towards the poles, so statistics reported per scene confound acquisition density with viewing geometry — most severely where availability is lowest. The same geometry prevents comparison with Sentinel-2, whose Military Grid Reference System tiles differ in size and placement.

**The evidence tier must be explicit.** Scene-level cloud cover is a footprint average. Converting it to a statement about a particular location requires assuming something about the spatial distribution of cloud within the footprint, and the natural assumption is optimistic. The pixel-scale analysis of Zhang et al. (2022) shows how much difference this makes.

**Results must be expressed in decision units.** "42% mean cloud cover" does not tell a phenologist whether green-up is retrievable. "Start-of-season error 3 days, 21% of fits fail" does.

We describe **cloudscape**, an R package built around these three principles, and demonstrate it on a real site.

## 2 | DESIGN AND IMPLEMENTATION

### 2.1 | What the package does

The package has five capabilities, exposed through a consistent interface in which every function has a single responsibility (Table 1).

**Table 1.** Capabilities and the principal functions that provide them.

| Capability | Principal functions | Question answered |
|---|---|---|
| Find what exists | `cl_search`, `cl_items_to_obs` | How many acquisitions cover this place, from which sensors, when? |
| Judge usability | `cl_clear_obs`, `cl_gaps`, `cl_seasonality`, `cl_persistence` | How many are usable, when do they fall, how long are the gaps, how clustered is the cloud? |
| Detect cloud and shadow | `cl_probability`, `cl_shadow`, `cl_qa_decode`, `cl_terrain_shadow` | Which pixels are contaminated, where is the shadow, how high was the cloud? |
| Decide feasibility | `cl_pheno_power`, `cl_pheno_map`, `cl_feasibility`, `cl_synergy` | Will my green-up date be right, and by how many days will it be wrong? |
| Benchmark | `cl_simulate`, `cl_validate`, `cl_compare`, `cl_calibration` | Which detector is better here, and is the difference real? |

The package deliberately does not introduce a new cloud-detection algorithm, perform gap filling or carry out atmospheric correction. Those are well served elsewhere, and duplicating them would obscure the question of how much real data exists.

### 2.2 | Architecture

Sixteen modules are organised into five layers, with the rule that a lower layer never calls into a higher one (Table 2). The constraint is enforced by a static call-graph analyser executed as part of the test suite, rather than being documented and hoped for. It has already earned its place: an observation-table constructor originally sat in the analysis layer while the catalogue reader depended on it, which the check identified.

**Table 2.** Module layers.

| Layer | Modules | Role |
|---|---|---|
| 0 | `aaa-config`, `sensors`, `grid` | Foundation; no intra-package dependencies |
| 1 | `classes`, `catalog` | Data representation and access |
| 2 | `preprocess`, `shadow`, `probability`, `uncertainty` | Pixel-level processing |
| 3 | `availability`, `simulate`, `evaluate`, `phenology` | Analysis |
| 4 | `engine`, `viz` | Orchestration and output |

Heavy dependencies (`terra`, `sf`, `httr2`) are suggested rather than imported and are loaded only when raster or network functionality is used, so the statistical core installs and runs its full test suite without a geospatial toolchain. The test suite makes no network calls, which is both a requirement of CRAN and a precondition for reproducibility.

### 2.3 | The equal-area analysis grid

Statistics are aggregated onto EASE-Grid 2.0 global (EPSG:6933), a cylindrical equal-area projection on the WGS84 ellipsoid with standard parallel 30° (Brodzik et al., 2012, 2014). The forward projection uses the authalic formulation and is implemented in closed form within the package, so grid arithmetic and the tests verifying it run without a PROJ installation.

Footprints are mapped to cells by centroid containment, which is unbiased in expectation and accurate when cells are much smaller than footprints, or by exact fractional overlap where that condition does not hold.

### 2.4 | Sensor drivers

Sensor-specific knowledge is confined to driver objects declaring band names, native resolutions, quality-layer specification, scaling coefficients, catalogue collection identifiers, capability flags and the operational period of every platform in the constellation. Algorithms address bands by standardised name only, so adding a sensor is a driver entry rather than a code change (Table 3).

**Table 3.** Sensor drivers supplied with the package.

| Driver | Missions | Availability from the default catalogue |
|---|---|---|
| `landsat-4-7-tm-etm` | Landsat 4, 5, 7 (1982–2024) | Probed at run time |
| `landsat-8-9-oli` | Landsat 8, 9 (2013–) | Yes |
| `sentinel-2-msi` | Sentinel-2 A, B, C (2015–) | Yes |
| `modis-mod09ga` | Terra, Aqua (2000–) | Alternative backend |
| `generic-multispectral` | PlanetScope, WorldView, SPOT, RapidEye, UAV | User-supplied files |

The capability flags have a functional role: `cl_methods(sensor = ...)` reports which algorithms are applicable before any data are downloaded, so a method requiring a shortwave-infrared band fails informatively on a four-band camera rather than producing a plausible but meaningless mask.

### 2.5 | One shadow-geometry kernel, used in two directions

For a cloud top at height *h* with solar zenith *θ*ₛ and azimuth *φ*ₛ, the shadow falls at horizontal distance *h* tan *θ*ₛ in direction *φ*ₛ + 180°. A second, smaller displacement arises because an elevated cloud is imaged away from the ground point beneath it; this term reaches roughly 0.19 *h* across a Sentinel-2 swath.

Detection sweeps candidate heights and selects the one maximising the fraction of projected pixels that are genuinely dark. The simulator applies the same function forwards to cast a physically consistent shadow from a synthetic cloud. Sharing the kernel is a deliberate safeguard: a simulator with independent geometry could reward a detector for reproducing an error.

Darkness is expressed as relative darkening against the clear-sky reference — the fractional reflectance loss relative to the median of non-cloud pixels — rather than as a scene-wide contrast stretch. The distinction is not cosmetic: a stretch over a scene containing bright cloud pushes ordinary clear land towards the dark end of the range, causing most non-cloud pixels to score as shadow.

The method has an identifiability limit that is a property of geometry rather than of the algorithm. A shadow displaced beyond the analysis window cannot be found in it, so heights above approximately 0.5 *W* / tan *θ*ₛ, for a window of width *W*, are indistinguishable from lower ones (Table 4). The implementation computes this bound before processing and warns, rather than silently returning the shortest candidate height.

**Table 4.** Maximum resolvable cloud-top height (m) by analysis-window width and solar zenith angle. At a 55° sun, a 3 km processing tile resolves cloud tops only to about 1,050 m, below typical convective cloud.

| Window (km) | 25° | 40° | 55° | 70° |
|---|---|---|---|---|
| 3 | 3,217 | 1,788 | 1,050 | 546 |
| 10 | 10,723 | 5,959 | 3,501 | 1,820 |
| 30 | 32,168 | 17,876 | 10,503 | 5,460 |
| 100 | 107,225 | 59,588 | 35,010 | 18,199 |

### 2.6 | Units enforced in the data structure

The statistics class is a long-format table in which every row carries the metric, its value, its unit, its sample size and its **denominator**, validated against a controlled vocabulary on construction. Each metric additionally declares how two values combine: counts add, fractions and rates combine as sample-size-weighted means, and maximum gap takes the maximum.

This strictness exists because denominator confusion is a silent and consequential failure. Combining a fraction without weighting by sample size yields the mean of means, which is not the mean: merging 0.20 (*n* = 90) with 0.80 (*n* = 10) gives 0.26, not 0.50. Encoding the rule in the class makes the error impossible rather than merely discouraged.

### 2.7 | Cloud persistence

Cloud occurrence is modelled as a two-state chain with marginal probability *p* and lag-1 autocorrelation *ρ*, parameterised as *p*₁₁ = *p* + (1 − *p*)*ρ* and *p*₀₁ = *p*(1 − *ρ*), whose stationary probability is exactly *p* for every *ρ* ∈ [0, 1). This was chosen over a transition-multiplier formulation, which must be clamped at high cloud fractions and whose clamped chain mixes so slowly that a one-year series never departs from its initial state.

Because the lag is whatever the local acquisition interval happens to be, and orbits converge towards the poles, the package also reports the decorrelation time *τ* = −Δ*t* / log *ρ*, which is independent of observation frequency.

The estimate is a lower bound. Whether an acquisition is usable at a given cell is inferred by thresholding a scene-level cloud fraction, which is a noisy proxy; independent misclassification attenuates an estimated autocorrelation towards zero. In simulation, a true *ρ* of 0.6 is recovered as approximately 0.41.

## 3 | VALIDATION

Every component was verified against an exact reference (Table 5). The projection was checked against the WGS84 ellipsoid surface area, shadow displacement against its closed-form identity, cloud-top height recovery against a known simulated height, terrain shadow against reversal of the sun direction, and accuracy metrics against a hand-computed confusion matrix.

**Table 5.** Software validation summary.

| Component | Verified against | Result |
|---|---|---|
| Equal-area projection | WGS84 ellipsoid surface area | 4.7 × 10⁻¹¹ relative error |
| Projection round trip | Inverse transformation | < 10⁻⁹ degrees |
| Shadow displacement | *h* tan *θ* identity | < 10⁻⁸ m, six zenith angles |
| Cloud-top height recovery | Known simulated height | 36 of 36, window sized to geometry |
| Cloud-top height recovery | Known simulated height | 24 of 36, fixed 2.9 km window |
| Terrain shadow | Reversal of sun direction | 0 shadowed pixels when reversed |
| Thermal height estimate | Lapse-rate identity | Exact |
| Simulator coverage | Requested coverage | Within 0.05 of target |
| Markov marginal | Stationary distribution | Within 0.04 of target |
| Persistence estimator | Known simulated *ρ* | Within 0.05 |
| Accuracy metrics | Hand-computed confusion matrix | Exact |
| Unit validation | Controlled vocabulary | 12 metrics, 6 denominators |
| Layer contract | Static call graph | 0 violations |
| Documentation | Roxygen block parse | 0 gaps |

The contrast between the two height-recovery rows is instructive and is reported rather than hidden. Recovery succeeded in 25 of 27 configurations where the shadow displacement fitted within the analysis window and in **none** of the nine where it did not. This is the identifiability limit of Table 4 expressed empirically, and it has an operational consequence: a tiling scheme with tiles smaller than the displacement will silently misestimate shadow position for most clouds.

The test suite comprises 136 assertions across ten files and makes no network calls. Catalogue parsing is tested against fixtures constructed from real responses, including cases that broke earlier implementations: datetimes with fractional seconds; Landsat items carrying no MGRS fields, for which naive string concatenation produced an identical literal tile identifier across unrelated scenes; antimeridian tiles returned as MultiPolygon rather than Polygon, which an implementation handling only Polygon dropped entirely, removing precisely the high-latitude scenes availability analysis most needs; and items lacking a cloud-cover property, which are excluded with a warning rather than treated as clear.

## 4 | WORKED EXAMPLE: ANDONG, REPUBLIC OF KOREA

We demonstrate the complete workflow at a single site. The analysis takes about two minutes, downloads only metadata, and requires no account.

### 4.1 | Defining the analysis area

```r
library(cloudscape)
grid  <- cl_grid(res = 25000)
cells <- cl_grid_lookup(grid, 128.73, 36.57)
```

The study area comprises sixteen 25 km cells, 10,000 km² in total, spanning 127.997–129.034° E and 36.212–37.185° N. Every cell has an area of 625 km², identical at any latitude — the property that makes the result comparable with any other site.

The same ground is covered by three overlapping Landsat WRS-2 scenes and a smaller number of Sentinel-2 MGRS tiles of different size and placement (Figure 1). This is the concrete form of the argument in Section 2.3: a statistic reported per footprint is reported on a different unit for each sensor.

### 4.2 | Querying the archive

```r
items <- cl_search(aoi, "sentinel-2-msi", "2019-01-01", "2024-12-31")
obs   <- cl_items_to_obs(items, grid)
```

Over 2019–2024 the two constellations delivered 6,167 scenes, which collapsed to 19,366 cell-observations after tiles of a single overpass were merged (mean 1.38 products per observation).

### 4.3 | How much usable data exists

**Table 6.** Acquisitions and usable observations per cell-year at Andong.

| Year | Acquisitions | Usable | Mean cloud fraction |
|---|---|---|---|
| 2019 | 96 | 33 | 0.47 |
| 2020 | 96 | 35 | 0.45 |
| 2021 | 100 | 34 | 0.46 |
| 2022 | 110 | 38 | 0.48 |
| 2023 | 104 | 33 | 0.48 |
| 2024 | 98 | 33 | 0.48 |

About a third of acquisitions are usable, consistently across years. The longest annual gap without a usable image had a median of 49 days, a ninetieth percentile of 60 days and a worst case of 75 days.

### 4.4 | When the gap falls

The annual figures above suggest a workable site. The seasonal profile does not (Figure 2). The clearest conditions occur on day 332 (27 November), with a clear probability of 0.54 at the seasonal peak and 0.08 at the trough. Grouped by phenological period, the archive was 44% usable in the dormant season (November–February) but **12% in July and August**, a 6.9-fold swing whose minimum coincides with peak canopy development during the East Asian summer monsoon.

This is exactly the pattern that an annual cloud statistic conceals, and it is the reason the package reports monthly usability as a first-class output rather than a diagnostic.

### 4.5 | Retrieval error, and the value of the constellation

```r
cl_pheno_map(obs, year = 2024, n_sim = 200)
```

Using the actual acquisition dates of 2024, the median cell had 124 acquisitions of which 58 were usable, giving a start-of-season error of 1.0 day and no fit failures. Restricting the same cell to Sentinel-2 alone, as would have been the case before Landsat 9, reduces this to 76 acquisitions and 36 usable, with a 1% failure rate.

The counterfactual is the point of the exercise: the package quantifies what an additional mission is worth at a specific site, in the units of the study's own conclusion.

### 4.6 | Detection and shadow

Detection is demonstrated on a simulated scene because the truth is then known exactly. Solar geometry is taken from the site and date (`cl_solar_position` gives a zenith of 17.9° and azimuth of 134.0° at Andong on 15 June).

**Table 7.** Detector performance on a simulated scene with 30% cloud cover at Andong's mid-June solar geometry.

| Method | IoU | Recall | Accuracy | Calibration error |
|---|---|---|---|---|
| Threshold baseline | 0.600 | 0.600 | 0.880 | 0.162 |
| Decision cascade | 0.776 | 0.776 | 0.933 | 0.113 |

The cloud-top height planted by the simulator (2,500 m) was recovered exactly, and the shadow was recovered with an intersection over union of 1.000 (Figure 3).

Reporting calibration error alongside accuracy is deliberate. During development, an implementation that combined the cascade's tests as a weighted sum rather than as the conjunction the algorithm specifies achieved an area under the ROC curve of 1.000 — a perfect ranking — while its calibration error was 0.373 and its accuracy at the default threshold was 0.611, because clear land accumulated a score above the threshold. Reporting discrimination alone would have concealed a method that was operationally worse than useless.

### 4.7 | Sharing the result

`cl_explore()` writes a self-contained HTML map with no server dependency and no expiring URLs, so it can be archived alongside a manuscript.

## 5 | DISCUSSION

### 5.1 | Relationship to existing tools

cloudscape is not a competitor to Fmask, Sen2Cor, MAJA or s2cloudless. It is a layer above them: a consistent interface through which any of them can be invoked, an unbiased unit onto which their outputs are aggregated, and machinery for converting the aggregate into a feasibility statement. Its quality-layer reader translates bit-packed Landsat and categorical Sentinel-2 quality information into one class vocabulary, which is what makes masks from different producers directly comparable.

Relative to cloud-platform implementations the trade-off is explicit. Those offer planetary-scale computation; cloudscape offers reproducibility without authentication, a proprietary backend or an internet connection, with provenance recorded on every object. For establishing what a published statistic was computed from, the latter matters more.

### 5.2 | What the design choices buy

Each of the three principles has a measurable consequence rather than being a matter of taste. The equal-area unit removes a factor-of-four latitude gradient between the equator and 75°. The explicit evidence tier prevents a metadata-derived count being reported as though it were a pixel measurement. And the decision-unit output changes conclusions: at Andong, an annual usability of 34% looks adequate, while a July usability of 12% does not.

### 5.3 | Limitations

**No component has been evaluated against hand-labelled scenes.** All validation is against analytical identities and synthetic truth, which catches geometry and statistical errors — it caught fourteen during development — but cannot catch a wrong band mapping or a misread quality bit. Evaluation against CloudSEN12 (Aybar et al., 2022) is required before the detection components are relied upon operationally.

**Archive statistics are not a cloud climatology.** Acquisition is scheduled rather than random, and mask commission errors over snow, bright soil and sun glint are systematic. Archive-derived cloud fractions should not be interpreted as climatology without independent validation.

**Cross-sensor comparison compares algorithms as much as atmospheres.** This is a limitation of the data rather than the software, and one the package makes visible rather than resolves.

**The phenology module assumes a double-logistic trajectory.** Sites with multiple growing seasons or evergreen canopies are not well represented, and the errors reported are lower bounds on real-world retrieval error.

**Learned detection methods are registered but not implemented in version 0.1.0**, pending distribution of model weights through a companion data package.

## 6 | CONCLUSIONS

Cloud-masking software answers which pixels are cloudy. Researchers usually need to know whether a study will work. Making the spatial unit equal-area, making the evidence tier explicit and expressing results in the units of the user's own conclusion are three changes that can be implemented in software, and each measurably alters what a user concludes.

cloudscape is released under GPL-3 with 136 tests, a mechanically enforced architecture contract, complete documentation, four vignettes and a reproducible worked example, at https://github.com/ehsanrahimi666/cloudscape.

## SOFTWARE AVAILABILITY

**Name** cloudscape · **Developers** Ehsan Rahimi, Chuleui Jung · **Contact** ehsanrahimi666@gmail.com · **Year first available** 2026 · **Software required** R ≥ 4.1; optionally `terra`, `sf`, `httr2`, `jsonlite` · **Program language** R · **Program size** approximately 4,200 lines · **Licence** GPL-3 · **Availability** https://github.com/ehsanrahimi666/cloudscape

## AUTHOR CONTRIBUTIONS

**ER**: Conceptualisation, Methodology, Software, Validation, Writing — original draft. **CJ**: Conceptualisation, Supervision, Funding acquisition, Writing — review and editing.

## CONFLICT OF INTEREST

The authors declare no conflict of interest.

## REFERENCES

Aybar, C., Ysuhuaylas, L., Loja, J., Gonzales, K., Herrera, F., Bautista, L., Yali, R., Flores, A., Diaz, L., Cuenca, N., Espinoza, W., Prudencio, F., Llactayo, V., Montero, D., Sudmanns, M., Tiede, D., Mateo-García, G., & Gómez-Chova, L. (2022). CloudSEN12, a global dataset for semantic understanding of cloud and cloud shadow in Sentinel-2. *Scientific Data*, 9, 782. https://doi.org/10.1038/s41597-022-01878-2

Aybar, C., Wu, Q., Bautista, L., Yali, R., & Barja, A. (2020). rgee: An R package for interacting with Google Earth Engine. *Journal of Open Source Software*, 5(51), 2272. https://doi.org/10.21105/joss.02272

Brodzik, M. J., Billingsley, B., Haran, T., Raup, B., & Savoie, M. H. (2012). EASE-Grid 2.0: Incremental but significant improvements for Earth-gridded data sets. *ISPRS International Journal of Geo-Information*, 1(1), 32–45. https://doi.org/10.3390/ijgi1010032

Brodzik, M. J., Billingsley, B., Haran, T., Raup, B., & Savoie, M. H. (2014). Correction: EASE-Grid 2.0. *ISPRS International Journal of Geo-Information*, 3(3), 1154–1156. https://doi.org/10.3390/ijgi3031154

Cao, R., Chen, Y., Chen, J., Zhu, X., & Shen, M. (2020). Thick cloud removal in Landsat images based on autoregression of Landsat time-series data. *Remote Sensing of Environment*, 249, 112001. https://doi.org/10.1016/j.rse.2020.112001

Crawford, C. J., Roy, D. P., Arab, S., Barnes, C., Vermote, E., Hulley, G., et al. (2023). The 50-year Landsat collection 2 archive. *Science of Remote Sensing*, 8, 100103. https://doi.org/10.1016/j.srs.2023.100103

Li, Z., Shen, H., Cheng, Q., Liu, Y., You, S., & He, Z. (2019). Deep learning based cloud detection for medium and high resolution remote sensing images of different sensors. *ISPRS Journal of Photogrammetry and Remote Sensing*, 150, 197–212. https://doi.org/10.1016/j.isprsjprs.2019.02.017

Qiu, S., Zhu, Z., & Woodcock, C. E. (2020). Cirrus clouds that adversely affect Landsat 8 images: What are they and how to detect them? *Remote Sensing of Environment*, 246, 111884. https://doi.org/10.1016/j.rse.2020.111884

Rahimi, E., & Jung, C. (2024). Evaluating the applicability of Landsat 8 data for global time series analysis. *Frontiers in Remote Sensing*, 5, 1492534. https://doi.org/10.3389/frsen.2024.1492534

Shen, Y., Wang, Y., Lv, H., & Li, H. (2015). Removal of thin clouds using cirrus and QA bands of Landsat-8. *Photogrammetric Engineering & Remote Sensing*, 81(9), 721–731. https://doi.org/10.14358/pers.81.9.721

Zhang, Y., Woodcock, C. E., Arévalo, P., Olofsson, P., Tang, X., Stanimirova, R., et al. (2022). A global analysis of the spatial and temporal variability of useable Landsat observations at the pixel scale. *Frontiers in Remote Sensing*, 3, 894618. https://doi.org/10.3389/frsen.2022.894618

Zhu, X., & Helmer, E. H. (2018). An automatic method for screening clouds and cloud shadows in optical satellite image time series in cloudy regions. *Remote Sensing of Environment*, 214, 135–153. https://doi.org/10.1016/j.rse.2018.05.024

Zhu, Z., & Woodcock, C. E. (2012). Object-based cloud and cloud shadow detection in Landsat imagery. *Remote Sensing of Environment*, 118, 83–94. https://doi.org/10.1016/j.rse.2011.10.028

---

## FIGURE CAPTIONS

**Figure 1.** The study area at Andong. (a) Location on the Korean peninsula, with the analysis extent outlined. (b) The sixteen 25 km equal-area analysis cells, with the Landsat WRS-2 scenes and Sentinel-2 MGRS tiles that cover the same ground. Three units of different size and placement describe one piece of Earth; only the cells are comparable between sensors and across latitude.

**Figure 2.** Seasonal usability at Andong, 2019–2024. Each bar is the probability that an acquisition in that fortnight has a scene cloud fraction of 0.2 or less; the dashed line is the annual mean. The minimum in July and August coincides with peak canopy development.

**Figure 3.** Cloud and shadow detection on a simulated scene at Andong's mid-June solar geometry. From left: contaminated red reflectance; true cloud; cloud probability from the decision cascade; and true against detected shadow. The planted cloud-top height of 2,500 m was recovered exactly.

**Figure 4.** Every acquisition at Andong, 2019–2024, coloured by whether the scene cloud fraction falls below the usability threshold.
