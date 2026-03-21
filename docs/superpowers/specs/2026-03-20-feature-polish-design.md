# Cosmic UI Feature Polish Design

Date: 2026-03-20
Status: Approved for planning

## Summary

This design defines a cross-feature polish pass for `cosmic-ui` focused on visual quality, clearer interaction design, and stronger handling of imperfect states. The work covers `rename`, `codeactions`, and `formatters`, with `codeactions` serving as the reference surface for the shared UI language.

The goal is not to expand the plugin into a different product. The goal is to make the existing features feel intentionally designed, resilient, and recognizably "Cosmic" while preserving the current Lua API surface and keeping any new affordances optional.

## Goals

- Give all three features a coherent visual identity and interaction model.
- Improve readability with stronger hierarchy, clearer labels, and more expressive state rendering.
- Make loading, empty, unavailable, and error states explicit inside the UI where possible.
- Improve keyboard flow and focus restoration so interactions feel deliberate instead of fragile.
- Allow optional discoverability affordances, including Ex commands, without replacing the Lua API-first model.

## Non-Goals

- Replacing the existing Lua APIs with command-only workflows.
- Rewriting feature semantics such as how code actions are requested or how formatter state is computed.
- Adding major new product areas unrelated to the current three feature modules.
- Turning this pass into a broad architecture rewrite beyond UI and interaction infrastructure needed for the polish work.

## Product Direction

The post-polish plugin should feel more opinionated and more visually distinctive than it does today. The desired personality is "Cosmic": stronger than stock Neovim, but still compatible with native workflows and current plugin usage.

Three principles define the pass:

1. Shared identity
   Every float should feel like part of the same product, with consistent titles, spacing, section treatment, status language, and key-hint patterns.

2. Explicit states
   When nothing useful can happen, the UI should say exactly why. Silent closes, vague warnings, and visually ambiguous empty states should be reduced.

3. Predictable interaction
   Selection, submit, cancel, navigation, and focus restoration should behave consistently across all feature surfaces.

## Shared UI Model

Introduce a shared internal panel layer used by list-style and prompt-style floats. This is internal infrastructure, not a new public API commitment.

The shared panel model should support:

- Header area
  - Primary title
  - Optional subtitle or context line
  - Optional status badge or count
- Body area
  - Rows for list-based UIs
  - Prompt layout for input-based UIs
  - Consistent padding and highlight treatment
- Footer area
  - Compact key hints
  - Brief state text when needed
- Shared states
  - `loading`
  - `ready`
  - `empty`
  - `unavailable`
  - `error`
- Shared interaction behavior
  - next/previous movement
  - wrap behavior
  - submit and cancel
  - focus restoration to the originating window

The shared layer is responsible for presentation and interaction behavior, not feature-specific meaning. Feature modules keep ownership of request building, response transformation, formatter status computation, and rename submission logic.

## Feature Design

## Codeactions

`codeactions` becomes the reference implementation for the new panel model.

Desired behavior:

- Render as a real action panel rather than a minimally formatted list.
- Keep deterministic grouping by client, but present each client as a proper section header instead of divider text.
- Show more context up front, such as action count and a lightweight subtitle for the current request context.
- Make the current selection visually obvious.

State handling:

- `loading`: visible while client requests are in flight.
- `empty`: explicit "no actions found" state instead of an abrupt no-result outcome.
- `error`: explicit failure message when request execution fails.
- partial failure: when some clients fail and others succeed, keep usable results visible and surface that the response is incomplete.

Interaction:

- Keep `j/k`, arrow keys, `Tab`, `Enter`, `Esc`, and `Ctrl-c`.
- Preserve quick confirm on `Enter`.
- If the action list is short, allow optional direct numeric activation for the first visible actions.
- Closing the panel must restore focus cleanly.

Optional discoverability:

- `:CosmicCodeActions`

Not required in the initial implementation:

- Auto-apply single action behavior. This may be considered later, but it is not part of this design by default.

## Rename

`rename` should become a compact prompt panel instead of a bare one-line input float.

