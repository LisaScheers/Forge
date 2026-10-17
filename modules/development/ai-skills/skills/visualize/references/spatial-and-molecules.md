# Maps and molecular structures

## Maps and traffic

Distinguish geographic traffic from network/request traffic. For a network graph use the graph patterns; for geographic traffic preserve longitude/latitude order, coordinate reference system, time window, units, and direction. Keep observed speeds, counts, travel times, and modeled congestion separate. Label schematic geometry and synthetic traffic as such. Never imply live traffic without a real timestamped source.

ECharts' bundled full distribution supports `echarts.registerMap(name, geoJSON)`, a `geo` component, and `lines`/`scatter` series with `coordinateSystem: 'geo'`. Embed local GeoJSON with attribution and use pan/zoom plus a reset control. For a small street or route map, local vector geometry is often enough; do not add a tile service merely for decoration. Preserve topology when simplifying geometry, and choose a suitable projection for the region. See the [ECharts geo options](https://echarts.apache.org/en/option.html#geo).

For example, after registering the actual supplied geometry:

```js
echarts.registerMap('region', localGeoJSON);
chart.setOption({
  animation: false,
  geo: { map: 'region', roam: true, itemStyle: { areaColor: '#101010', borderColor: '#666' } },
  series: [{
    type: 'lines', coordinateSystem: 'geo',
    data: routes.map(route => ({ coords: route.coordinates, name: route.name })),
    lineStyle: { color: '#8cbaff', width: 3, opacity: 1 },
  }],
});
```

If actual basemaps, tiles, or live feeds are required, check the provider's license, attribution, availability, and credentials. Download/embed permitted source data when an offline artifact is required; otherwise disclose the network dependency. Do not invent a traffic API or silently send private locations to one. Native Canvas can draw a projected network or spatial field without a map library.

## Molecules

Use pinned 3Dmol.js for atoms/bonds, macromolecules, and supplied volumetric structures. It renders into WebGL Canvas. Prefer supplied SDF/MOL/PDB/mmCIF data with provenance and topology; XYZ contains elements and positions but bonds may be inferred. Do not infer bond order, aromaticity, protonation, charge, or stereochemistry from an attractive picture. State coordinate units and whether geometry is experimental, computed, idealized, or schematic.

Put `<!-- THREEDMOL_RUNTIME -->` before the application script and one `<!-- VISUALIZE_NOTICES -->` in the document. The container must have an explicit height and `position: relative`:

```js
const viewer = $3Dmol.createViewer(container, { backgroundColor: '#000' });
const model = viewer.addModel(structureText, 'sdf');
viewer.setStyle({}, { stick: {}, sphere: { scale: 0.25 } });
viewer.zoomTo();
viewer.render();
new ResizeObserver(() => viewer.resize()).observe(container);
// Add HTML controls for representation, reset view, and atom/residue inspection.
```

Use `cartoon` for appropriate protein structures, not small molecules. Keep rotation/zoom user-controlled; avoid automatic spinning. Read the current API before adding picking, measurements, surfaces, or selections. Keep structure text embedded rather than calling a remote download helper at viewing time. For PNG generation use the documented `viewer.pngURI()` after rendering. See [3Dmol integration](https://3dmol.org/doc/tutorial-code.html) and [GLViewer API](https://3dmol.org/doc/GLViewer.html).

Verify parsed atom count/elements, explicit or inferred bonds, and representative distances against the supplied model. Check a rotation or representation change, reset framing, narrow layout, and any measurements. A WebGL failure needs a visible explanation and atom/topology text alternative; a 2D fallback must be labeled as such.
