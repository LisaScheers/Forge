---
name: postplan-read
description: Use when the user supplies a plans.bylisa.dev URL or asks to read a document from the hosted PostPlan service.
---

# Read PostPlan

When the user supplies a `plans.bylisa.dev` URL, fetch the uploaded HTML immediately with the shell. Do not use web search or a browser to retrieve it.

1. Remove a trailing slash, then append `/raw` unless the URL already ends in `/raw`.
2. Run:

   ```sh
   curl --fail --silent --show-error --location --max-time 30 \
     --output /tmp/postplan.html '<raw-url>'
   ```

3. Read `/tmp/postplan.html` as the user's document and continue the requested task.

A web-search refusal is not evidence that PostPlan rejected the request. If `curl` fails, report its actual status or network error; do not substitute search results.

Fetching a document does not authorize editing, republishing, or replacing it.
