# ---------------------------------------------------------------------------
# STAC response fixtures.
#
# Built as R lists, exactly as jsonlite::fromJSON(simplifyVector = FALSE) would
# return them, so that the catalogue parser can be tested without a network
# call, without jsonlite, and without httptest2. Values are copied from real
# Element84 Earth Search responses, including the awkward parts: fractional
# seconds in datetimes, Landsat items that carry no MGRS fields, Sentinel-2
# items that carry no WRS path/row, and antimeridian tiles returned as
# MultiPolygon rather than Polygon.
# ---------------------------------------------------------------------------

cs_fixture_s2_item <- function(id = "S2A_52SDG_20240615_0_L2A",
                               dt = "2024-06-15T02:31:29.024000Z",
                               cloud = 37.42,
                               lon0 = 128.0, lat0 = 35.5,
                               lon1 = 129.0, lat1 = 36.4) {
  list(
    type = "Feature",
    id = id,
    collection = "sentinel-2-l2a",
    geometry = list(
      type = "Polygon",
      coordinates = list(list(
        list(lon0, lat0), list(lon1, lat0), list(lon1, lat1),
        list(lon0, lat1), list(lon0, lat0)
      ))
    ),
    properties = list(
      datetime = dt,
      platform = if (grepl("^S2B", id)) "sentinel-2b" else "sentinel-2a",
      constellation = "sentinel-2",
      `eo:cloud_cover` = cloud,
      `view:sun_elevation` = 68.31,
      `view:sun_azimuth` = 128.77,
      `mgrs:utm_zone` = 52L,
      `mgrs:latitude_band` = "S",
      `mgrs:grid_square` = "DG",
      `s2:processing_baseline` = "05.10"
    ),
    assets = list(
      blue = list(href = "https://example.invalid/B02.tif", type = "image/tiff"),
      nir  = list(href = "https://example.invalid/B08.tif", type = "image/tiff"),
      scl  = list(href = "https://example.invalid/SCL.tif", type = "image/tiff")
    )
  )
}

cs_fixture_landsat_item <- function(id = "LC09_L2SP_115035_20240612_02_T1",
                                    dt = "2024-06-12T02:07:41.123456Z",
                                    cloud = 12.0, cloud_land = 9.5) {
  list(
    type = "Feature",
    id = id,
    collection = "landsat-c2-l2",
    geometry = list(
      type = "Polygon",
      coordinates = list(list(
        list(127.6, 35.1), list(129.9, 35.4), list(129.5, 37.2),
        list(127.2, 36.9), list(127.6, 35.1)
      ))
    ),
    properties = list(
      datetime = dt,
      platform = "landsat-9",
      `eo:cloud_cover` = cloud,
      `landsat:cloud_cover_land` = cloud_land,
      `landsat:wrs_path` = "115",
      `landsat:wrs_row` = "035",
      `landsat:collection_category` = "T1",
      `view:sun_elevation` = 66.02,
      `view:sun_azimuth` = 120.45,
      `view:off_nadir` = 0.0
    ),
    assets = list(
      blue     = list(href = "https://example.invalid/B2.TIF"),
      lwir11   = list(href = "https://example.invalid/B10.TIF"),
      qa_pixel = list(href = "https://example.invalid/QA_PIXEL.TIF")
    )
  )
}

# An antimeridian-crossing tile. Catalogues return these as MultiPolygon, which
# is a different nesting depth from Polygon and is a common cause of silent
# breakage in footprint handling.
cs_fixture_multipolygon_item <- function(id = "S2B_01VCK_20240701_0_L2A") {
  list(
    type = "Feature", id = id, collection = "sentinel-2-l2a",
    geometry = list(
      type = "MultiPolygon",
      coordinates = list(
        list(list(list(179.2, 60.1), list(180.0, 60.1),
                  list(180.0, 61.0), list(179.2, 61.0), list(179.2, 60.1))),
        list(list(list(-180.0, 60.1), list(-179.4, 60.1),
                  list(-179.4, 61.0), list(-180.0, 61.0), list(-180.0, 60.1)))
      )
    ),
    properties = list(
      datetime = "2024-07-01T23:14:02Z", platform = "sentinel-2b",
      `eo:cloud_cover` = 88.1,
      `mgrs:utm_zone` = 1L, `mgrs:latitude_band` = "V", `mgrs:grid_square` = "CK"
    ),
    assets = list(blue = list(href = "https://example.invalid/B02.tif"))
  )
}

# An item missing optional properties entirely, which happens for older
# reprocessed scenes and for some providers.
cs_fixture_sparse_item <- function(id = "SPARSE_0001") {
  list(
    type = "Feature", id = id, collection = "sentinel-2-l2a",
    geometry = list(type = "Polygon", coordinates = list(list(
      list(10.0, 45.0), list(11.0, 45.0), list(11.0, 46.0),
      list(10.0, 46.0), list(10.0, 45.0)))),
    properties = list(datetime = "2019-03-02T10:00:00Z"),
    assets = list()
  )
}

cs_fixture_collection <- function() {
  list(
    cs_fixture_s2_item(),
    cs_fixture_s2_item(id = "S2B_52SDG_20240620_0_L2A",
                       dt = "2024-06-20T02:31:31.500000Z", cloud = 4.1),
    cs_fixture_s2_item(id = "S2A_52SDG_20240625_0_L2A",
                       dt = "2024-06-25T02:31:28.900000Z", cloud = 91.7),
    cs_fixture_sparse_item()
  )
}
