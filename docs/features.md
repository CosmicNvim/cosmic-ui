# Rename, Codeactions, and Formatters

This file explains how to use the three feature modules exposed through `require("cosmic-ui")`.

## Prerequisites

Call setup first, and enable each module you plan to use.

```lua
require("cosmic-ui").setup({
  rename = {},
  codeactions = {},
  formatters = {},
})
```

If setup is not called, or a module is disabled, calls will warn and no-op.

## Rename

Use when you want to rename the symbol under cursor.

### API: `require("cosmic-ui").rename.open(popup_opts?, opts?)`

Opens the rename prompt at cursor, prefilled with the current symbol, then submits `textDocument/rename` to LSP clients that support rename.

`popup_opts` definition:

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `popup_opts` | `table\|nil` | No | `nil` | NUI popup options merged over module defaults before opening input. |
| `popup_opts.position` | `table\|nil` | No | `{ row = 1, col = 0 }` | Cursor-relative popup position. |
| `popup_opts.size` | `table\|nil` | No | auto width, `height = 2` | Popup size. Width grows to fit prompt + current symbol. |
| `popup_opts.relative` | `string\|nil` | No | `"cursor"` | Popup anchor mode. |
| `popup_opts.border` | `table\|nil` | No | from `rename.border` config | Border options for the input popup. |

`opts` definition:

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `opts` | `table\|nil` | No | `nil` | NUI input options merged over module defaults. |
| `opts.prompt` | `any\|nil` | No | `Text(prompt)` | Prompt content for the input. |
| `opts.default_value` | `string\|nil` | No | current word under cursor | Initial value in rename input. |
| `opts.on_submit` | `function\|nil` | No | built-in rename submit handler | Callback invoked with `new_name`. |

### Usage examples

```lua
vim.keymap.set("n", "gn", function()
  require("cosmic-ui").rename.open()
end, { silent = true, desc = "Rename symbol" })
```

```lua
require("cosmic-ui").rename.open(
  { size = { width = 40, height = 2 } },
  { default_value = "new_symbol_name" }
)
```

## Codeactions

Use when you want LSP code actions at cursor or for a selected range.

### API: `require("cosmic-ui").codeactions.open(opts?)`

Fetches and displays code actions for the current cursor context.

`opts` definition:

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `opts` | `table\|nil` | No | `{}` | Optional code action request input. |
| `opts.params` | `table\|nil` | No | `nil` | Full LSP request params table to use. |
| `opts.range` | `table\|nil` | No | `nil` | Range object used to build params when present. |
| `opts.range.start` | `{integer, integer}\|nil` | No | `nil` | Start `{line, col}` pair. |
| `opts.range.end` | `{integer, integer}\|nil` | No | `nil` | End `{line, col}` pair. |

Behavior:
- If `opts.range` is present, range params are built from it.
- Else if `opts.params` is present, `opts.params` is used directly.
- Else cursor-based range params are created automatically.
- Code action menu groups are ordered deterministically by client name (tie-break: client id).
- Action order within each client group follows server response order.

### API: `require("cosmic-ui").codeactions.range(opts?)`

Fetches and displays code actions for the active visual selection.

`opts` definition:

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `opts` | `table\|nil` | No | `{}` | Optional code action request input. |
| `opts.params` | `table\|nil` | No | `nil` | Optional explicit params override. |
| `opts.range` | `table\|nil` | No | `nil` | Optional range override. |

Behavior:
- Uses `opts.range` when provided.
- Else uses `opts.params` when provided.
- Else builds `range` from `'<` and `'>` marks.

### Usage examples

```lua
vim.keymap.set("n", "<leader>ga", function()
  require("cosmic-ui").codeactions.open()
end, { silent = true, desc = "Code actions" })

vim.keymap.set("v", "<leader>ga", function()
  require("cosmic-ui").codeactions.range()
end, { silent = true, desc = "Range code actions" })
```

### Optional advanced opts

```lua
require("cosmic-ui").codeactions.open({
  params = { context = { only = { "quickfix" } } },
})
```

## Formatters

Use when you want to:

- open a UI to toggle formatter sources
- toggle Conform/LSP globally or per buffer
- run formatting with current toggle state

