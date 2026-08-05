# cloudscape — architecture

This records what was decided and, more usefully, what was rejected and why.
It is written for whoever maintains the package next, including a future
version of the authors.

## 1. The problem

Cloud-masking software answers "which pixels are cloudy". Users are usually
asking something else: "can I do my study here". Bridging those requires three
things that existing tools leave to the user.

**An unbiased spatial unit.** WRS-2 scene area falls with latitude and orbital
side-lap rises from roughly 7% at the equator to over 50% near the poles.
Counting images per path/row therefore conflates acquisition density with
geometry, and does so most severely exactly where availability is lowest. It
also makes Landsat (185 × 180 km) incomparable with Sentinel-2 MGRS
(110 × 110 km).

**Honesty about evidence tiers.** Scene-level `eo:cloud_cover` is a footprint
average. Converting it to a per-pixel clear probability requires an assumption,
and the natural one — independence — is optimistic, because cloud is clustered.
Any conclusion from catalogue metadata is an upper bound, and the software
should say so rather than leaving it implicit.

**Translation into decision units.** "42.5% mean cloud" does not tell a
phenologist whether green-up is retrievable. "SOS error ±9 days, 68% of fits
fail" does.

## 2. Layers

A lower layer must never call into a higher one. This is enforced by
`tools/architecture.R` and asserted in `tests/testthat/test-architecture.R`,
because a contract that is only written down is an aspiration.

| Layer | Files | Role |
|---|---|---|
| 0 | `aaa-config.R`, `sensors.R`, `grid.R` | Foundation; depends on nothing in the package |
| 1 | `classes.R`, `catalog.R` | Data representation and access |
| 2 | `preprocess.R`, `shadow.R`, `probability.R`, `uncertainty.R` | Pixel-level processing |
| 3 | `availability.R`, `simulate.R`, `evaluate.R`, `phenology.R` | Analysis |
| 4 | `engine.R`, `viz.R` | Orchestration and output |

The check has already earned its place: `cl_obs()` was originally defined in
`availability.R` (layer 3) while `catalog.R` (layer 1) called it. It is a data
structure, so it moved to `classes.R`.

## 3. Decisions and rejected alternatives

### 3.1 EASE-Grid 2.0 as the analysis unit

**Chosen:** aggregate onto EPSG:6933, a cylindrical equal-area projection on
the WGS84 ellipsoid with standard parallel 30°. Footprints are import
geometries only.

**Rejected:** native footprints (the bias described above); H3 or DGGRID
hexagons (both add heavy or unstable dependencies, and `dggridR` has an
uncertain CRAN history); MODIS sinusoidal tiles (equal-area but sensor-specific).

**Consequence:** the projection is implemented in closed form in `grid.R` rather
than delegated to PROJ, so grid arithmetic and its tests run without a
geospatial toolchain. Verified to 4.7e-11 relative error against the true WGS84
surface area.

### 3.2 Heavy dependencies in `Suggests`, not `Imports`

**Chosen:** `terra`, `sf`, `httr2`, `jsonlite` are suggested and gated behind
`cl_require()`, which produces one actionable error at the point of use.

**Rationale:** the entire statistical core — availability, gaps, seasonality,
synergy, phenology, simulation, evaluation — is arithmetic on data frames and
matrices. A phenologist reading a pre-computed table should not need GDAL. The
test suite runs on base R alone, which also means it runs in environments where
the geospatial stack is unavailable.

**Cost:** unconventional; reviewers may object. The gain in installability and
testability is worth defending.

### 3.3 STAC via `httr2`, not `rgee` or `rstac`

**Rejected `rgee`:** requires interactive OAuth and a `reticulate` Python
environment. Neither survives `R CMD check` on CRAN or unattended CI, and the
paper's central claim is reproducibility.

**Rejected `rstac` as a hard dependency:** it is good software, but the Element84
search API is a small REST surface, and owning the request path means owning the
property normalisation and the retry semantics. `rstac` remains usable as an
alternative backend.

**Default backend:** Element84 Earth Search — no authentication, so the package
is demonstrable without credentials.

### 3.4 Two packages, not one

CRAN limits source tarball size. Model weights, benchmark imagery and the
pre-computed global dataset cannot ship there. Therefore:

