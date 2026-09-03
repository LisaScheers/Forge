---
name: html-communication
description: Use when the user explicitly asks for HTML or invokes $html-communication to present a plan, report, comparison, or mockup. Create a local artifact; use postplan only when publication is authorized.
---

# HTML Communication

Create one complete static HTML document for communicating with the user. Write a useful working document, not a promotional page. This skill does not create product HTML.

Keep the file self-contained and no larger than 512 KB.

Allowed:

- semantic HTML;
- inline CSS or a `<style>` block;
- normal document metadata such as charset, viewport, and title;
- links to ordinary HTTPS pages;
- images from HTTPS or data URLs when necessary.

Do not include:

- JavaScript, `<script>` tags, or inline event handlers;
- `javascript:` URLs;
- forms;
- iframes, embeds, objects, or applets;
- meta refresh redirects;
- secrets, tokens, private URLs, or local filesystem paths.

Match the document to the request. Prefer clear hierarchy, concise prose, and direct comparisons over decoration. For UI mocks:

- create several genuinely different options;
- label them `A`, `B`, `C`, and so on for easy selection;
- place them where they can be compared directly;
- keep explanation secondary to the mocks.

Use one stable local file across revisions. Return a clickable link to that file.

Do not upload the document unless the user explicitly asks to publish, host, share, or return a public URL. A repository instruction that requires publication also counts as authorization. When publication is authorized, invoke `postplan` with the finished file.

Return the local file in every case. Return a hosted URL only after `postplan` reports a successful upload. Do not open the hosted page unless the user asks.
