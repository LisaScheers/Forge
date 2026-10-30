# Aurora Viewer on macOS

Vega's Home Manager profile includes `aurora-viewer`. The package builds the
viewer from source and provides `Aurora Viewer.app` and the `aurora-viewer`
command. Applying Vega's configuration makes the app available in
`~/Applications/Home Manager Apps/`.

Build it without activating the configuration:

```sh
nix build path:.#aurora-viewer
./result/bin/aurora-viewer --version
```

Run the offline demo:

```sh
AURORA_DEMO=1 ./result/bin/aurora-viewer --title "Test macos"
```

The demo uses separate settings and caches and needs no Second Life account.
For normal use, launch the app from Finder or run `aurora-viewer` after applying
the configuration. Log in manually.

## Port and package

The source is pinned to upstream commit
`77d8c70c8bf7075aef66698544764d623abff346` (29 October 2026).
Upstream PR #1463 includes the native Metal port, visible startup window,
water-shader compiler workaround, Metal memory-budget queries and native
Command-Q handling. Windows and Linux retain Vulkan.
`packages/aurora-viewer/macos.patch` carries the remaining rendering performance
work: binding-array page limits, world scaling and early alpha rejection.
The binding-array page limit is separate from ordinary texture slots. The patch
removes the incorrect 79-page ceiling on Metal. Preferences › Graphics ›
Smoothness includes a 50–100% 3D render scale: the world is spatially upscaled,
while controls, labels and HUDs stay at native resolution. Saved photos bypass
this scale. Use 67% or 50% when full Retina resolution is GPU-bound; 100% is the
default. `AURORA_RENDER_SCALE` and `AURORA_TEXTURE_BUDGET_MB` allow isolated
comparisons without activating a new system configuration.

The package uses upstream's optimized development profile, which disables
debug assertions and overflow checks and builds dependencies with full
optimization. It identifies itself as `0.8.3+macos.77d8c70c`. The app bundle
contains an icon and a microphone usage description for voice chat.

## Measured on Apple M5 Pro

The packaged offline High demo at 3456×2112 output reached median 35.7 FPS at
100% world scale, 73.8 FPS at 67%, and 114.2 FPS at 50%. Each run completed
1,800 frames in a visible window; medians use the final 15 profile samples.
A denser 9,000-texture/20-avatar stress scene reached 30.0/40.0/43.9 FPS at
those scales, with CPU draw submission becoming a limit. These are offline
measurements, not a promise of live-region performance. Saved 1920×1080 photos
were checked at 50% world scale and rendered at the requested resolution.

A stationary live-view Metal System Trace showed the GPU active for about 91%
of a 10.54-second trace, with median 18.74 ms active per frame. Fragment shading
was the main cost; spatial upscaling took about 0.77 ms and egui 0.23 ms.
These pipeline timings overlap. More texture budget is unlikely to help that
view: about 4.2 GB was resident within the manually selected 10 GB budget.
The early-alpha candidate measured 145.6 before / 146.5 FPS after in a separate
layered-hair offline scene (3,000 frames, final 15 profile samples); that small
difference does not establish an FPS improvement in the live scene. A later
live trace measured 21.05 ms GPU active per frame, with vertex work higher too
(8.28 vs 7.19 ms); the changing live workload prevents attributing that
difference to the alpha change. The candidate remains experimental.

The previous packaged build passed 6,102 workspace tests (30 ignored), with the
existing intermittent viewer-statistics HTTP fixture run separately. The updated
source passed 6,151 tests (30 ignored), formatting and Clippy, including native
Metal sampling/upscaling and alpha-work rejection checks. The updated Nix package
also passed its full test run, isolated HTTP fixture and version check. It is
built without activating Vega's configuration.

## Limits

This packages upstream's macOS port of an early-development viewer. Grid login,
voice, teleporting and prolonged sessions need manual validation. Tests and
the offline demo do not establish live-grid compatibility.

CEF/video media plugins are not bundled. Upstream's downloadable media packs
target Windows and Linux; this package does not provide a macOS media pack.
URL-scheme registration is also not implemented on macOS upstream, so opening
Second Life links from other applications is not configured by this package.

Updates remain declarative: advance the pinned source and Cargo hashes,
refresh the patch, rebuild and validate the demo before applying the new
configuration.
