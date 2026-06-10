---
name: dsfr-stitch
description: >-
  Bridges Google Stitch with French public-sector UI constraints. Use when generating, auditing, or translating Stitch designs for DSFR, RGAA, react-dsfr, LaSuite/Cunningham, DESIGN.md, or French government service prototypes. Not for generic Tailwind, shadcn-only, or non-public-sector Stitch workflows.
---

# DSFR Stitch

**Audience:** Agents using Google Stitch for French public-sector UI exploration.

**Goal:** Keep Stitch useful for ideation while preserving DSFR, RGAA, LaSuite, and production React implementation constraints.

## Use this stance

Use Stitch as a design accelerator, not production truth. Stitch may generate attractive HTML/Tailwind, but French public-sector implementation must still map to DSFR or LaSuite components and pass RGAA review.

Do not ship Stitch HTML directly. Do not treat Stitch colors, fonts, Tailwind classes, or generated copy as authoritative.

## Before using Stitch

1. Confirm the target surface: `DESKTOP`, `MOBILE`, `TABLET`, or `AGNOSTIC`.
2. Determine whether the product is pure DSFR or LaSuite/Cunningham.
3. Check for existing project design docs or components before inventing anything.
4. If using MCP, verify auth with `scripts/stitch-mcp.mjs list-projects`. It reads `STITCH_API_KEY`, or OAuth variables `STITCH_ACCESS_TOKEN` and `GOOGLE_CLOUD_PROJECT`.
5. Start from `references/dsfr-design-md.md` for a DSFR `DESIGN.md`; adapt tokens only after checking official project constraints.

## Core workflow

1. **Create or select a Stitch project**
   - Use MCP/SDK when credentials are available.
   - For manual use, prepare a prompt the user can paste into Stitch.

2. **Attach design-system context**
   - Upload a DSFR `DESIGN.md` with `upload_design_md` then `create_design_system_from_design_md`, or paste the DSFR design-system block into the prompt.
   - For LaSuite, add Cunningham and `@gouvfr-lasuite/ui-kit` constraints in the prompt.

3. **Generate exploratory screens**
   - Prompt with real French copy, real service goals, and one primary user task.
   - Include DSFR constraints explicitly: Marianne typography, blue-france primary, République Française/service framing, flat restrained surfaces, DSFR-style grid.
   - Use variants for visual exploration; use targeted edits for one major change at a time.

4. **Validate the artifact**
   - Run `npx @google/design.md lint DESIGN.md` when a DESIGN.md exists.
   - Run `node scripts/validate-dsfr-stitch-output.mjs <files>` on downloaded HTML, DESIGN.md, or screenshots metadata when available.
   - Treat this as a pre-check only; still run the RGAA skill for final code.

5. **Translate to production UI**
   - Read `references/stitch-to-react-dsfr.md`.
   - Implement with `@codegouvfr/react-dsfr` for DSFR services.
   - Implement with `@gouvfr-lasuite/ui-kit` and Cunningham for LaSuite apps.
   - Preserve product IA and service language over Stitch’s layout suggestions.

6. **Quality gate**
   - Run an RGAA audit on final rendered code, not just on Stitch HTML.
   - Verify in a real browser for keyboard navigation, focus, responsive behavior, and copy fit.

## Prompt pattern

```text
[Idea] French public service screen for <service/task>.
[Device] DESKTOP or MOBILE.
[Anatomy] DSFR-style layout: header, breadcrumb, main content, form/list/cards, footer.
[Vibe] Institutional, accessible, restrained, operational, trustworthy.
[Content] Use this exact French copy and fields: <copy>.
[Design system] Follow DSFR: Marianne typography, blue-france #000091 primary, red-marianne for critical/error only, neutral grey surfaces, minimal elevation, no SaaS gradients.
[Constraints] Do not invent custom colors, decorative icons, fake metrics, or marketing copy. Output must be translatable to react-dsfr components.
```

## MCP helper

Use the bundled helper instead of generic MCP clients if they mishandle Stitch’s stateless HTTP behavior:

```bash
node skills/dsfr-stitch/scripts/stitch-mcp.mjs list-tools
node skills/dsfr-stitch/scripts/stitch-mcp.mjs list-projects
node skills/dsfr-stitch/scripts/stitch-mcp.mjs info generate_screen_from_text
node skills/dsfr-stitch/scripts/stitch-mcp.mjs call list_projects '{"filter":"view=owned"}'
```

Mutating calls can take minutes. Do not blindly retry `generate_screen_from_text`, `edit_screens`, `generate_variants`, or design-system writes after a timeout or connection error. Check later with `get_project`, `list_screens`, or `get_screen`.

## Read references as needed

- `references/dsfr-design-md.md`: DSFR DESIGN.md starter for Stitch projects.
- `references/stitch-to-react-dsfr.md`: component mapping and implementation rules.
- `references/rgaa-stitch-checklist.md`: preflight checks before handing concepts to implementation.

## Hard stops

- Do not use `stitch::react-components` as the final path for DSFR production code; it targets React/Tailwind, not react-dsfr.
- Do not use shadcn/ui for French state services unless the project explicitly allows a non-DSFR system.
- Do not accept non-DSFR colors or fonts in a government concept without naming the exception.
- Do not skip RGAA review because DESIGN.md lint passed.
