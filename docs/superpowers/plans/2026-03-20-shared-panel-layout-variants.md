# Shared Panel Layout Variants Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add shared panel layout variants so `rename` defaults to a compact single-line prompt that behaves like `main` while `codeactions` and `formatters` stay on the richer shared panel layout.

**Architecture:** Extend `lua/cosmic-ui/ui/panel.lua` to normalize a `layout = 'standard' | 'compact'` field and keep `standard` as the default. Then move `rename` onto `layout = 'compact'` using the existing shared panel metadata path, but render only the prompt line in the buffer and restore the old cursor/edit/submit semantics from `main` without forking back to a separate non-panel implementation.

**Tech Stack:** Lua, Neovim 0.11 APIs, plenary.nvim test harness, native floating windows, existing `cosmic-ui` modules.

---

## File Structure

### Modified files

- `lua/cosmic-ui/ui/panel.lua`
  Normalize and expose `layout = 'standard' | 'compact'` on shared panel models.
- `tests/ui/panel_spec.lua`
  Add regression coverage for layout normalization and defaulting.
- `lua/cosmic-ui/rename/ui.lua`
  Make `rename` build a shared panel with `layout = 'compact'` and render a single-line prompt buffer using shared metadata but old prompt behavior.
- `tests/rename/ui_spec.lua`
  Replace multi-line-panel expectations with compact rename behavior expectations and keep validation/submit coverage aligned with `main`-style interaction.

### No new files expected

- Keep this implementation narrow. Do not add a new public config surface or a rename-only UI module unless the shared panel layout boundary proves insufficient.

## Task 1: Add Shared Panel Layout Normalization

**Files:**
- Modify: `lua/cosmic-ui/ui/panel.lua`
- Modify: `tests/ui/panel_spec.lua`

- [ ] **Step 1: Add the failing shared-panel layout spec**

```lua
it('defaults panel layout to standard and preserves compact when requested', function()
  local panel = require('cosmic-ui.ui.panel')

  assert.are.equal('standard', panel.build({}).layout)
  assert.are.equal('compact', panel.build({ layout = 'compact' }).layout)
end)
```

- [ ] **Step 2: Run the shared UI spec and confirm it fails on missing `layout` support**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ui { minimal_init = 'tests/minimal_init.lua' }" -c qa`

Expected: FAIL because `panel.build()` does not currently return a `layout` field.

- [ ] **Step 3: Implement layout normalization in the shared panel model**

```lua
local function normalize_layout(layout)
  if layout == 'compact' then
    return 'compact'
  end
  return 'standard'
end

function M.build(opts)
  opts = opts or {}
  local rows = normalize_rows(opts.rows)

  return {
    layout = normalize_layout(opts.layout),
    title = opts.title or '',
    subtitle = opts.subtitle or '',
    footer = normalize_footer(opts.footer),
    rows = rows,
    selected = normalize_selected(opts.selected, rows),
  }
end
```

- [ ] **Step 4: Re-run the shared UI spec and confirm it passes**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ui { minimal_init = 'tests/minimal_init.lua' }" -c qa`

Expected: PASS for the shared panel spec, including the new layout assertions.

- [ ] **Step 5: Commit the shared layout normalization**

```bash
git add lua/cosmic-ui/ui/panel.lua tests/ui/panel_spec.lua
git commit -m "feat: add shared panel layout variants"
```

## Task 2: Move Rename to Compact Shared-Panel Behavior

**Files:**
- Modify: `lua/cosmic-ui/rename/ui.lua`
- Modify: `tests/rename/ui_spec.lua`

- [ ] **Step 1: Add failing rename specs for compact default behavior**

```lua
it('renders only the prompt line for the default compact layout', function()
  stub_rename_context('current_name')
  local ui = require('cosmic-ui.rename.ui')

  ui.open({ default_value = 'next_name' })

  assert.are.same({ '> next_name' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
end)

it('does not render footer helper rows into the compact rename buffer', function()
  stub_rename_context('current_name')
  local ui = require('cosmic-ui.rename.ui')

  ui.open({ default_value = 'next_name' })

  assert.is_false(vim.tbl_contains(vim.api.nvim_buf_get_lines(0, 0, -1, false), ' Enter:rename  Esc:cancel '))
end)
```

- [ ] **Step 2: Run the rename spec and confirm it fails against the current multi-line rename panel**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/rename { minimal_init = 'tests/minimal_init.lua' }" -c qa`

Expected: FAIL because `rename` currently renders context/footer rows and uses multi-line panel structure.

- [ ] **Step 3: Make `rename` build a compact shared panel and render only the prompt line**

```lua
local function build_panel_model(curr_name, reason)
  return panel.prepare({
    layout = 'compact',
    title = 'Rename',
    rows = {},
    footer = {
      { key = 'Enter', text = 'rename' },
      { key = 'Esc', text = 'cancel' },
    },
  })
end

local function render(ui, value)
  ui.value = value
  ui.panel = build_panel_model(ui.curr_name, ui.validation_reason)

  local prompt_line = ui.prompt .. value
  vim.bo[ui.buf].modifiable = true
  vim.api.nvim_buf_set_lines(ui.buf, 0, -1, false, { prompt_line })
  vim.bo[ui.buf].modifiable = true

  ui.prompt_row = 1
  ui.prompt_col = #ui.prompt
end
```