- `cloudscape` (CRAN): all code, synthetic fixtures, documentation.
- `cloudscape.data` (r-universe / Zenodo DOI): weights, benchmark subsets,
  global statistics.

Learned methods are *registered* in the method table so `cl_methods()`
advertises them and the error message on use is actionable, rather than the
function simply not existing.

### 3.5 The global harvest is a data product, not a function call

A global tier-A harvest is tens of millions of paged requests over days against
provider rate limits. Exposing it as `cl_availability(aoi = "global")` would
invite accidental launches and make published statistics irreproducible, since
each run samples a shifting archive.

`data-raw/harvest-global.R` runs it once, resumably; the result is deposited
with a DOI and read instantly thereafter.

**Subtlety found during design:** bands must partition cells by *ownership*
(centroid within the band), not merely be queried and merged. A scene straddling
a band boundary is returned by both neighbouring queries, so merging aggregates
would double-count it. Ownership partitioning is exact: every cell is claimed
once, and every scene covering a claimed cell intersects that band's bounding
box and is therefore returned by its query.

### 3.6 One geometry kernel, two directions

`cl_shadow_offset()` maps cloud height and illumination geometry to a ground
displacement. The detector inverts it, searching heights for the displacement
that best explains observed dark pixels; the simulator applies it forwards,
casting a physically consistent shadow.

This prevents a specific failure: a synthetic benchmark that rewards a detector
for reproducing a geometry the simulator itself got wrong. Verified — the
detector recovers the exact height the simulator used, IoU 1.000.

### 3.7 Units enforced in the data structure

Every `cl_stats` row carries `unit`, `n` and `denominator`, validated on
construction against a controlled vocabulary. Each metric also declares how two
values *combine* (`sum`, `wmean`, `max`), because a maximum gap is neither
additive nor averageable, and combining fractions without weighting by sample
size gives the mean of means.

This exists because a total across ten years divided by ten is a mean **per
year**, not a mean per scene, and the two are trivially confused in a plain
data frame. Encoding the denominator makes that a validation error rather than
a published table.

### 3.8 Persistence as autocorrelation, not as a multiplier

Cloud occurrence is generated by a two-state chain with marginal `p` and lag-1
autocorrelation `ρ`:

```
p11 = p + (1 - p)ρ        p01 = p(1 - ρ)
```

whose stationary probability is exactly `p` for every `ρ ∈ [0, 1)`.

**Rejected:** persistence as a transition multiplier (`p11 = p × k`). It must be
clamped at high cloud fractions, and the clamped chain then mixes so slowly that
a one-year series never leaves its initial state — the implementation reported
all 73 acquisitions usable at 80% cloud before this was found.

## 4. What is deliberately not here

- **A new cloud-detection algorithm.** The field has enough. The contribution is
  the framework, the equal-area statistics, and the translation into decision
  units.
- **Gap filling or compositing.** Adjacent, well-served by other packages, and it
  would obscure the question of how much real data exists.
- **Atmospheric correction.** Providers do this; duplicating it invites
  disagreement with the official product for no gain.

## 5. Known limitations

- Archive statistics are **not a cloud climatology**. Acquisition is scheduled,
  not random, and mask commission over snow, bright soil and sun glint is
  systematic. Independent validation against MODIS MOD35/MCD06 or CALIPSO is
  outstanding.
- Cross-sensor cloud comparisons compare *algorithms* as much as atmospheres:
  Landsat `CLOUD_COVER` comes from CFMask, Sentinel-2 `eo:cloud_cover` from
  Sen2Cor.
- Processing baselines changed during 2014–2023, so apparent temporal trends in
  archive-derived cloud statistics are partly reprocessing artefacts. This is
  why every object carries a manifest.
- `method = "centroid"` footprint indexing is unbiased in expectation but
  approximate when cell size approaches footprint size; use `method = "area"`
  (requires `sf`) in that regime.
- Nothing here has yet touched a real satellite scene. Every result is validated
  against analytical identities and synthetic truth, which catches geometry and
  statistics errors but **cannot** catch a wrong band mapping or a misread QA
  bit. `tools/integration-check.R` is the real test.
