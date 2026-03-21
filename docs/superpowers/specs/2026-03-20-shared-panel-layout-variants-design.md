# Shared Panel Layout Variants Design

Date: 2026-03-20
Status: Approved for planning

## Summary

This design adds layout variants to the shared panel system so prompt-style flows can preserve old interaction behavior without abandoning shared panel infrastructure.

The first concrete use is `rename`. It should keep using shared panel code, but its default behavior should match the old `main`-branch rename experience: a compact single-line prompt, old cursor/edit semantics, and no extra buffer rows for context or helper text.

## Goals

- Keep `rename` on shared panel infrastructure instead of restoring a fully separate float implementation.
- Make `rename` default to the old interaction model from `main`.
- Keep the current shared multi-line panel behavior available for list-style features.
- Introduce the smallest shared API necessary to support both styles cleanly.

## Non-Goals

- Changing `codeactions` or `formatters` to compact prompt behavior.
- Adding a user-facing layout toggle in setup config at this stage.
- Reverting the shared panel work or restoring feature-specific UI code paths wholesale.
- Treating visual differences in border/title chrome as regressions when behavior is intentionally preserved.

## Product Direction

Shared panel code should support multiple interaction shapes, not force every feature into the same in-buffer structure.

The desired outcome is:

- `codeactions` and `formatters` continue to use the richer shared panel presentation.
- `rename` uses the same shared panel infrastructure, but renders as a compact prompt panel.
- Shared visuals can evolve, but prompt behavior must remain appropriate for a rename flow.

This keeps the codebase unified without flattening feature-specific interaction needs.

## Shared Panel Model

The shared panel model should add a `layout` field with two variants:

- `standard`
  The current shared multi-line panel layout. Suitable for action lists, formatter lists, and state-heavy panels.
- `compact`
  A minimal shared prompt layout. Suitable for prompt-driven flows where the buffer should primarily behave like an editable input line.

Default behavior:

- `layout = 'standard'` unless a feature selects otherwise.

Responsibilities that remain shared across both layouts:

- border and title metadata
- window sizing hooks
- highlight registration
- panel lifecycle helpers
- normalized panel/footer/title metadata

Responsibilities that vary by layout:

- which metadata is rendered into buffer lines
- how many lines are rendered
- whether helper/footer text is shown inside the buffer
- how prompt-style cursor/edit rules are applied

## Rename Default Behavior

`rename` should default to `layout = 'compact'`.

In compact layout, `rename` should behave like the old implementation:

- render only the editable prompt line in the buffer
- keep prompt editing semantics aligned with `main`
- start in insert mode
- constrain cursor movement within the prompt line
- keep submission and cancel flow aligned with the old rename interaction

Behavior explicitly not rendered into the buffer by default:

- context rows such as `Current: <symbol>`
- footer helper rows such as `Enter:rename`
- validation/status rows

Shared panel infrastructure may still receive this metadata, but compact layout should choose not to render it into buffer lines.

Window-level chrome is still allowed:

- border
- title
- border/title highlights

Those do not conflict with the old rename behavior because they do not alter the editable buffer shape.

## Architecture

Implementation should preserve a single shared panel path while adding a layout boundary inside it.

Expected structure:

- shared panel normalization accepts `layout = 'standard' | 'compact'`
- shared panel rendering helpers branch on layout only where buffer structure differs
- `rename` builds a shared panel model with `layout = 'compact'`
- `codeactions` and `formatters` continue to use `layout = 'standard'`

Architectural rules:

- Do not reintroduce a fully separate rename UI implementation.
- Keep layout branching localized to shared panel rendering behavior.
- Do not push rename-specific business logic into generic panel normalization.
- If compact prompt behavior needs dedicated helpers, keep them shared and layout-oriented rather than feature-oriented.

## Error Handling

Compact layout should preserve old rename interaction behavior without losing current validation correctness.

Rules:

- no-client rename should still fail clearly before opening the prompt
- empty and unchanged submissions should still be handled correctly
- validation should not depend on rendering extra buffer rows
- compact layout should avoid mutating the buffer in ways that make prompt editing feel unlike the old rename flow

If feedback is needed for invalid submission, it should not force the compact buffer to become a multi-line panel by default.

## Testing

Planning and implementation should include:

- shared panel unit coverage for layout normalization and defaulting
- `rename` regression coverage proving compact layout renders a single-line prompt buffer
- `rename` coverage proving helper/footer rows are not rendered into the buffer
- `rename` coverage proving prompt editing remains possible
- `rename` coverage proving submit/cancel/cursor behavior stays aligned with the old flow
- confirmation that existing `codeactions` and `formatters` coverage stays green under `standard`

## Acceptance Criteria

This design is successful when:

- shared panel supports `layout = 'standard' | 'compact'`
- `rename` defaults to `compact`
- `rename` behaves like the old single-line prompt flow while still using shared panel code
- `codeactions` and `formatters` remain on the richer shared layout unchanged
- implementation can proceed without reopening the question of whether rename should fork away from shared panel infrastructure
