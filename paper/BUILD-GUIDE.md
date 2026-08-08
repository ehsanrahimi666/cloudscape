# Build guide for the two manuscripts

Working document. Written for whoever rebuilds these papers, which is me.
Updated 7 August 2026.

---

## 0 | What went wrong in the first drafts, and must not recur

1. **No figures were embedded.** The markdown carried no image references, so
   pandoc placed nothing. Twenty PNGs existed on disk and none reached the
   document. Every figure must appear inline, at its point of first citation,
   with the caption immediately below.
2. **Tables used pandoc's default grid**, not the template's table style.
   Convert with `--reference-doc` *and* verify a rendered table page before
   shipping.
3. **The template was the wrong one.** `pollmap_REVISED_Ecological_Processes.docx`
   failed to upload (I/O error) and the GEB manuscript was substituted without
   flagging it prominently enough. Confirm which template before converting.
4. **A placeholder caption was left in the text** (Paper 1, Figure 14) because
   the global data could not be read. Never ship a caption without its figure.

**Check before delivery:** render to PDF, open at least one table page and one
figure page, and confirm both by eye.

---

## 1 | Asset inventory

### 1.1 Available now, verified

Deep harvest, 2013–2025, 24 sites, 384 cells, 3 sensors, 724,050
cell-observations. QC 14 passed / 0 failed.

**Figures** — `/tmp/fig2/figures/*.png` and `.pdf`

| File | Shows |
|---|---|
| `F1_acquisition_density` | Acquisitions per cell-year against latitude, with nominal 192 line |
| `F2_cloud_and_gaps` | Cloud fraction and longest annual gap against latitude |
| `F3_persistence` | τ by regime; run length vs cloud (+0.94); τ vs cloud (−0.67) |
| `F4_cross_sensor` | S2 vs Landsat scatter (r = 0.834) and difference histogram |
| `F5_phenology` | SOS error and failure rate against usable observations |
| `F6_seasonality` | Day of year of clearest conditions against latitude |
| `F7_measured_vs_nominal` | Measured acquisitions, measured clear, nominal model, 2013–2025 |
| `F8_feasibility_crossover` | Usable obs per year; % of cells retrievable — the 2018 step |
| `F9_offset_structure` | S2 − Landsat binned by cloud amount, with CIs |
| `F10_reported_cloud_drift` | Reported cloud by year, three chains, same cells |
| `F11_seasonal_blind_spots` | Regime × month usability heatmap, crosses below 0.15 |
| `F12_blind_spot_vs_annual` | Seasonal ratio against annual usability (−0.50 cells) |
| `F13_shape_dependence` | Peak day, parametric vs spline |

**Tables** — `/tmp/fig2/tables/*.csv`

| File | Contents |
|---|---|
| `T1_persistence_by_regime` | 17 regimes: cloud, ρ, lag, τ, run length |
| `T2_availability_by_latitude` | 10 bands × 3 sensors: acquisitions, clear, cloud |
| `T3_gaps_by_regime` | Clear obs, median and p90 longest gap |
| `T4_cross_sensor` | Mean difference, CI, correlation, n |
| `T5_phenology_by_regime` | Usable obs, SOS error, IQR, failure rate |
| `T6_feasibility_by_year` | 13 years: usable, SOS error, failure, % retrievable |
| `T7_crossover_by_regime` | Median crossover year per regime |
| `T8_reported_cloud_by_year` | 35 rows, sensor × year, with adequacy flag |
| `T9_usability_by_month` | 197 rows, regime × month |
| `T10_blind_spots` | 14 regimes: annual, worst month, ratio, blind months |
| `T11_shape_dependence` | 347 cells: SOS and peak divergence |
| `T12_reported_cloud_trends` | Trend per chain, adequately sampled years only |
| `TS1_sites` | 24 sites: name, lon, lat, regime, cells |

**Worked example, Andong** — user has these; W1–W3 PNG, W4 HTML, E1–E7 CSV.

| File | Shows |
|---|---|
| `W1_timeline` | Every acquisition 2019–2024, coloured by usability |
| `W2_seasonal_clear` | Fortnightly usability — the July collapse |
| `W3_detection` | Contaminated red, true cloud, fmask probability, shadow |
| `W4_map.html` | Interactive map of usable observations per cell |

### 1.2 Pending

| Asset | Script | Status |
|---|---|---|
| `M1_study_area` | `study-area-map.R` | **Not yet run.** Andong on Korea + cells vs footprints |
| `M2_unit_comparison` | `study-area-map.R` | **Not yet run.** Three units over one piece of ground |
| `M3_global_sites` | `study-area-map.R` | **Not yet run.** 24 sites by regime |
| `G_*` global maps | `global-map.R` | **Re-running at 3°.** Previous run was 60 points, unusable |
| `G_latitude_profiles` | `global-map.R` | New in the upgraded script |

---

## 2 | Paper 1 — global multi-sensor analysis

