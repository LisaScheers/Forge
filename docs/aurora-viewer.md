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

## Control bridge

Upstream Aurora has no automation API, so forge patches one in
([`control.patch`](../packages/aurora-viewer/control.patch)). It lets agents
read chat and conversations, reply to IMs and drive the viewer when its own
window is no use, for example while the scene draws black. With
`AURORA_CONTROL_DIR` unset, the viewer behaves exactly as upstream.

Launch the app with the bridge on Vega:

```sh
aurora-viewer-control
```

The launcher opens a new instance of the Home Manager app with
`AURORA_CONTROL_DIR=~/Library/Caches/aurora-control` and passes its arguments
to the viewer. If a viewer with the bridge already answers there, it refuses;
if a viewer that did not quit cleanly left the directory behind, it removes the
stale socket and directory first. Launches from Finder and `aurora-viewer` stay
without the bridge: the endpoint is opt-in per session, so no agent can drive a
session a person did not start for that. A person still logs in by hand; the
bridge never handles credentials.

How it works:

- The viewer creates the directory itself (mode 0700; an existing path is
  refused) and listens on `control.sock` (0600). Connections from other users
  are refused. Quitting removes both.
- Each connection carries one JSON request per line and gets one reply line:
  `result` or `error`, plus `request_id`.
- Connection threads only forward requests. The frame answers them through the
  viewer's own paths: chat and IMs go through the conversation field's handler,
  inventory edits through the inventory window's, notifications through the
  cards' answers, shortcuts through the key handler. Every network command
  passes `App::send`, so RLVa's send boundary and the simulator's permissions
  apply. Protected inventory, worn items, no-copy rules and RLVa restrictions
  (`@showinv`, `@viewscript`, `@shownearby`, `@showloc`, camera locks) refuse
  the matching tools. Login, account, proxy, update and RLVa preferences are
  out of reach of `viewer_settings`.
- Receipts keep the last 128 commands and an event ring the last 512 entries
  (chat and IM lines, notifications, screen, region, posture, commands).
- Automation movement holds and drags end 10 seconds after their last renewal.
- With requests waiting and no frame for 250 ms (macOS stops redrawing an
  occluded window), the bridge runs a frame itself.

The client, CLI and MCP server are the `aurora-control` package
([`tools/aurora-control`](../tools/aurora-control)), standard-library Python.
`aurora-control --directory DIR TOOL` reads JSON arguments on stdin;
`aurora-control-mcp --directory DIR` serves the sixteen tools and the
`aurora://guide` and `aurora://tools` resources over stdio. Codex has the
`aurora` server behind tool search; Claude attaches it on request:

```sh
claude --mcp-config ~/.claude/mcp-available/aurora.json
```

The [`aurora-viewer-control` skill](../modules/development/ai-skills/skills/aurora-viewer-control/SKILL.md)
describes the workflows and safety rules.

Not covered yet: rezzing new prims, notecards, teleports, payments and
purchases. Use the visual fallback (`viewer_capture`, `viewer_input`) or the
viewer itself.

### Checks

- The patch's Rust tests (`control::tests`, `app::control_bridge`) run in the
  package build: request framing, receipt and event limits, leases, settings
  pointers and type checks, the endpoint's permissions and cleanup, and a
  settings round trip on the real preferences.
- `checks.aarch64-darwin.aurora-control` runs the client, CLI and MCP framing
  tests against a stand-in socket.
- `e2e_demo.py` drives an offline demo end to end; it refuses to run unless
  `viewer_state` reports `demo=true`. macOS draws nothing for a covered
  window, so the capture step reports a skip while the viewer is covered.
  `AURORA_DEMO=1 aurora-viewer-control` starts the demo with the bridge too:

```sh
AURORA_DEMO=1 AURORA_CONTROL_DIR=/tmp/aurora-e2e ./result/bin/aurora-viewer &
python3 "$(nix build --no-link --print-out-paths path:.#aurora-control)/lib/aurora-control/e2e_demo.py" /tmp/aurora-e2e
```

## Port and package

The source is pinned to upstream release 0.9.13
(`e961b7df61c49552773f3bc209d7d80d92a0b16b`, 23 November 2026). Upstream includes the macOS browser integration, media-pack
selection, binding-array page-limit fixes, world render scaling, and masked-pixel
rejection. The former blended-alpha early-rejection patch was dropped at 0.9.13:
Medium and higher presets now draw blended faces in exact order through
`fs_blend_once`, which that patch never covered. In the remaining `fs_blend`
pass, upstream now shades legacy materials before rejecting empty texels so
they can still glare. Its measured gain was also within noise (below).

Unpatched 0.9.13 opens to a black world on M3 and later
([Aurora-Viewer#4785](https://github.com/Aurora-Viewer/Aurora-Viewer/issues/4785)).
Apple's Metal compiler aborts with `LLVM ERROR: Failed to encode.` on the
terrain fragment shaders (`fs_terrain`, `fs_terrain_pbr` and their G-buffer
variants), and the crashed compiler service takes every pipeline compiling
alongside them down too. The trigger arrived with upstream `c32edd26` and is
not one construct: deleting code does not avoid it, but keeping any of several
functions as a real call does. Two local patches do that for the debug views,
which only run when Preferences › Debug picks one:

- `metal-outlined-debug-view.patch` moves the views into `debug_view_outlined`,
  called only when a view is chosen.
- `wgpu-hal-outlined-functions.patch`, applied to the vendored wgpu-hal, marks
  every generated MSL function named `*_outlined` `noinline`.

Apple's offline compiler (Metal toolchain 27.2, `applegpu-nt`) reproduces the
failure for G15 to G17 (M3 to M5) and accepts all 135 scene pipelines with the
patches; M1 and M2 (G13, G14) were never affected. Remove both patches once
upstream compiles on Metal without them.

A third local patch, `control.patch`, adds the control bridge described above.

Preferences › Graphics › Smoothness includes a 50–100% 3D render scale.
The interface and HUDs stay at native resolution, and saved photos bypass scaling.
`AURORA_RENDER_SCALE` and `AURORA_TEXTURE_BUDGET_MB` allow isolated comparisons.

The package uses upstream's optimized development profile. It identifies itself
as `0.9.13+macos.e961b7df`. The app bundle includes an icon and microphone usage
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
The dropped early-alpha patch measured 145.6 before / 146.5 FPS after in a separate
layered-hair offline scene (3,000 frames, final 15 profile samples); that small
difference does not establish an FPS improvement in the live scene. A later
live trace measured 21.05 ms GPU active per frame, with vertex work higher too
(8.28 vs 7.19 ms); the changing live workload prevents attributing that
difference to the alpha change.

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
