# Live-endpoint checks. Deliberately kept out of tests/ because CRAN forbids
# network access during checks and because an upstream outage should not be
# reported as a package failure. Run manually or on CI.
library(cloudscape)
stopifnot(requireNamespace("httr2", quietly = TRUE))

aoi <- c(128.0, 35.5, 129.2, 36.2)   # Daegu region
cat("Backend:", cl_catalog()$url, "\n")

items <- cl_search(aoi, "sentinel-2-msi", "2024-06-01", "2024-06-30", limit = 50)
stopifnot(nrow(items) > 0, all(!is.na(items$datetime)))
cat("Sentinel-2 items:", nrow(items),
    "| median cloud:", round(median(items$cloud_cover, na.rm = TRUE), 1), "%\n")

ls_items <- cl_search(aoi, "landsat-8-9-oli", "2024-06-01", "2024-06-30", limit = 50)
cat("Landsat items:", nrow(ls_items), "\n")

grid <- cl_grid(res = 25000)
obs <- cl_items_to_obs(items, grid)
stopifnot(inherits(obs, "cl_obs"), nrow(obs) > 0)
print(summary(cl_clear_obs(obs, by = "month")))

# Every value must survive the unit validator
validate_cl_stats(cl_clear_obs(obs, by = "month"))
cat("\nIntegration check passed.\n")
