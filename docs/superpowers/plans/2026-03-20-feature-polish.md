# Cosmic UI Feature Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved cross-feature polish pass so `rename`, `codeactions`, and `formatters` share a stronger Cosmic UI language, clearer state handling, and optional discoverability commands.

**Architecture:** Add a small shared internal panel layer under `lua/cosmic-ui/ui/` for common float rendering, highlight setup, key-hint composition, and state rows. Migrate `codeactions` first as the reference implementation, then move `rename` onto the same prompt-panel model, and finally align `formatters` to the shared presentation and interaction rules without changing its core status logic.

**Tech Stack:** Lua, Neovim 0.11 APIs, plenary.nvim (test harness), native Neovim floating windows, existing `cosmic-ui` modules and docs.

---

## File Structure

### New files

- `lua/cosmic-ui/ui/constants.lua`
  Shared icons, spacing defaults, panel titles, and highlight link names used by all three UIs.
- `lua/cosmic-ui/ui/highlights.lua`
  Shared highlight creation and panel-level highlight application.
- `lua/cosmic-ui/ui/panel.lua`
  Shared float lifecycle helpers for titled panels, footer hints, cursorline behavior, and common state rendering.
- `lua/cosmic-ui/ui/states.lua`
  Helpers that build standard `loading`, `empty`, `unavailable`, and `error` row payloads.
- `tests/minimal_init.lua`
  Headless test bootstrap for runtimepath setup and Plenary test execution.
- `tests/ui/panel_spec.lua`
  Regression coverage for shared panel/state rendering.
- `tests/codeactions/model_spec.lua`
  Coverage for grouped rows, counts, and partial-error metadata.
- `tests/codeactions/ui_spec.lua`
  Coverage for code action state rendering and keymap behavior.
- `tests/rename/ui_spec.lua`
  Coverage for prompt validation and submit/cancel behavior.
- `lua/cosmic-ui/rename/model.lua`
  Isolated rename prompt normalization and validation helpers so prompt rules can be tested without opening a float.
- `tests/formatters/rows_spec.lua`
  Coverage for formatter row shaping and richer unavailable/empty rows.
- `tests/commands_spec.lua`
  Coverage for optional `:Cosmic...` command registration.

### Modified files

- `lua/cosmic-ui/window.lua`
  Reuse shared window defaults and any new focus/cursor restoration helpers needed by the panel layer.
- `lua/cosmic-ui/codeactions/request.lua`
  Preserve per-client success/error data so the UI can render partial failures and loading completion cleanly.
- `lua/cosmic-ui/codeactions/ui/init.lua`
  Switch to the shared panel layer and structured state handling.
- `lua/cosmic-ui/codeactions/ui/model.lua`
  Build section rows, action rows, count metadata, and partial-error status rows.
- `lua/cosmic-ui/codeactions/ui/render.lua`
  Apply shared panel rendering instead of bespoke list rendering.
- `lua/cosmic-ui/codeactions/ui/input.lua`
  Keep current navigation and add optional numeric picks for short lists.
- `lua/cosmic-ui/codeactions/ui/lifecycle.lua`
  Align panel lifecycle and focus restoration with the shared layer.
- `lua/cosmic-ui/rename/ui.lua`
  Refactor the current one-line prompt into a compact prompt panel with inline validation.
- `lua/cosmic-ui/formatters/constants.lua`
  Remove formatter-only UI constants that move into the shared UI layer; keep formatter-domain constants only.
- `lua/cosmic-ui/formatters/ui/init.lua`
  Open the formatter UI through the shared panel primitives.
- `lua/cosmic-ui/formatters/ui/render.lua`
  Adopt shared header/footer/state rendering.
- `lua/cosmic-ui/formatters/ui/highlights.lua`
  Keep formatter-specific row highlighting only where shared highlighting is insufficient.
- `lua/cosmic-ui/formatters/ui/rows.lua`
  Emit richer row metadata and clearer explanatory text.
- `lua/cosmic-ui/formatters/ui/input.lua`
  Preserve existing power-user mappings while aligning close/selection behavior.
