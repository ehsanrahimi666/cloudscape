# The layer contract is part of the design, so it is asserted, not merely
# documented. This test caught cl_obs() sitting in the analysis module while
# the catalogue reader depended on it.

test_that("no lower layer depends on a higher one", {
  skip_on_cran()
  src <- system.file("R", package = "cloudscape")
  root <- if (nzchar(src)) src else "../../R"
  skip_if_not(dir.exists(root), "source directory unavailable")
  source(file.path(dirname(root), "tools", "architecture.R"), local = TRUE)
  v <- cs_check_layers(root)
  expect_equal(nrow(v), 0L)
})

test_that("every source file is assigned to a layer", {
  skip_on_cran()
  root <- "../../R"
  skip_if_not(dir.exists(root), "source directory unavailable")
  source("../../tools/architecture.R", local = TRUE)
  files <- basename(list.files(root, pattern = "\\.R$"))
  expect_setequal(files, names(cs_layers()))
})

test_that("exported functions document their arguments and return value", {
  skip_on_cran()
  root <- "../../R"
  skip_if_not(dir.exists(root), "source directory unavailable")
  source("../../tools/architecture.R", local = TRUE)
  expect_equal(nrow(cs_check_docs(root)), 0L)
})
