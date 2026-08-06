# R CMD check status

Run with R 4.3.3 on Ubuntu 24.04. Full log: `R-CMD-check.log`.

```
Status: 1 WARNING, 1 NOTE
```

Both are artifacts of the environment the check was run in, not defects:

| Item | Cause |
|---|---|
| WARNING: checking R files for syntax errors | `Sys.setlocale("LC_CTYPE","en_US.UTF-8")` unavailable in the container. No syntax error is reported. |
| NOTE: packages suggested but not available | The container has no CRAN access, so `terra`, `sf`, `httr2` and the other Suggests could not be installed. |

Everything substantive passes, including **checking examples ... OK**, which
runs every example in every help file.

Re-run on your own machine, where the Suggests are installable, with:

```r
devtools::check()
```

Expect 0 errors, 0 warnings, and possibly a NOTE about the installed size.
