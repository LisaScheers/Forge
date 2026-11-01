# Viewer workflows

Consult only the workflow needed for the current request. The selected viewer's
tool catalog is authoritative for operation names and fields.

## Direct Python client

Resolve `viewer_source` and `directory` from the selected checkout and endpoint.
Import the existing client rather than reimplementing socket framing. Its reply
has `result` or `error`, plus `request_id`; MCP places the same envelope in
`structuredContent` (or the JSON text content).

```python
import sys
from pathlib import Path

viewer_source = Path("/Users/lisa/Projects/Scheers/work/aurora-mcp")
directory = Path("/tmp/aurora-my-test")  # Replace with the exact selected endpoint.
sys.path.insert(0, str(viewer_source / "scripts/control"))
from viewer_api import request

def call(tool, **arguments):
    answer = request(directory, tool, arguments)
    if "error" in answer:
        # Preserve the ID for receipt/state inspection; do not replay this call.
        raise RuntimeError({"request_id": answer["request_id"], "error": answer["error"]})
    return answer["result"]

state = call("viewer_state")
assert state["in_world"], "The human must log in, or select an offline demo"
first_page = call("viewer_query", topic="huds", limit=25)
print(first_page)
```

For asynchronous workflows, poll reads using `time.monotonic()` and an explicit
deadline, sleeping about 0.2 seconds between calls. Retain the last state/error
when a deadline expires. A disappearing or replaced viewer PID ends the workflow.

## Inventory, contents and documents

- Start from `viewer_state.inventory_root`, a known parent UUID, or a bounded
  inventory search. Fetch the intended folder with `viewer_inventory(op="fetch",
  id=...)`; query its children by `parent` and inspect folder `state`.
- Fetch a prim's contents with `viewer_contents(op="fetch", id=OBJECT_UUID)`.
  Query `topic="contents", id=OBJECT_UUID` until `known=true` and `loading=false`;
  its records are in `items`. Ordinary inventory/object queries use `rows`.
- Requery after create/copy/move/wear/rez. Match acknowledged UUIDs and parents;
  do not repeat a creation merely because the original cache has not caught up.
- Trash and purge are separate operations. Purge is permanent and only accepts
  eligible items already in Trash. Native protection and worn/no-copy checks apply.
- For notecards, preview the inventory item or open the task notecard, then query
  `topic="documents", id=ITEM_UUID` until loaded. The exact-ID query includes
  readable source; save through the corresponding inventory/contents operation.

## Scripts

An inventory script uses `item=ITEM_UUID`; a task script additionally uses
`object=PRIM_UUID`. Preserve both fields throughout that workflow.

1. Open with `viewer_script(op="open", ...)`, then read until `loaded=true` and
   `loading=false`. Confirm `can_read`, `can_edit`, `dirty`, `saving` and source.
2. Preserve an existing unsaved draft. Edit it only within the user's authorized
   changes; if the requested source conflicts with another draft, resolve that
   conflict with the user instead of replacing it silently.
3. `op="edit", source=...` changes the draft without uploading.
   `op="save"` explicitly runs the native preprocessor/save/compile path.
4. Read until `saving=false`; inspect `compile_failed`, `errors`, `status`, source
   and `dirty`. A dispatched save is not a successful compile. Report diagnostics;
   do not loop edits/saves after a permission or transport failure.

## Movement, camera and settings

- Coordinates are main-region metres for world positions, attachment-local for
  attachment transforms/HUDs. Observed avatar angles are radians; typed build
  rotations are degrees, while observed object rotations are quaternions.
- `viewer_move(op="hold", duration_ms=..., ...)` replaces the previous automation
  hold and expires within ten seconds. `left`/`right` turn; `strafe_left`/
  `strafe_right` move sideways. Use short holds and read actual motion afterward.
- `goto` starts native autopilot; follow/autopilot can outlive a hold. Use
  `viewer_move(op="stop")` on completion or abort; it cancels automation movement,
  autopilot and following. Do not continuously renew a hold without readback.
- `fly` and camera `mouselook` toggle; inspect current state before invocation and
  never retry them blindly. Camera zoom is a fraction in [0, 1].
- Read the specific settings JSON Pointer before setting it, preserve its type,
  and verify the sanitized value afterward. `persist=false` still permits normal
  autosave/exit persistence; restore the original value for temporary experiments.
  Login/account configuration is intentionally unavailable.

## HUDs, dialogs and visual fallback

- Find HUD child prim UUIDs via `viewer_query(topic="huds")`. Inspect an exact
  object UUID for face metadata; inspect/open may be needed to load properties.
  Touch the intended child and face. UV/ST are three-vectors with z=0; use observed
  coordinates rather than assuming every HUD button is at a face's center.
- Query notifications after a touch. Respond with the actual numeric notification
  ID and zero-based button index, or the text-box operation. Do not infer an
  authorized answer from the dialog's wording alone.
- Discover panels with `viewer_ui(op="list")` and shortcuts with `op="actions"`.
  Prefer these over keys. Shortcut operations may toggle; read their effects.
- `viewer_input` coordinates are logical points from the top left. A capture can
  be resized: map its pixel coordinates back to `window_pixels`, then divide by
  `ui_pixels_per_point`. Do not use image pixels directly as UI points.
- UI-only `click`/`key`/`text` route through egui. Use `game_click` or the
  `drag_start`/`drag_move`/`drag_end` sequence for native world/HUD picking.
  Wait for `pointer_down=false` and `pick_pending=false` before another gesture.
  Do not interfere with an active human gesture. End a drag in cleanup; each move
  renews its ten-second release lease. Native gestures use current modifiers.
- MCP `viewer_capture` returns a native image. With the direct client, poll the
  capture until it returns `png_base64`, decode to a task-local PNG, and view it.
  Keep the render window visible/uncovered if macOS pauses presentation. A capture
  timeout is not proof of an interaction failure; inspect state before retrying.