**Working title.** Three cloud-masking chains disagree about how cloudy the
Earth is becoming: a multi-sensor assessment of optical observation
availability, 2013–2025.

**Target.** Global Ecology and Biogeography, or Remote Sensing of Environment.
Structured abstract (Aim / Location / Time period / Major taxa / Methods /
Results / Main conclusions / Keywords) if GEB.

**The argument in one line.** Producer cloud statistics are not interchangeable
between missions, the disagreement is growing, and it is large enough to be
mistaken for a climate signal.

### Figure allocation

| Manuscript | Source | Section |
|---|---|---|
| Figure 1 | `M3_global_sites` | 2.2 Sites |
| Figure 2 | `G_cloud_by_sensor` (3°) | 3.1 |
| Figure 3 | `G_usable_by_sensor` (3°) | 3.1 |
| Figure 4 | `G_latitude_profiles` | 3.1 |
| Figure 5 | `F2_cloud_and_gaps` | 3.1 |
| Figure 6 | `F3_persistence` | 3.2 |
| Figure 7 | `F11_seasonal_blind_spots` | 3.3 |
| Figure 8 | `F12_blind_spot_vs_annual` | 3.3 |
| Figure 9 | `F8_feasibility_crossover` | 3.4 |
| Figure 10 | `F4_cross_sensor` | 3.5 |
| Figure 11 | `G_sensor_difference` (3°) | 3.5 |
| Figure 12 | `F9_offset_structure` | 3.5 |
| **Figure 13** | `F10_reported_cloud_drift` | **3.5 — the headline** |
| Figure 14 | `F13_shape_dependence` | 3.6 |

Supplementary: `F1`, `F5`, `F6`, `F7`.

### Table allocation

| Manuscript | Source |
|---|---|
| Table 1 | `T2_availability_by_latitude` |
| Table 2 | `T3_gaps_by_regime` |
| Table 3 | `T1_persistence_by_regime` |
| Table 4 | `T10_blind_spots` |
| Table 5 | `T6_feasibility_by_year` |
| **Table 6** | `T12_reported_cloud_trends` — **the headline** |
| Table S1 | `TS1_sites` |
| Table S2 | `T7_crossover_by_regime` |
| Table S3 | `G5_latitude_profile` |

### Key numbers, already derived — do not recompute

- Harvest: 291,728 scene records → 724,050 cell-observations, 384 cells,
  888 fetches (801 with data, 87 legitimately empty).
- Platforms: Landsat 7 (20,829), 8 (35,073), 9 (11,770), S2A (104,077),
  S2B (110,249), S2C (9,730).
- **Trends:** Landsat 4–7 −0.00494 yr⁻¹ (p = 0.039, 11 yr); Landsat 8/9
  +0.00198 (p = 0.078, 13 yr); Sentinel-2 **+0.01679 (p = 0.003, 9 yr)**.
- Cross-sensor: +0.0609 (95% CI 0.0573–0.0646), r = 0.834, n = 3,519.
- Offset structure: vs cloud −0.096 (p = 8×10⁻²⁰); vs |lat| p = 0.396;
  vs year +0.0115 (p = 9×10⁻⁶⁵); R² = 0.096.
- Global (60-point pilot, to be superseded): +0.0823 (CI 0.0701–0.0945),
  positive at 59/60, r with |lat| = 0.469.
- Persistence: τ 13.10 d (tropical wet-dry) → 0.74 d (high Arctic);
  τ vs cloud ρ_s = −0.67; run vs cloud ρ_s = +0.94.
- Blind spots: 139/328 cells ≥ 2 months; median ratio 3.8×; annual usability
  vs seasonal ratio ρ_s = −0.67 (regimes), −0.50 (cells).
- **Tropical wet-dry:** annual 0.512, July 0.026, ratio 36.1, 3 blind months.
- Feasibility: 75.5% (2013) → 100% (2018). Crossover 2013 for 13 regimes,
  2015 tropical monsoon, 2017 subpolar oceanic and tropical rainforest,
  2018 high Arctic.
- Shape dependence: SOS divergence 2.2 d, **peak divergence 9.4 d**,
  vs blind months ρ_s = 0.38, n = 347.
- Grid validation: 4.7 × 10⁻¹¹ relative area error.

### Reviewer objections to pre-empt

- *24 sites, several regimes on one location.* State it in Limitations; the
  3° global run answers it for the cross-sensor claim.
- *Metadata not pixels.* Stated as an upper bound throughout; cite Zhang
  et al. (2022) for the pixel-scale analysis.
- *Diurnal timing confound.* S2 and Landsat do not overpass at the same local
  time; part of the offset may be cloud development, not algorithm. Must be
  conceded explicitly.
- *Reprocessing not demonstrated.* Leading hypothesis, not shown. Do not
  overclaim.

---

## 3 | Paper 2 — the R package

**Working title.** cloudscape: an R package for assessing whether an optical
satellite time-series analysis is possible before undertaking it.