- `plugin/cosmic-ui.lua`
  Register optional `:CosmicRename`, `:CosmicCodeActions`, `:CosmicFormatters`, and `:CosmicFormat` commands.
- `doc/cosmic-ui.txt`
  Document the polished behaviors and optional commands.
- `readme.md`
  Refresh feature descriptions and usage examples.
- `docs/features.md`
  Keep the repo-facing feature guide aligned with the new behavior.
- `docs/rename.md`
  Document the prompt panel behavior and validation states.
- `docs/codeactions.md`
  Document the action panel states and optional command.
- `docs/formatters.md`
  Document the aligned panel behavior and optional commands.

## Task 1: Test Harness Bootstrap

**Files:**
- Create: `tests/minimal_init.lua`
- Create: `tests/ui/panel_spec.lua`

- [ ] **Step 1: Write the failing smoke test for the shared panel layer**

```lua
describe("cosmic-ui.ui.panel", function()
  it("builds a standard empty state row", function()
    local states = require("cosmic-ui.ui.states")
    local row = states.empty("No code actions found")
    assert.are.equal("empty", row.state)
    assert.are.equal("No code actions found", row.text)
  end)
end)
```

- [ ] **Step 2: Add the headless Neovim test bootstrap**

```lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
for _, path in ipairs(vim.fn.globpath(vim.fn.stdpath("data") .. "/site/pack/*/start", "plenary.nvim", false, true)) do
  vim.opt.runtimepath:append(path)
end
vim.opt.swapfile = false
vim.opt.shadafile = "NONE"
```

- [ ] **Step 3: Run the targeted test and confirm it fails because the shared UI modules do not exist yet**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/ui/panel_spec.lua" -c qa`

Expected: FAIL with `module 'cosmic-ui.ui.states' not found` or equivalent missing-module error.

- [ ] **Step 4: Add the minimal shared UI module skeletons needed by the smoke test**

```lua
-- lua/cosmic-ui/ui/states.lua
local M = {}

function M.empty(text)
  return { kind = "state", state = "empty", text = text }
end

return M
```

- [ ] **Step 5: Re-run the targeted test and confirm it passes**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/ui/panel_spec.lua" -c qa`

Expected: PASS for the smoke test.

- [ ] **Step 6: Commit the harness bootstrap**

```bash
git add tests/minimal_init.lua tests/ui/panel_spec.lua lua/cosmic-ui/ui/states.lua
git commit -m "test: bootstrap headless ui specs"
```

## Task 2: Shared Cosmic Panel Infrastructure

**Files:**
- Create: `lua/cosmic-ui/ui/constants.lua`
- Create: `lua/cosmic-ui/ui/highlights.lua`
- Create: `lua/cosmic-ui/ui/panel.lua`
- Modify: `lua/cosmic-ui/window.lua`
- Test: `tests/ui/panel_spec.lua`

- [ ] **Step 1: Expand the shared panel spec with failing coverage for header/footer/state rendering**

```lua
it("normalizes panel metadata for title, subtitle, and footer hints", function()
  local panel = require("cosmic-ui.ui.panel")
  local model = panel.build({
    title = "Code Actions",
    subtitle = "lua • 3 actions",
    footer = { "Enter:apply", "Esc:close" },
    rows = { { kind = "state", state = "empty", text = "No code actions found" } },
  })

  assert.are.equal("Code Actions", model.title)
  assert.are.equal("lua • 3 actions", model.subtitle)
  assert.are.same({ "Enter:apply", "Esc:close" }, model.footer)
end)
```

- [ ] **Step 2: Run the shared UI spec and confirm it fails on missing `panel` and highlight behavior**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/ui/panel_spec.lua" -c qa`

Expected: FAIL with missing module or missing field assertions for panel metadata.

- [ ] **Step 3: Implement the shared constants, highlight links, and panel builder**

