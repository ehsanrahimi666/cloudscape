# What to run, in order

## 1. Test the connection (30 seconds)

```r
install.packages(c("remotes", "httr2", "jsonlite"))
remotes::install_github("ehsanrahimi666/cloudscape")
```

```bash
Rscript paper/run-real-analysis.R --mode test
```

Expect: a few hundred acquisitions from 3 sites. If this fails, the message
will say why; nothing else will work until it passes.

## 2. Pilot (15–30 minutes)

```bash
Rscript paper/run-real-analysis.R --mode pilot
```

24 sites, 2021–2024. Produces every result table in miniature. Look at
`paper/real-results/R3_persistence_by_regime.csv` — if the `mean_rho` column
varies sensibly between climate regimes, the full run is worth doing.

## 3. Full analysis (2–5 hours)

```bash
Rscript paper/run-real-analysis.R --mode full
```

120 sites, 2016–2024. **Resumable**: if it stops for any reason, run the same
command again and it continues from where it stopped.

## 4. Send back

One file:

```
paper/real-results/cloudscape-results-YYYYMMDD.zip
```

CSV summaries and a run manifest only. No imagery is downloaded at any point.

## If something goes wrong

| Symptom | Cause | Fix |
|---|---|---|
| `could not find function "cl_search"` | package not installed | re-run `remotes::install_github` |
| `requires the 'httr2' package` | missing dependency | `install.packages(c("httr2","jsonlite"))` |
| Many `transient error, retrying` | rate limiting | normal; it backs off and continues |
| `No data harvested` | connection blocked | try `--backend planetary` |
| Stops partway | anything | re-run the same command |

Progress is printed every 10 requests with a projected time remaining.
