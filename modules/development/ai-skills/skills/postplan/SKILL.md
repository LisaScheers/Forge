---
name: postplan
description: Use only when the user explicitly asks to publish, upload, host, or share an existing static HTML document through PostPlan.
---

# Postplan

Publish a completed static HTML document to Lisa's PostPlan service. The request must authorize the external upload. Use `postplan-read` to read an existing hosted document and `html-communication` to create a new document.

Before uploading, confirm that the file exists, is smaller than 512 KB, and contains no scripts, inline event handlers, forms, frames, embedded objects, meta refresh, secrets, private URLs, or local filesystem paths.

Run:

```sh
postplan upload <file-path> --description "Short purpose"
```

The CLI updates the draft associated with the same absolute file path. Use `--new` only when the user asks for a separate draft. PostPlan stores authentication and file-to-draft mappings in `~/.postplan`.

Treat publication as successful only when the command succeeds. Return the public URL and the local file. Report the exact CLI error on failure. Do not open the hosted page unless the user asks.