```lua
-- lua/cosmic-ui/ui/constants.lua
return {
  padding = { x = 1, y = 0 },
  hints = { submit = "Enter", close = "Esc" },
  highlight_links = {
    CosmicUiPanelTitle = "Title",
    CosmicUiPanelSubtitle = "Comment",
    CosmicUiPanelSection = "Type",
    CosmicUiPanelHintKey = "Special",
    CosmicUiPanelHintText = "Comment",
    CosmicUiPanelStateInfo = "Comment",
    CosmicUiPanelStateWarn = "WarningMsg",
    CosmicUiPanelStateError = "ErrorMsg",
  },
}
```

```lua
-- lua/cosmic-ui/ui/panel.lua
local M = {}

function M.build(opts)
  return {
    title = opts.title,
    subtitle = opts.subtitle,
    footer = opts.footer or {},
    rows = opts.rows or {},
    selected = opts.selected,
  }
end

return M
```

- [ ] **Step 4: Add the window/focus helpers the shared layer needs and keep them generic**

```lua
function M.restore_focus(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
end
```

- [ ] **Step 5: Re-run the shared panel spec and confirm it passes**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/ui/panel_spec.lua" -c qa`

Expected: PASS for the shared panel/state tests.

- [ ] **Step 6: Commit the shared infrastructure**

```bash
git add lua/cosmic-ui/ui/constants.lua lua/cosmic-ui/ui/highlights.lua lua/cosmic-ui/ui/panel.lua lua/cosmic-ui/ui/states.lua lua/cosmic-ui/window.lua tests/ui/panel_spec.lua
git commit -m "feat: add shared cosmic panel primitives"
```

## Task 3: Codeactions Migration

**Files:**
- Modify: `lua/cosmic-ui/codeactions/request.lua`
- Modify: `lua/cosmic-ui/codeactions/ui/init.lua`
- Modify: `lua/cosmic-ui/codeactions/ui/model.lua`
- Modify: `lua/cosmic-ui/codeactions/ui/render.lua`
- Modify: `lua/cosmic-ui/codeactions/ui/input.lua`
- Modify: `lua/cosmic-ui/codeactions/ui/lifecycle.lua`
- Test: `tests/codeactions/model_spec.lua`
- Test: `tests/codeactions/ui_spec.lua`

- [ ] **Step 1: Write failing model specs for grouped rows, counts, and partial failures**

```lua
it("keeps successful actions visible when one client errors", function()
  local model = require("cosmic-ui.codeactions.ui.model")
  local built = model.build({
    [1] = {
      client = { id = 1, name = "lua_ls" },
      result = { { title = "Organize Imports" } },
    },
    [2] = {
      client = { id = 2, name = "eslint" },
      error = { code = -1, message = "request failed" },
      result = nil,
    },
  })

  assert.are.equal(1, #built.actions)
  assert.are.equal(true, built.has_partial_error)
end)
```

- [ ] **Step 2: Run the codeactions specs and confirm they fail against the current model**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/codeactions/model_spec.lua" -c "PlenaryBustedFile tests/codeactions/ui_spec.lua" -c qa`

Expected: FAIL because partial-error metadata, state rows, and shared panel rendering do not exist yet.

- [ ] **Step 3: Update request/model/init code to keep enough metadata for `loading`, `empty`, and partial-failure states**

```lua
return {
  rows = rows,
  actions = actions,
  min_width = min_width,
  title = "Code Actions",
  subtitle = ("%s actions"):format(#actions),
  has_partial_error = has_partial_error,
  error_count = error_count,
}
```

- [ ] **Step 4: Replace bespoke render/input behavior with shared panel rendering plus optional numeric picks**

```lua
map("n", "1", function() submit_index(1) end)
map("n", "2", function() submit_index(2) end)
```

- [ ] **Step 5: Re-run the codeactions specs and then the full suite**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/codeactions/model_spec.lua" -c "PlenaryBustedFile tests/codeactions/ui_spec.lua" -c qa`

Expected: PASS for codeactions specs.

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests { minimal_init = 'tests/minimal_init.lua' }" -c qa`

Expected: PASS for the full suite so far.

- [ ] **Step 6: Commit the codeactions migration**

