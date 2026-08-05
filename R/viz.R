# ---------------------------------------------------------------------------
# Module 12: visualisation and export
# ---------------------------------------------------------------------------

#' Quick look at a mask or scene
#'
#' @param x A `cl_maskset`, `cl_scene` or matrix.
#' @param what For a maskset, `"probability"`, `"class"` or `"shadow"`.
#' @param ... Passed to [graphics::image()].
#' @return Invisibly `x`.
#' @export
cl_visualize <- function(x, what = c("probability", "class", "shadow"), ...) {
  what <- match.arg(what)
  m <- if (inherits(x, "cl_maskset")) x[[what]] else .cs_as_matrix(x)
  cl_assert(!is.null(m), "Layer '", what, "' is not present.")
  graphics::image(t(m[nrow(m):1, , drop = FALSE]), axes = FALSE,
                  col = grDevices::grey.colors(64), ...)
  invisible(x)
}

#' Export an interactive map of grid statistics
#'
#' Writes a self-contained HTML file showing one metric per grid cell. The
#' output has no server dependency and no expiring URLs, so it can be archived
#' alongside a manuscript and will still work years later. Live imagery
#' browsing is a different problem with different constraints and belongs in
#' [cl_app()].
#'
#' @param stats A `cl_stats` table.
#' @param metric Metric to display.
#' @param period Optional period filter.
#' @param file Output path.
#' @param grid The `cl_grid` the cells refer to; taken from `stats` if absent.
#' @param palette Colour ramp endpoints.
#' @param title Map title.
#' @return The output path, invisibly.
#' @export
cl_explore <- function(stats, metric, period = NULL, file = "cloudscape.html",
                       grid = NULL, palette = c("#2c7bb6", "#ffffbf", "#d7191c"),
                       title = NULL) {
  cl_assert(inherits(stats, "cl_stats"), "`stats` must be a cl_stats table.")
  grid <- grid %||% attr(stats, "grid")
  cl_assert(!is.null(grid), "No grid available; pass `grid = `.")
  d <- stats[stats$metric == metric, , drop = FALSE]
  if (!is.null(period)) d <- d[d$period %in% period, , drop = FALSE]
  cl_assert(nrow(d) > 0L, "No rows for metric '", metric, "'.")

  cc <- cl_grid_cells(grid, cells = d$cell)
  rng <- range(d$value, na.rm = TRUE)
  half <- grid$res / 2
  corners <- t(vapply(seq_len(nrow(cc)), function(i) {
    ll <- cl_unproject(c(cc$x[i] - half, cc$x[i] + half),
                       c(cc$y[i] - half, cc$y[i] + half))
    c(ll[1, "lon"], ll[1, "lat"], ll[2, "lon"], ll[2, "lat"])
  }, numeric(4)))

  feats <- vapply(seq_len(nrow(cc)), function(i) {
    x0 <- corners[i, 1]; y0 <- corners[i, 2]; x1 <- corners[i, 3]; y1 <- corners[i, 4]
    sprintf(
      '{"type":"Feature","properties":{"v":%s,"cell":%d,"n":%s},"geometry":{"type":"Polygon","coordinates":[[[%f,%f],[%f,%f],[%f,%f],[%f,%f],[%f,%f]]]}}',
      ifelse(is.na(d$value[i]), "null", format(d$value[i], digits = 6)),
      cc$cell[i], ifelse(is.na(d$n[i]), "null", d$n[i]),
      x0, y0, x1, y0, x1, y1, x0, y1, x0, y0)
  }, character(1))

  html <- sprintf(
    '<!DOCTYPE html><html><head><meta charset="utf-8"><title>%s</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<style>html,body,#map{height:100%%;margin:0}
.legend{background:#fff;padding:8px 10px;font:12px sans-serif;line-height:1.5;border-radius:4px}
.legend i{width:16px;height:10px;display:inline-block;margin-right:4px}</style></head>
<body><div id="map"></div><script>
var data={"type":"FeatureCollection","features":[%s]};
var lo=%f, hi=%f, pal=%s;
function ramp(t){var n=pal.length-1,i=Math.max(0,Math.min(n-1,Math.floor(t*n))),f=t*n-i;
 function hx(c){return [parseInt(c.substr(1,2),16),parseInt(c.substr(3,2),16),parseInt(c.substr(5,2),16)];}
 var a=hx(pal[i]),b=hx(pal[i+1]);
 return "rgb("+a.map(function(v,k){return Math.round(v+(b[k]-v)*f);}).join(",")+")";}
var map=L.map("map").setView([20,0],2);
L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
 {attribution:"&copy; OpenStreetMap",maxZoom:12}).addTo(map);
var layer=L.geoJSON(data,{style:function(f){var v=f.properties.v;
 return {fillColor:v==null?"#ccc":ramp((v-lo)/(hi-lo||1)),weight:0,fillOpacity:0.75};},
 onEachFeature:function(f,l){l.bindPopup("cell "+f.properties.cell+"<br>%s: "+
  (f.properties.v==null?"NA":f.properties.v.toFixed(3))+"<br>n = "+f.properties.n);}}).addTo(map);
try{map.fitBounds(layer.getBounds());}catch(e){}
var lg=L.control({position:"bottomright"});
lg.onAdd=function(){var d=L.DomUtil.create("div","legend");
 d.innerHTML="<b>%s</b><br>";
 for(var k=0;k<=4;k++){var t=k/4;d.innerHTML+=\'<i style="background:\'+ramp(t)+\'"></i>\'+
  (lo+(hi-lo)*t).toFixed(2)+"<br>";}
 return d;};lg.addTo(map);
</script></body></html>',
    title %||% metric, paste(feats, collapse = ","), rng[1], rng[2],
    paste0('["', paste(palette, collapse = '","'), '"]'), metric, metric)

  writeLines(html, file)
  cl_msg("Wrote ", file, " (", nrow(cc), " cells).")
  invisible(normalizePath(file, mustWork = FALSE))
}

