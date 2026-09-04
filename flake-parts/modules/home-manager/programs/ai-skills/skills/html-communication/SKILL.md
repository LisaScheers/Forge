---
name: html-communication
description: Use when the user explicitly asks for HTML or invokes $html-communication to present a plan, report, comparison, or mockup. Create a local artifact; always publish plans through PostPlan, while other documents require publication authorization.
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

For every plan created with this skill, publication through PostPlan is required. Treat the request to create or present a plan with `html-communication` as authorization to publish that plan. Invoke `postplan` with the finished file and return both the local file and the hosted URL. If publication fails, return the local file and the exact upload error.

For reports, comparisons, mocks, and other non-plan documents, do not upload unless the user explicitly asks to publish, host, share, or return a public URL. A repository instruction that requires publication also counts as authorization.

Return a hosted URL only after `postplan` reports a successful upload. Do not open the hosted page unless the user asks.