```bash
git add lua/cosmic-ui/codeactions/request.lua lua/cosmic-ui/codeactions/ui/init.lua lua/cosmic-ui/codeactions/ui/model.lua lua/cosmic-ui/codeactions/ui/render.lua lua/cosmic-ui/codeactions/ui/input.lua lua/cosmic-ui/codeactions/ui/lifecycle.lua tests/codeactions/model_spec.lua tests/codeactions/ui_spec.lua
git commit -m "feat: polish codeactions panel states"
```

## Task 4: Rename Prompt Panel Migration

**Files:**
- Create: `lua/cosmic-ui/rename/model.lua`
- Modify: `lua/cosmic-ui/rename/ui.lua`
- Test: `tests/rename/ui_spec.lua`

- [ ] **Step 1: Write failing rename specs for unchanged names, empty names, and restored focus on submit/cancel**

```lua
it("rejects empty submissions without dispatching rename", function()
  local model = require("cosmic-ui.rename.model")
  local result = model.normalize_submission("> ", "> ")
  assert.are.same({ ok = false, reason = "empty" }, result)
end)
```

- [ ] **Step 2: Run the rename spec and confirm it fails on missing helpers and validation behavior**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/rename/ui_spec.lua" -c qa`

Expected: FAIL because `cosmic-ui.rename.model` and the new validation behavior do not exist yet.

- [ ] **Step 3: Add `rename/model.lua` and refactor `rename/ui.lua` so normalization, rendering, and submit logic are isolated**

```lua
local M = {}

function M.normalize_submission(prompt, raw_line, current_name)
  local submitted = vim.startswith(raw_line, prompt) and raw_line:sub(#prompt + 1) or raw_line
  if submitted == "" then
    return { ok = false, reason = "empty" }
  end
  if submitted == current_name then
    return { ok = false, reason = "unchanged" }
  end
  return { ok = true, value = submitted }
end

return M
```

- [ ] **Step 4: Render the rename UI through the shared prompt-panel structure and show inline validation copy**

```lua
local rows = {
  { kind = "context", text = ("Current: %s"):format(curr_name) },
  validation_row,
}
```

- [ ] **Step 5: Re-run the rename spec and the full suite**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/rename/ui_spec.lua" -c qa`

Expected: PASS for rename validation and focus behavior.

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests { minimal_init = 'tests/minimal_init.lua' }" -c qa`

Expected: PASS for the full suite.

- [ ] **Step 6: Commit the rename migration**

```bash
git add lua/cosmic-ui/rename/model.lua lua/cosmic-ui/rename/ui.lua tests/rename/ui_spec.lua
git commit -m "feat: polish rename prompt panel"
```

## Task 5: Formatters Alignment

**Files:**
- Modify: `lua/cosmic-ui/formatters/constants.lua`
- Modify: `lua/cosmic-ui/formatters/ui/init.lua`
- Modify: `lua/cosmic-ui/formatters/ui/render.lua`
- Modify: `lua/cosmic-ui/formatters/ui/highlights.lua`
- Modify: `lua/cosmic-ui/formatters/ui/rows.lua`
- Modify: `lua/cosmic-ui/formatters/ui/input.lua`
- Test: `tests/formatters/rows_spec.lua`

- [ ] **Step 1: Write failing formatter row specs for richer unavailable/empty text and shared section metadata**

```lua
it("renders conform-unavailable rows with explanatory text", function()
  local rows = require("cosmic-ui.formatters.ui.rows")
  local built = rows.build_rows({
    conform = { available = false, reason = "conform unavailable", formatters = {}, fallback = {} },
    lsp_clients = {},
  }, { conform = "C", lsp = "L", file = "F", filetype = "lua" }, { unavailable = "!" })

  assert.is_truthy(vim.tbl_contains(vim.tbl_map(function(row) return row.id end, built), "conform_unavailable"))
end)
```

- [ ] **Step 2: Run the formatter spec and confirm it fails against the current row shape**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/formatters/rows_spec.lua" -c qa`

Expected: FAIL because the current rows do not carry the richer shared-panel metadata yet.

- [ ] **Step 3: Move only generic UI constants to the shared layer and update formatter rows/rendering to consume it**