#' Launch the interactive scene explorer
#'
#' Live imagery browsing needs a server: asset URLs from most catalogues are
#' signed and expire, and masks are computed on demand. This is therefore a
#' Shiny application rather than a static file.
#'
#' @param stats Optional `cl_stats` to seed the map.
#' @param ... Passed to `shiny::runApp()`.
#' @return Invisibly `NULL`.
#' @export
cl_app <- function(stats = NULL, ...) {
  cl_require(c("shiny", "terra"), reason = "The interactive scene explorer")
  app_dir <- system.file("shiny", package = "cloudscape")
  if (!nzchar(app_dir)) cl_abort("Shiny application not found in the installed package.")
  shiny::runApp(app_dir, ...)
}

#' Export cloudscape objects
#'
#' @param x A `cl_stats`, `cl_maskset` or `cl_obs`.
#' @param file Output path.
#' @param format Output format; `"auto"` infers from the extension.
#' @return The output path, invisibly.
#' @export
cl_export <- function(x, file, format = c("auto", "csv", "rds", "geojson", "tif")) {
  format <- match.arg(format)
  if (format == "auto") {
    format <- switch(tolower(tools::file_ext(file)),
                     csv = "csv", rds = "rds", geojson = "geojson",
                     json = "geojson", tif = "tif", tiff = "tif", "rds")
  }
  switch(format,
    csv = utils::write.csv(as.data.frame(x), file, row.names = FALSE),
    rds = saveRDS(x, file),
    geojson = {
      cl_require("sf", reason = "GeoJSON export")
      sf::st_write(x, file, delete_dsn = TRUE, quiet = TRUE)
    },
    tif = {
      cl_require("terra", reason = "GeoTIFF export")
      terra::writeRaster(x, file, overwrite = TRUE)
    })
  # Provenance travels with the data, in a sidecar so the primary file stays
  # readable by any tool.
  m <- attr(x, "manifest")
  if (!is.null(m)) {
    writeLines(vapply(names(m), function(k)
      paste0(k, ": ", paste(m[[k]], collapse = ", ")), character(1)),
      paste0(file, ".manifest.txt"))
  }
  invisible(normalizePath(file, mustWork = FALSE))
}
