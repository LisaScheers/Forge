---
name: visualize
description: "Create or revise interactive visual explanations, data graphs, spatial maps, molecules, mathematical plots, 3D scenes, and simulations as local HTML Canvas/WebGL artifacts. Use for /visualize, $visualize, or requests to explore data, concepts, structures, or dynamics visually. Do not use for full websites, static prose reports, or publication-ready scientific figures."
---

# Visualize

Turn the question into a useful visual experiment, using HTML Canvas 2D or WebGL. Deliver a working local HTML file. Choose the representation around the question, rather than fitting every request into a dashboard or chart. Interaction can reveal structure, change a mathematical parameter, inspect an atom, navigate a map, or run a physical model.

## Choose the view

Use the facts, code, or data already available. Fetch missing evidence when authorized; ask only for a missing choice that materially changes the result. Keep units, dates, filters, sources, and uncertainty attached to the data. Label illustrative or simulated inputs explicitly. Distinguish observed relationships from proposed ones.

Pick the simplest representation that answers the question. These are starting points, not a closed list of supported subjects:

| Visual | Renderer and guidance |
|---|---|
| Statistical plots, network graphs, flows | ECharts Canvas; [chart and graph patterns](references/canvas-patterns.md) |
| Geographic or traffic maps, spatial fields | ECharts geo or native Canvas with local geometry; [maps](references/spatial-and-molecules.md#maps-and-traffic) |
| Molecular structures and proteins | 3Dmol.js on WebGL Canvas; [molecules](references/spatial-and-molecules.md#molecules) |
| Functions, parametric curves, phase portraits, contours | ECharts or native Canvas; [mathematics](references/math-and-simulation.md#mathematical-plots) |
| 3D mathematical surfaces, geometry, custom scenes | Three.js on WebGL Canvas; [3D scenes](references/math-and-simulation.md#3d-scenes) |
| Gravity, particles, waves, dynamical systems | A numerical model plus Canvas/Three.js; [simulations](references/math-and-simulation.md#simulations) |

For another subject, choose or implement an appropriate renderer using open-source tools; verify new APIs and package dependencies rather than inventing them. Rendering libraries display a model; they do not supply scientific correctness. For a research figure intended for export or publication, use the relevant scientific plotting workflow instead.

## Build the artifact

1. Locate this skill's directory from the path used to read it. Work in the chat's artifact directory, or another user-requested location; otherwise use a descriptive directory under `${CODEX_HOME:-$HOME/.codex}/visualizations/`. Keep one stable output file when revising the same visual. [assets/starter.html](assets/starter.html) is a chart example, not a required layout for molecules, mathematics, maps, or simulations.
2. Use a suitable scaffold or create the artifact directly; replace all example data, source notes, and controls with the actual task. Keep the question, visual, and short takeaway together. Preserve an existing design; otherwise use black `#000`, white primary text, and a restrained categorical palette. Redraw on input or resize; do not add continuous decorative animation.
3. Initialize ECharts with `{ renderer: 'canvas' }`, or create the appropriate Canvas/WebGL renderer. Use ordinary HTML controls for keyboard access and a text/table, equation, atom list, or relationship-list alternative for the same evidence. Give the container a real height and resize it correctly. Show a clear error and useful text alternative if WebGL is unavailable. A requested simulation may animate; start paused, provide play/pause/reset, and stop advancing while hidden. Static 3D scenes redraw on camera/input changes rather than running a perpetual render loop.
4. Bundle the runtime and its licenses into the output, using the helper from the Nix-packaged skill:

   ```sh
   python3 /absolute/skill-directory/scripts/bundle.py \
     /absolute/artifact-directory/draft.html \
     /absolute/artifact-directory/visualization.html
   ```

   `bundle.py` needs only Python 3's standard library. Follow the Nix dependency workflow if a suitable interpreter is missing. Forge's `_package.nix` supplies pinned runtimes and license notices in `assets/vendor/`; the helper also accepts `--runtime-dir` for that directory when working from a source checkout. Put the markers for the libraries actually used before the application script:

   - `<!-- ECHARTS_RUNTIME -->` exposes `echarts`.
   - `<!-- THREE_RUNTIME -->` exposes `THREE`, including `THREE.OrbitControls`.
   - `<!-- THREEDMOL_RUNTIME -->` exposes `$3Dmol`.
   - One `<!-- VISUALIZE_NOTICES -->` includes licenses for the selected libraries. The starter's older `ECHARTS_NOTICES` marker also works.

   Multiple runtime markers are allowed; unused libraries are not embedded. Do not substitute an unpinned CDN or omit the notices. Native Canvas-only artifacts need no runtime marker or bundling step.

Embed data locally. Encode external strings as data rather than interpolating them into executable JavaScript or `innerHTML`; escape `<` as `\u003c` in inline JSON so labels containing `</script>` cannot terminate it. Keep assets local or embedded so the delivered HTML works offline. Creating a local visual does not authorize publication or changes to the source application.

## Verify and show

Open the finished file in an available browser and inspect its rendered state. Verify the source/model, at least one meaningful control, the text alternative, resizing at a narrow width, and PNG generation when offered. Check for clipped labels, misleading scales, missing values presented as zeros, console errors, and unwanted continuous animation. Also verify the relevant domain: geographic coordinates and timestamps, molecular topology and units, function limits and discontinuities, or numerical invariants and timestep sensitivity. A smooth animation is not evidence of correct physics. Report any browser-verification limit honestly.

Use the available Codex file/browser panel to show the artifact; serve only its artifact directory on loopback if the browser requires HTTP. Return an absolute link to the HTML, a short takeaway, and a screenshot or exported PNG when it helps. A PNG is a preview; the HTML contains the interaction. Do not claim a proprietary inline visualization card or publish the artifact merely to display it.