```lua
table.insert(rows, {
  id = "section_lsp",
  kind = "section",
  text = "LSP",
  subtitle = lsp_header_mode,
})
```

- [ ] **Step 4: Update formatter input/footer rendering so the panel still exposes scope/reset/toggle/format actions but with the shared footer style**

```lua
ui.footer = {
  "Tab:toggle",
  "s:scope",
  "r:reset",
  "a:toggle all",
  "f:format",
  "q:close",
}
```

- [ ] **Step 5: Re-run the formatter spec and the full suite**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/formatters/rows_spec.lua" -c qa`

Expected: PASS for formatter row/rendering coverage.

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests { minimal_init = 'tests/minimal_init.lua' }" -c qa`

Expected: PASS for the full suite.

- [ ] **Step 6: Commit the formatter alignment**

```bash
git add lua/cosmic-ui/formatters/constants.lua lua/cosmic-ui/formatters/ui/init.lua lua/cosmic-ui/formatters/ui/render.lua lua/cosmic-ui/formatters/ui/highlights.lua lua/cosmic-ui/formatters/ui/rows.lua lua/cosmic-ui/formatters/ui/input.lua tests/formatters/rows_spec.lua
git commit -m "feat: align formatter panel with cosmic ui"
```

## Task 6: Commands and Documentation

**Files:**
- Create: `tests/commands_spec.lua`
- Modify: `plugin/cosmic-ui.lua`
- Modify: `doc/cosmic-ui.txt`
- Modify: `readme.md`
- Modify: `docs/features.md`
- Modify: `docs/rename.md`
- Modify: `docs/codeactions.md`
- Modify: `docs/formatters.md`

- [ ] **Step 1: Write the failing command spec**

```lua
it("registers optional Cosmic commands", function()
  vim.cmd("runtime plugin/cosmic-ui.lua")
  local commands = vim.api.nvim_get_commands({})
  assert.is_truthy(commands.CosmicRename)
  assert.is_truthy(commands.CosmicCodeActions)
  assert.is_truthy(commands.CosmicFormatters)
  assert.is_truthy(commands.CosmicFormat)
end)
```

- [ ] **Step 2: Run the command/doc spec and confirm the commands are not registered yet**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/commands_spec.lua" -c qa`

Expected: FAIL because the commands do not exist yet.

- [ ] **Step 3: Add the commands in `plugin/cosmic-ui.lua` and wire them to the existing Lua APIs**

```lua
vim.api.nvim_create_user_command("CosmicRename", function()
  require("cosmic-ui").rename.open()
end, {})
```

- [ ] **Step 4: Update help and Markdown docs to describe the polished panels and optional commands**

```text
:CosmicCodeActions   Open the Cosmic code action panel
:CosmicRename        Open the Cosmic rename prompt
```

- [ ] **Step 5: Run command spec, then run formatting, then run the full suite**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/commands_spec.lua" -c qa`

Expected: PASS for command registration.

Run: `stylua lua plugin tests`

Expected: formatting succeeds with no parse errors.

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests { minimal_init = 'tests/minimal_init.lua' }" -c qa`

Expected: PASS for all tests.

- [ ] **Step 6: Commit commands and docs**

```bash
git add plugin/cosmic-ui.lua doc/cosmic-ui.txt readme.md docs/features.md docs/rename.md docs/codeactions.md docs/formatters.md tests/commands_spec.lua
git commit -m "docs: add cosmic ui command and polish docs"
```

## Final Verification

- [ ] Run: `stylua lua plugin tests`
  Expected: no formatting errors.
- [ ] Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests { minimal_init = 'tests/minimal_init.lua' }" -c qa`
  Expected: full suite passes.
- [ ] Run a manual smoke pass in Neovim for:
  - `require("cosmic-ui").codeactions.open()`
  - `require("cosmic-ui").rename.open()`
  - `require("cosmic-ui").formatters.open()`
  - `:CosmicCodeActions`, `:CosmicRename`, `:CosmicFormatters`, `:CosmicFormat`
- [ ] Confirm `readme.md` and `doc/cosmic-ui.txt` describe the same commands and polished behaviors.
