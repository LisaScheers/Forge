# Mathematical plots, 3D scenes, and simulations

## Mathematical plots

Choose the representation for the mathematical object: Cartesian/parametric/polar curves, implicit contours, complex-domain coloring, vector fields, phase portraits, or a 3D surface. ECharts works for sampled curves and fields; native Canvas supports custom raster/contour work; Three.js supports interactive 3D geometry. Do not reduce a surface or vector field to a category chart.

Keep the equation, domain, parameter ranges, units or dimensionless convention, and sampling/solver method visible. Use actual numeric/time coordinates rather than equally spaced categories for nonuniform samples. Split curves at undefined values and poles; never connect across an asymptote. Handle removable singularities using the mathematical limit, not an arbitrary epsilon shift. Refine sampling or disclose aliasing when narrow features cannot be resolved.

Check known zeros, extrema, limits, symmetry, or a simple special case. For contours/surfaces check representative function values and orientation. For differential equations distinguish the vector field from integrated trajectories and verify solver convergence. Generate code from understood expressions; do not run arbitrary input with `eval` or `new Function`. If an expression editor is needed, use a verified parser with a bounded grammar and work limit.

## 3D scenes

Put `<!-- THREE_RUNTIME -->` before the application script and one `<!-- VISUALIZE_NOTICES -->` in the document. The pinned browser bundle exposes Three.js plus OrbitControls under `THREE`:

```js
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 1000);
camera.position.set(8, 6, 10);
const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setPixelRatio(window.devicePixelRatio);
renderer.setSize(width, height);
container.append(renderer.domElement);
const controls = new THREE.OrbitControls(camera, renderer.domElement);
controls.enableDamping = false;
const render = () => renderer.render(scene, camera);
controls.addEventListener('change', render);
// Add geometry and appropriate lighting, then render once.
```

For a sampled surface, build `BufferGeometry` with explicit coordinates, indexed triangles, and computed normals; label coordinate orientation and color scale. Update camera aspect/projection and renderer dimensions on resize. Dispose replaced geometry/materials/textures. Render on orbit, parameter changes, and resize. A static scene needs no permanent animation loop. Render immediately before exporting a WebGL canvas. Check context availability and show a text alternative on failure. See [Three.js installation](https://threejs.org/manual/en/installation.html) and [OrbitControls](https://threejs.org/docs/pages/OrbitControls.html).

## Simulations

Separate the model and integrator from rendering. Specify state, equations, initial conditions, units, boundary/collision rules, approximations, and deterministic seed if random inputs matter. Provide play/pause, reset to the same initial state, and useful parameter controls. Start paused; a requested simulation may run while visible. Stop advancing while hidden and reset the wall-clock accumulator on resume so background time cannot cause a large jump.

Use a fixed simulation timestep with an accumulator, cap catch-up work, and show simulated elapsed time. Wall-clock frame time controls how many steps to take, not the physical step size. Single-step should advance the same timestep used by play. Limit trails and body counts; use a worker only when measured work warrants it.

For gravity, use Newtonian acceleration `a_i = G Σ m_j (r_j-r_i) / |r_j-r_i|³`. State any softening and use the corresponding softened potential when reporting energy. Apply pair forces consistently, or explicitly label a fixed central mass as a test-particle approximation. Use a suitable integrator such as velocity Verlet/leapfrog rather than naive explicit Euler for long orbital motion:

```js
// One velocity-Verlet step. acceleration(position) must be a pure model function.
const a0 = acceleration(position);
const nextPosition = position.map((x, i) => x + velocity[i] * dt + 0.5 * a0[i] * dt * dt);
const a1 = acceleration(nextPosition);
const nextVelocity = velocity.map((v, i) => v + 0.5 * (a0[i] + a1[i]) * dt);
```

Monitor quantities the model should preserve: total energy and angular momentum for isolated gravity, plus momentum/center of mass when all interacting bodies move. A fixed central source does not conserve the test particle's linear momentum. Define close-approach/collision behavior; do not hide unstable states by clamping coordinates. For numerical validation, compare a known solution (for example a normalized circular orbit) and rerun with half the timestep; report the observed error and convergence, not just that the animation looks plausible. For other systems choose the corresponding analytic limit or invariant.

Verification must also cover pause/resume, deterministic reset, finite state, and no advancement while paused/hidden. Label toy models and approximations plainly; do not present an educational animation as a validated physical prediction.
