test_that("shadow offset matches closed-form geometry", {
  for (z in c(0, 30, 45, 60, 75)) {
    o <- cl_shadow_offset(1000, z, 180)
    expect_equal(sqrt(sum(o^2)), 1000 * tan(z * pi / 180), tolerance = 1e-8)
  }
  expect_gt(cl_shadow_offset(1000, 45, 180)[, "dy"], 0)
  expect_lt(cl_shadow_offset(1000, 45, 0)[, "dy"], 0)
  expect_lt(cl_shadow_offset(1000, 45, 90)[, "dx"], 0)
  expect_gt(cl_shadow_offset(1000, 45, 270)[, "dx"], 0)
})

test_that("simulator and detector agree on geometry", {
  s <- cl_simulate(100, 100, coverage = 0.25, height = 2500, res = 30,
                   sun_zenith = 45, sun_azimuth = 160, seed = 42)
  r <- cl_shadow_project(s$cloud, s$shadow, res = 30, sun_zenith = 45,
                         sun_azimuth = 160, heights = seq(500, 6000, by = 100))
  expect_equal(r$height, 2500, tolerance = 200)
  v <- cl_validate(r$shadow, s$shadow)
  expect_gt(v$iou[v$class == "1"], 0.9)
})

test_that("terrain shadow respects sun direction", {
  dem <- matrix(0, 40, 40); dem[, 30:40] <- 600
  east <- cl_terrain_shadow(dem, 75, 90, res = 30)
  expect_gt(sum(east), 0)
  expect_equal(sum(cl_terrain_shadow(dem, 75, 270, res = 30)), 0)
  expect_true(all(which(east == 1, arr.ind = TRUE)[, 2] < 30))
})

test_that("cloud height from thermal contrast matches the lapse-rate identity", {
  bt <- matrix(300, 50, 50)
  cl <- matrix(FALSE, 50, 50); cl[20:30, 20:30] <- TRUE
  bt[cl] <- 280
  expect_equal(cl_cloud_height(bt, cl)$height, 20 / 0.0065, tolerance = 1)
  expect_true(is.na(cl_cloud_height(NULL, cl)$height))
})

test_that("clamping preserves matrix dimensions", {
  # pmax(0, m) drops dim(); .cs_clamp() must not. A shadow index that
  # silently became a vector produced a dimension-mismatch error far from
  # its cause, so this is a regression guard.
  m <- matrix(1:12, 3, 4)
  expect_equal(dim(cloudscape:::.cs_clamp((5 - m) / 5)), c(3L, 4L))
  d <- cloudscape:::.cs_darkness(matrix(0.3, 8, 8), matrix(0.2, 8, 8))
  expect_equal(dim(d), c(8L, 8L))
})

test_that("darkness is near zero over clear land and high in shadow", {
  s <- cl_simulate(64, 64, coverage = 0.25, opacity = 1, height = 2200,
                   res = 30, sun_zenith = 42, sun_azimuth = 155, seed = 7,
                   background = list(nir = matrix(0.32, 64, 64),
                                     swir16 = matrix(0.20, 64, 64)))
  d <- cloudscape:::.cs_darkness(s$bands$nir, s$bands$swir16, cloud = s$cloud)
  clear <- s$cloud == 0 & s$shadow == 0
  # Referencing the clear-sky median, not a scene-wide stretch, is what keeps
  # clear land from being scored as shadow when bright cloud is present.
  expect_lt(mean(d[clear]), 0.05)
  expect_gt(mean(d[s$shadow > 0]), mean(d[clear]) + 0.1)
})

test_that("a shadow displaced beyond the window is reported, not guessed", {
  # Displacement is height * tan(zenith). With a 96 x 96 window at 30 m and a
  # 65 degree sun, a 4800 m cloud casts its shadow 343 pixels away: entirely
  # outside the scene. The search would otherwise settle on the shortest
  # candidate height, which is indistinguishable from a genuine low cloud.
  cloud <- matrix(0, 96, 96); cloud[40:56, 40:56] <- 1
  dark <- matrix(0, 96, 96)
  expect_warning(
    r <- cl_shadow_project(cloud, dark, res = 30, sun_zenith = 65,
                           sun_azimuth = 150, heights = seq(200, 6000, by = 50)),
    "not identifiable")
  expect_true(r$truncated)
  expect_lt(r$resolvable_m, max(seq(200, 6000, by = 50)))

  # A window large enough for the same search range must not warn
  big <- matrix(0, 400, 400); big[190:210, 190:210] <- 1
  r2 <- cl_shadow_project(big, big, res = 30, sun_zenith = 25,
                          sun_azimuth = 150, heights = seq(200, 2000, by = 50))
  expect_false(r2$truncated)
})

test_that("height is recovered exactly when the window is adequate", {
  cases <- expand.grid(h = c(600, 1200, 2400), zen = c(25, 45, 65))
  err <- vapply(seq_len(nrow(cases)), function(i) {
    h <- cases$h[i]; z <- cases$zen[i]
    # Size the window to the displacement, as an operational tiling scheme must
    npx <- ceiling(3 * h * tan(z * pi / 180) / 30)
    npx <- max(96L, min(400L, npx))
    s <- cl_simulate(npx, npx, coverage = 0.12, opacity = 1, height = h,
                     res = 30, sun_zenith = z, sun_azimuth = 150, seed = 9)
    r <- suppressWarnings(
      cl_shadow_project(s$cloud, s$shadow, res = 30, sun_zenith = z,
                        sun_azimuth = 150, heights = seq(200, 6000, by = 50)))
    abs(r$height - h)
  }, numeric(1))
  expect_lte(max(err), 50)   # one height step
})