Implementation notes:

- Keep using `panel.prepare()` and shared title/footer metadata even though compact layout does not render footer/context rows into buffer lines.
- Preserve border/title config through the current merged window options path.
- Keep prompt extmark highlighting.
- Restore the old single-line cursor math from `main` where compact layout is active.

- [ ] **Step 4: Re-run the rename spec and confirm the compact buffer tests pass**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/rename { minimal_init = 'tests/minimal_init.lua' }" -c qa`

Expected: PASS for the new single-line buffer expectations, with any still-failing old multi-line expectations identified for cleanup in the next task.

- [ ] **Step 5: Commit the compact rename default**

```bash
git add lua/cosmic-ui/rename/ui.lua tests/rename/ui_spec.lua
git commit -m "feat: default rename to compact panel layout"
```

## Task 3: Align Rename Interaction Semantics with Main

**Files:**
- Modify: `lua/cosmic-ui/rename/ui.lua`
- Modify: `tests/rename/ui_spec.lua`

- [ ] **Step 1: Replace now-invalid multi-line rename assertions with main-style behavior checks**

```lua
it('keeps the compact rename buffer modifiable for prompt editing', function()
  stub_rename_context('current_name')
  local ui = require('cosmic-ui.rename.ui')

  ui.open({ default_value = 'draft' })

  assert.is_true(vim.bo[vim.api.nvim_get_current_buf()].modifiable)
  assert.are.equal(1, #vim.api.nvim_buf_get_lines(0, 0, -1, false))
end)

it('keeps the cursor constrained to the prompt line in compact layout', function()
  stub_rename_context('current_name')
  local ui = require('cosmic-ui.rename.ui')

  ui.open({ default_value = 'draft' })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.wait(1000, function()
    return vim.api.nvim_win_get_cursor(0)[2] == 2
  end)

  assert.are.same({ 1, 2 }, vim.api.nvim_win_get_cursor(0))
end)
```

- [ ] **Step 2: Run the rename spec and confirm it fails on any remaining behavior drift**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/rename { minimal_init = 'tests/minimal_init.lua' }" -c qa`

Expected: FAIL on any remaining differences in prompt mutability, cursor rules, submit handling, or compact rendering assumptions.

- [ ] **Step 3: Restore old rename prompt semantics while staying on shared metadata**

```lua
local buf = window.create_scratch_buf({
  filetype = 'cosmicui-rename',
  modifiable = true,
  bufhidden = 'wipe',
})

local function ensure_cursor_after_prompt(ui)
  local cursor = vim.api.nvim_win_get_cursor(ui.win)
  local current_line = vim.api.nvim_buf_get_lines(ui.buf, 0, 1, true)[1] or ''
  local min_col = #ui.prompt
  local max_col = #current_line

  if cursor[2] < min_col then
    set_cursor_col(ui, min_col)
  elseif cursor[2] > max_col then
    set_cursor_col(ui, max_col)
  end
end
```

Implementation notes:

- Remove compact-layout footer highlight assertions and multi-line edit-lock behavior from the rename tests. Those belong to `standard`, not compact.
- Keep `model.normalize_submission()` and validation correctness.
- Do not reintroduce context/footer rows as hidden state inside the buffer.
- If current focus restoration differs from `main`, prefer the old rename close behavior unless a specific regression test proves otherwise.

- [ ] **Step 4: Re-run the rename spec and confirm it passes**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/rename { minimal_init = 'tests/minimal_init.lua' }" -c qa`

Expected: PASS for compact single-line rename behavior, prompt editing, submit/cancel, and validation tests.

- [ ] **Step 5: Commit the behavior-alignment cleanup**

```bash
git add lua/cosmic-ui/rename/ui.lua tests/rename/ui_spec.lua
git commit -m "fix: align compact rename behavior with main"
```

## Task 4: Full Verification

**Files:**
- Modify: none expected

- [ ] **Step 1: Run formatting**

Run: `stylua lua plugin tests`

Expected: exit 0.

- [ ] **Step 2: Run the full test suite**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests { minimal_init = 'tests/minimal_init.lua' }" -c qa`

Expected: PASS with 0 failures and 0 errors.

- [ ] **Step 3: Inspect the final diff**

Run: `git diff --stat HEAD~3..HEAD`

Expected: only shared panel layout normalization and compact rename behavior changes.

- [ ] **Step 4: Commit any final formatting-only fallout if needed**

```bash
git add lua/cosmic-ui/ui/panel.lua lua/cosmic-ui/rename/ui.lua tests/ui/panel_spec.lua tests/rename/ui_spec.lua
git commit -m "style: format shared panel layout changes"
```

Only do this if `stylua` changes files after the feature commits.
