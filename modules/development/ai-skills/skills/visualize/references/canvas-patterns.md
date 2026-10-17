# Canvas patterns

Use Apache ECharts 6.1.0, bundled by `_package.nix` under Apache-2.0 with its LICENSE and NOTICE. The HTML starter uses the full browser distribution, not an assumed global package or a remote service. Keep the licenses when embedding it. Official references: [Canvas renderer](https://echarts.apache.org/handbook/en/best-practices/canvas-vs-svg/), [container sizing](https://echarts.apache.org/handbook/en/concepts/chart-size/), [events](https://echarts.apache.org/handbook/en/concepts/event/).

| Question | View | Useful interaction |
|---|---|---|
| Compare categories | Sorted horizontal bars; zero baseline | Choose a measure or filter categories |
| Change over time | Line with an actual time axis; mark gaps | Zoom a time window, toggle series |
| Distribution or relationship | Histogram or scatter | Inspect values, brush a range |
| Two-dimensional intensity | Heatmap with a labeled scale | Filter a range or inspect a cell |
| Ownership, dependencies, transitions | Directed graph with explicit layout | Inspect a node, pan/zoom, reset |
| Weighted flows | Sankey, only with measured weights | Trace a path |

Preserve meaningful order, units, denominators, and sampling intervals. Category bars normally start at zero; label a justified truncated axis clearly elsewhere. Missing observations are gaps, not zero. Aggregate large datasets explicitly and retain the original range/count. Avoid pies with many slices, decorative 3D, or invented weights for a relationship graph.

## Relationships

For a small directed graph, replace the starter's Cartesian axes and series with a graph. Coordinates below control layout; they do not encode measured quantities. Replace the example entities with evidenced relationships and update the accessible table into a relationship list. `roam` supports pointer navigation; provide HTML buttons for zoom/reset if navigation is needed by keyboard.

```js
chart.setOption({
  animation: false,
  backgroundColor: '#000',
  tooltip: { renderMode: 'richText' },
  series: [{
    type: 'graph', layout: 'none', roam: true,
    symbolSize: 56, edgeSymbol: ['none', 'arrow'],
    label: { show: true, color: '#fff', position: 'bottom' },
    itemStyle: { color: '#8cbaff' },
    lineStyle: { color: '#aaa', width: 2 },
    data: [
      { id: 'input', name: 'Input', x: 0, y: 0 },
      { id: 'parse', name: 'Parse', x: 160, y: 0 },
      { id: 'model', name: 'Domain model', x: 320, y: 0 },
    ],
    links: [{ source: 'input', target: 'parse' }, { source: 'parse', target: 'model' }],
  }],
}, { notMerge: true });
```

For time ranges use ECharts `dataZoom`, for multiple measures use a legend or native HTML selector, and for drill-down use the documented `chart.on('click', ...)` event. Keep the source dataset separate from the displayed subset so reset restores the same evidence. Avoid a continuously running force simulation for a static explanation.

## Native Canvas 2D

For a custom drawing, use a `<canvas>` with a text/DOM alternative and HTML controls. Measure its CSS rectangle, set its backing dimensions to the CSS size times `devicePixelRatio`, then reset its transform with `context.setTransform(dpr, 0, 0, dpr, 0, 0)` before drawing in CSS pixels. Repaint after resize or input. Convert pointer coordinates from `clientX/clientY` through `getBoundingClientRect()`; do not confuse CSS and backing pixels.

Draw a solid background before exporting with `canvas.toBlob(...)` or `toDataURL('image/png')`. Use actual text measurements to avoid clipping labels. Use `requestAnimationFrame` only for a requested simulation; provide pause/reset and respect reduced motion. See the [Canvas API](https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API).
