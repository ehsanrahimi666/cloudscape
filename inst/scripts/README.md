# Scripts shipped with cloudscape

These install with the package, so they can be located without cloning the
repository:

```r
system.file("scripts", "check-install.R",     package = "cloudscape")
system.file("scripts", "run-real-analysis.R", package = "cloudscape")
```

| Script | Purpose |
|---|---|
| `check-install.R` | Verify the installation and test live catalogue access |
| `run-real-analysis.R` | Harvest a stratified sample and produce the manuscript's archive-based results |
| `HOW-TO-RUN.md` | Step-by-step instructions for the above |

Run either from R:

```r
source(system.file("scripts", "check-install.R", package = "cloudscape"))
```

or from a shell:

```bash
Rscript -e 'source(system.file("scripts","check-install.R", package="cloudscape"))'
```
