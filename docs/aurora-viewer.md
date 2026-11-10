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
`24fe0e77c292068d6b2f01ab457b77efbc9b3ccf` (8 November 2026), after release 0.9.3.
Upstream now includes the macOS browser integration, media-pack selection,
binding-array page-limit fixes, world render scaling, and masked-pixel rejection.
`packages/aurora-viewer/macos.patch` retains only the early rejection of transparent
blended texels before the remaining material maps are sampled, with its GPU
regression test. The separate browser patch has been removed.

Preferences › Graphics › Smoothness includes a 50–100% 3D render scale.
The interface and HUDs stay at native resolution, and saved photos bypass scaling.
`AURORA_RENDER_SCALE` and `AURORA_TEXTURE_BUDGET_MB` allow isolated comparisons.

The package uses upstream's optimized development profile. It identifies itself
as `0.9.3+macos.24fe0e77`. The app bundle includes an icon and microphone usage
description. Earlier performance measurements below describe the October build;
they have not been repeated for this source revision.

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

The 8 November package passed 7,920 workspace tests (52 ignored), including
the rebased GPU alpha tests and the separately executed statistics HTTP fixture.
The Nix package build and application version check also passed. These checks
ran without activating Vega's configuration.

## Limits

This packages upstream's macOS port of an early-development viewer. Grid login,
voice, teleporting and prolonged sessions need manual validation. Tests and
the offline demo do not establish live-grid compatibility.

CEF/video media plugins are not bundled. Upstream handles macOS media packs; this package does not bundle one.
The package does not configure system-wide Second Life URL-scheme registration.

Updates remain declarative: advance the pinned source and Cargo hashes,
refresh the patch, rebuild and validate the demo before applying the new
configuration.