**Target.** Methods in Ecology and Evolution, or Environmental Modelling and
Software.

**The argument in one line.** Three design choices — equal-area unit, explicit
evidence tier, decision-unit output — measurably change what a user concludes,
and each is implementable in software.

### Figure allocation

| Manuscript | Source | Section |
|---|---|---|
| Figure 1 | `M1_study_area` | 4.1 — location and cells vs footprints |
| Figure 2 | `M2_unit_comparison` | 2.3 — three units, one piece of ground |
| Figure 3 | `W1_timeline` | 4.2 — every acquisition |
| Figure 4 | `W2_seasonal_clear` | 4.4 — the July collapse |
| Figure 5 | `W3_detection` | 4.6 — cloud and shadow |
| Figure 6 | `F3_persistence` (upper panel only) | 2.7 |

### Table allocation

| Manuscript | Contents |
|---|---|
| Table 1 | Capabilities and principal functions — hand-written |
| Table 2 | Module layers — hand-written |
| Table 3 | Sensor drivers — hand-written |
| Table 4 | Maximum resolvable cloud-top height — hand-written |
| Table 5 | Validation summary — hand-written |
| Table 6 | Andong acquisitions and usable per year — from `E2` |
| Table 7 | Detector performance — from `E7` |

### Key numbers, already derived

- Andong: 128.73 E, 36.57 N; 16 cells, 10,000 km²; extent 127.997–129.034 E,
  36.212–37.185 N. Site sits 71% across, 37% up — not centred, by construction.
- 6,167 scenes 2019–2024 → 19,366 cell-observations; 1.38 products per
  observation.
- ~100 acquisitions/cell-year, ~34 usable (34%).
- Gaps: median 49 d, p90 60 d, worst 75 d.
- Clearest day 332 (27 Nov); clear probability 0.54 peak, 0.08 trough.
- **Dormant Nov–Feb 44% usable; July–Aug 12%. 6.9× swing at peak biomass.**
- 2024 retrieval: 124 acquisitions, 58 usable, SOS error 1.0 d, 0% failure.
  Sentinel-2 alone: 76 acquisitions, 36 usable, 1% failure.
- Detection: threshold IoU 0.600, ECE 0.162; cascade IoU 0.776, ECE 0.113.
  Height 2,500 m recovered exactly; shadow IoU 1.000.
- Solar geometry at Andong 15 June: zenith 17.9°, azimuth 134.0°.
- Package: 136 tests, 0 layer violations, 0 doc gaps, R CMD check clean
  (1 locale warning, 1 Suggests note, both environment artefacts).
- Height recovery: 36/36 window sized to geometry; **24/36 fixed 2.9 km
  window** — 25/27 when the shadow fits, 0/9 when it does not.

### Anecdotes that earn their place

- The weighted-sum Fmask composite: AUC 1.000, ECE 0.373, accuracy 0.611.
  Discrimination alone would have hidden it. Keep — it justifies reporting
  calibration.
- `structure(NULL, ...)`: a deprecation warning on R 4.3, a hard error on
  R 4.6. Only surfaced on the user's machine. Keep in Limitations as an
  argument for testing across versions.
- Overpass collapsing: counting tiles as observations inflated Sentinel-2
  counts. Keep in Methods — it is a trap others will fall into.

---

## 4 | Build procedure

1. Confirm the template. If `pollmap_REVISED_Ecological_Processes.docx` is
   readable, use it; otherwise say plainly which was used.
2. Write markdown with `![](path/to/figure.png)` at each first citation,
   caption immediately below in bold **Figure N.** form.
3. Convert: `pandoc paper.md -o paper.docx --reference-doc=<template>.docx
   --from=markdown+pipe_tables`.
4. Render to PDF, inspect one table page and one figure page.
5. Check every citation resolves to a reference and every reference is cited.
6. Zip supplementary: figures, tables, harvest CSVs, scripts, QC report,
   DESIGN.md, R CMD check log.

## 5 | Reference pool, verified

Aybar et al. 2022 (CloudSEN12); Aybar et al. 2020 (rgee); Brodzik et al. 2012
and 2014 (EASE-Grid 2.0); Cao et al. 2020; Crawford et al. 2023; Holden and
Woodcock 2016; Li et al. 2019; Qiu et al. 2020; Rahimi and Jung 2024
(Frontiers); Shen et al. 2015; Whitcraft et al. 2015; Xu et al. 2022; Zhang
et al. 2022; Zhu and Helmer 2018; Zhu and Woodcock 2012.

Not yet verified, cited by name only, must be added with checked details
before submission: Foga et al. (CFMask validation); Main-Knorn et al.
(Sen2Cor); Hagolle et al. (MAJA); Vermote et al. (LaSRC); Frantz (FORCE);
Gorelick et al. (GEE); Claverie et al. (HLS); Drusch et al. (Sentinel-2).

**Rule: no citation enters the text without a full reference entry.**
