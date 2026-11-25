# aurora-control

Client, CLI and MCP stdio server for the control bridge that forge patches
into Aurora Viewer (`packages/aurora-viewer/control.patch`). Standard library
only. Setup and safety rules: [docs/aurora-viewer.md](../../docs/aurora-viewer.md).

| File | Role |
| --- | --- |
| `viewer_api.py` | `request(directory, tool, arguments)` returns the reply envelope |
| `aurora_control.py` | `aurora-control --directory DIR TOOL`, JSON arguments on stdin |
| `mcp_server.py` | `aurora-control-mcp --directory DIR`, MCP over stdio |
| `tools.json` | the tool catalog, served as `aurora://tools` |
| `guide.md` | the usage guide, served as `aurora://guide` |
| `e2e_demo.py` | end-to-end check against the offline demo |

```sh
printf '{}\n' | aurora-control --directory "$AURORA_CONTROL_DIR" viewer_state
```

Unit tests run in the package build:

```sh
python3 -B -m unittest discover -s tests -p 'test_*.py'
```
