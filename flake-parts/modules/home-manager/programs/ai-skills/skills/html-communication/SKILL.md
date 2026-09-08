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
- give example prompts for each option, so the user can see how they would be used in practice;
- place them where they can be compared directly;
- keep explanation secondary to the mocks.

Use one stable local file across revisions. Return a clickable link to that file.

all plans created by this skill must be uploade to `postplan` for the user to review and approve before working on the actual implementation. The user may ask for a hosted URL, but do not provide one until `postplan` reports a successful upload. Do not open the hosted page unless the user asks.

Return the local file in every case. Return a hosted URL only after `postplan` reports a successful upload. Do not open the hosted page unless the user asks.