All methods below are called via `require("cosmic-ui").formatters.<method>(opts)`.
For methods that accept `bufnr`, invalid/nonexistent buffer handles warn and no-op.

### API: `open(opts?)`

Opens the formatter toggle floating UI.

`opts` definition:

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `scope` | `"buffer"\|"global"\|nil` | No | `"buffer"` | Scope shown when UI opens. |
| `bufnr` | `integer\|nil` | No | current buffer (`0`) | Buffer used for formatter discovery and scope state. |

### API: `toggle(opts?)`, `enable(opts?)`, `disable(opts?)`

Mutates backend enable state for one or both backends.

`opts` definition:

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `scope` | `"buffer"\|"global"\|nil` | No | `"buffer"` | Override scope target. |
| `bufnr` | `integer\|nil` | No | current buffer (`0`) | Buffer whose local state is read/written. |
| `backend` | `"lsp"\|"conform"\|table\|nil` | No | both backends | Backend(s) to mutate. |

### API: `toggle_item(opts)`, `enable_item(opts)`, `disable_item(opts)`, `is_item_enabled(opts)`

Mutates or queries a single formatter item override.

`opts` definition:

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `scope` | `"buffer"\|"global"\|nil` | No | `"buffer"` | Override scope target. |
| `bufnr` | `integer\|nil` | No | current buffer (`0`) | Buffer whose local state is read/written. |
| `source` | `"lsp"\|"conform"` | Yes | none | Item source namespace. |
| `name` | `string` | Yes | none | LSP client name or conform formatter name. |

Returns:
- `is_item_enabled(opts)` returns `boolean` when inputs are valid, otherwise `nil`.

### API: `reset(opts?)`

Clears backend and/or item overrides.

`opts` definition:

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `scope` | `"buffer"\|"global"\|nil` | No | `"buffer"` | Target scope to reset. |
| `bufnr` | `integer\|nil` | No | current buffer (`0`) | Buffer whose local state is reset. |
| `backend` | `"lsp"\|"conform"\|table\|nil` | No | both backends | Backend reset target (when resetting backend state). |
| `source` | `"lsp"\|"conform"\|nil` | No | `nil` | Switches reset into item-reset mode. |
| `name` | `string\|nil` | No | `nil` | If set with `source`, resets one item; else resets all items for source. |

### API: `is_enabled(opts?)`

Returns effective backend enabled state.

`opts` definition:

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `scope` | `"buffer"\|"global"\|nil` | No | `"buffer"` | Scope to query. |
| `bufnr` | `integer\|nil` | No | current buffer (`0`) | Buffer used for local-state query. |
| `backend` | `"lsp"\|"conform"\|table\|nil` | No | `nil` | If one backend is provided, return single `boolean`. |

Returns:
- `boolean` when one backend is requested.
- `{ lsp = boolean, conform = boolean }` when backend is omitted or multiple.

### API: `status(opts?)`

Returns a formatter status snapshot for UI and inspection.

`opts` definition:

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `scope` | `"buffer"\|"global"\|nil` | No | `"buffer"` | Scope to inspect. |
| `bufnr` | `integer\|nil` | No | current buffer (`0`) | Buffer whose status is inspected. |

Returns:
- Table containing `backends`, `lsp_clients`, and `conform` formatter availability/details.
- `conform.fallback` includes global fallback visibility:
  - `requested_mode` (call-level mode, when provided)
  - `global_mode` (from Conform `default_format_opts.lsp_format`)
  - `specific_mode` (from matched filetype/specific Conform config)
  - `display_global_mode` (UI global mode shown in Conform header ghost text)
  - `display_specific_mode` / `display_specific_filetype` (UI per-item specific mode context)
  - `mode` (configured mode before backend clamp)
  - `effective_mode` (`"never"`, `"fallback"`, `"prefer"`, `"first"`, `"last"`)
  - `source` (effective source: `requested`, `specific`, `global`, `default`, `clamped`)
  - `configured_source` (pre-clamp source: `requested`, `specific`, `global`, `default`)
  - `uses_lsp` (`boolean`)
  - `eligible_clients` / `total_clients`
  - `reason` (for example: `conform unavailable`, `lsp backend disabled`, `no eligible lsp clients`)
