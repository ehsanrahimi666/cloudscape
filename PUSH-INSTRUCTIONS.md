# Updating your GitHub repository

This archive **is** the repository, `.git` history included (5 commits). It is
already connected to nothing, so you attach it to your remote once.

## If you keep your existing local clone (recommended)

Your clone at `C:\Users\USER\Documents\GitHub\cloudscape` already has `origin`
set and tracks `main`. Replace its contents with this archive's, then push:

```bash
cd C:\Users\USER\Documents\GitHub\cloudscape
```

Delete everything in that folder EXCEPT the `.git` directory, copy in
everything from this archive EXCEPT its `.git` directory, then:

```bash
git add -A
git commit -m "Fix Rd generation; R CMD check now clean"
git push
```

## If you would rather start from this archive

```bash
# extract somewhere, then:
cd cloudscape
git remote add origin https://github.com/ehsanrahimi666/cloudscape.git
git branch -M main
git push -u --force origin main
```

`--force` overwrites the remote history with this one.

## Then, on GitHub

Settings → General → Default branch → make sure it is `main`, and delete the
old `master` branch if it is still there. `install_github()` installs from the
default branch, so this matters.

## Then reinstall

```r
# restart R first: a loaded package cannot be replaced on Windows
remotes::install_github("ehsanrahimi666/cloudscape",
                        force = TRUE, build_vignettes = TRUE)
source(system.file("scripts", "check-install.R", package = "cloudscape"))
```

Expect **34 passed, 0 failed**.