Desired behavior:

- Show a title and brief context around the current symbol.
- Present the prompt with clearer structure and spacing.
- Preserve the current simple rename flow while making the interaction feel intentional.

State handling:

- `unavailable`: clear in-UI explanation when no rename-capable LSP clients are attached.
- validation feedback for:
  - unchanged name
  - empty input
- avoid fragile-feeling cursor behavior around the prompt prefix.

Interaction:

- Submit and cancel should match the other panels.
- Cursor placement and editing should feel like a dedicated prompt, not a raw buffer trick.
- Closing should restore the originating context reliably before dispatching the rename.

Optional discoverability:

- `:CosmicRename`

## Formatters

`formatters` already has the richest UI structure and should be visually aligned with the new panel model instead of replaced.

Desired behavior:

- Keep the current capability set: scope switching, item toggling, reset, and format actions.
- Improve scanability of section headers, backend state, scope state, and row meaning.
- Surface more meaning in the rows themselves so the footer does less explanatory work.

State handling:

- Improve readability of unavailable and empty rows.
- Keep detailed formatter and fallback status available, but render it in a more legible hierarchy.
- Preserve informative backend state without making the panel feel dense or cryptic.

Interaction:

- Retain current power-user flows while making navigation and row intent clearer.
- Keep scope switching, reset, toggle-all, and format actions available.
- Align selection and close behavior with the shared panel model.

Optional discoverability:

- `:CosmicFormatters`
- `:CosmicFormat`

## Discoverability

The plugin remains Lua API-first. Optional Ex commands are allowed where they materially improve discoverability or provide a more obvious entry point.

Command additions in scope:

- `:CosmicRename`
- `:CosmicCodeActions`
- `:CosmicFormatters`
- `:CosmicFormat`

These commands should be documented as convenience entry points, not replacements for the existing Lua API.

## Architecture

Implementation should favor small, well-bounded units:

- shared panel/presentation modules for common float behavior
- feature-specific adapters for row construction, state mapping, and submit actions
- isolated highlight/state helpers where visual semantics are reused

Expected architectural rules:

- Keep public feature modules (`rename`, `codeactions`, `formatters`) as the user-facing boundary.
- Do not push feature-specific business logic into shared UI infrastructure.
- Prefer composable rendering/state helpers over large monolithic UI files.
- Where existing files have become too presentation-heavy, split them along stable responsibilities rather than adding more branching in place.

## Error Handling

State handling should follow these rules:

- If no float is opened, warnings/notifications may still be used.
- Once a float is open, user feedback should be rendered inside the float first when practical.
- Partial failures should not discard successful data if the feature can still proceed meaningfully.
- Empty and unavailable states should be descriptive enough that a planner or implementer does not need to infer intent.

## Testing

Planning and implementation should include targeted coverage for:

- shared row/state builders
- selection behavior and wrap behavior
- state rendering for `loading`, `empty`, `unavailable`, and `error`
- code action grouping and partial failure handling
- rename validation for unchanged and empty submissions
- formatter row/status rendering when backends or items are unavailable
- focus restoration and invalid buffer/window edge cases where applicable

Documentation verification should include:

- README updates
- `:help cosmic-ui` updates
- any new command documentation
- examples that stay aligned with the final public behavior

## Planning Constraints

The implementation plan should stay focused on a single polish initiative, not multiple unrelated projects. It should treat shared panel infrastructure as support work for the three existing features, not as a new standalone framework.

The plan should prioritize:

1. shared UI primitives and state rendering
2. `codeactions` migration to the new model
3. `rename` migration to the new model
4. `formatters` alignment with the new model
5. optional command and documentation updates

## Acceptance Criteria

This design is successful when:

- `rename`, `codeactions`, and `formatters` visibly share the same design language
- empty, unavailable, and error situations are explicit and understandable
- interaction flow feels consistent across all three features
- optional commands improve discoverability without displacing Lua APIs
- the resulting implementation plan can be written without inventing missing requirements