- Each `lsp_clients[]` entry includes `conform_fallback`:
  - `eligible` (`boolean`)
  - `reason` (for example: `eligible`, `lsp client disabled`, `lsp client unavailable`)
  - `mode` (configured mode)
  - `effective_mode` (`"never"`, `"fallback"`, `"prefer"`, `"first"`, `"last"`)
  - `source` (effective source) and `configured_source` (pre-clamp source)
- Formatter UI shows:
  - an inline specific-or-global mode value on the LSP header (`<specific_mode_or_global_mode>`)

### API: `format(opts?)`, `format_async(opts?)`

Runs formatting with Conform-first routing while respecting backend toggles.

`opts` definition:

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `scope` | `"buffer"\|"global"\|nil` | No | `"buffer"` | Scope for backend/item filtering. |
| `bufnr` | `integer\|nil` | No | current buffer (`0`) | Buffer to format. |
| `backend` | `"lsp"\|"conform"\|table\|nil` | No | both backends | Backend request selector. |
| `conform` | `table\|nil` | No | `{}` | Extra options passed to conform formatting logic. |
| `lsp` | `table\|nil` | No | `{}` | Extra options passed to `vim.lsp.buf.format`. |

Notes:
- Routing:
  - If Conform is installed and conform backend is enabled/requested, `conform.format()` is used.
  - Else if LSP backend is enabled/requested, `vim.lsp.buf.format()` is used.
  - If neither backend is enabled/requested, formatting no-ops with warning.
- Toggle-authoritative LSP clamping under Conform:
  - If LSP backend is disabled, Conform is forced to `lsp_format = "never"`.
  - If LSP backend is enabled, effective mode precedence is:
    - `opts.conform.lsp_format` (requested) >
    - filetype/specific Conform mode >
    - global Conform default mode >
    - `"never"` default
  - Valid `lsp_format` modes are:
    - `"never"`: never use LSP
    - `"fallback"`: use LSP only when no other formatter runs
    - `"prefer"`: prefer only LSP when available
    - `"first"`: run LSP first, then other formatters
    - `"last"`: run other formatters, then LSP
- `conform.formatters` is intersected with enabled conform items.
- For Conform LSP execution, Conform `filter` is combined with enabled LSP item filtering.

### Usage examples

```lua
vim.keymap.set("n", "<leader>gf", function()
  require("cosmic-ui").formatters.open()
end, { silent = true, desc = "Toggle formatters (buffer)" })

vim.keymap.set("n", "<leader>gF", function()
  require("cosmic-ui").formatters.open({ scope = "global" })
end, { silent = true, desc = "Toggle formatters (global)" })

vim.keymap.set("n", "<leader>fm", function()
  require("cosmic-ui").formatters.format()
end, { silent = true, desc = "Format" })
```

```lua
require("cosmic-ui").formatters.disable({
  backend = "lsp",
  scope = "buffer",
})
```

```lua
require("cosmic-ui").formatters.toggle_item({
  source = "conform",
  name = "stylua",
  scope = "buffer",
})
```

### Conform `format_on_save` example

Use this when you want save-formatting to respect CosmicUI Conform item toggles.
It formats only with enabled Conform formatters and skips save-format when none are enabled.

```lua
require("conform").setup({
  format_on_save = function(bufnr)
    if not vim.g.format_on_save_enabled then
      return
    end

    local ok, cosmic = pcall(require, "cosmic-ui")
    if not (ok and cosmic.is_setup and cosmic.is_setup()) then
      return { timeout_ms = 500, lsp_format = "fallback" }
    end

    local st = cosmic.formatters.status({ scope = "buffer", bufnr = bufnr })
    local enabled = {}
    for _, f in ipairs((st and st.conform and st.conform.formatters) or {}) do
      if f.enabled then
        enabled[#enabled + 1] = f.name
      end
    end

    if #enabled == 0 then
      return nil
    end

    return {
      timeout_ms = 500,
      formatters = enabled,
      lsp_format = "never",
    }
  end,
})
```

Note:
- This controls Conform formatting only.
- LSP code actions on save (for example `source.fixAll.eslint`) are separate and must be configured independently.
