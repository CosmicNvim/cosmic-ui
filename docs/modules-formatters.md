# formatters

Formatter controls wrapper for `cosmic-ui`.
This module validates setup and module enable state, then forwards calls to `cosmic-ui.formatters`.

## Setup

```lua
require("cosmic-ui").setup({
  formatters = {
    enabled = true,
  },
})
```

## ⚙️ Config

```lua
formatters = {
  enabled = true,
}
```

## Types

### `OpenOpts`

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `scope` | `"buffer"\|"global"\|nil` | No | `"buffer"` | Scope shown when UI opens. |
| `bufnr` | `integer\|nil` | No | current buffer (`0`) | Buffer used for discovery and local state. |

### `BackendOpts`

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `scope` | `"buffer"\|"global"\|nil` | No | `"buffer"` | Scope target for backend mutation/query. |
| `bufnr` | `integer\|nil` | No | current buffer (`0`) | Buffer used for local scope operations. |
| `backend` | `"lsp"\|"conform"\|table\|nil` | No | both backends | Backend selector. |

### `ItemOpts`

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `scope` | `"buffer"\|"global"\|nil` | No | `"buffer"` | Scope target for item mutation/query. |
| `bufnr` | `integer\|nil` | No | current buffer (`0`) | Buffer used for local scope operations. |
| `source` | `"lsp"\|"conform"` | Yes | none | Item source namespace. |
| `name` | `string` | Yes | none | Item name (LSP client or conform formatter). |

### `ResetOpts`

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `scope` | `"buffer"\|"global"\|nil` | No | `"buffer"` | Scope target to reset. |
| `bufnr` | `integer\|nil` | No | current buffer (`0`) | Buffer used for local reset scope. |
| `backend` | `"lsp"\|"conform"\|table\|nil` | No | both backends | Backend reset target when resetting backend state. |
| `source` | `"lsp"\|"conform"\|nil` | No | `nil` | Switches reset into item-reset mode. |
| `name` | `string\|nil` | No | `nil` | Item name to reset when `source` is set. |

### `FormatOpts`

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `scope` | `"buffer"\|"global"\|nil` | No | `"buffer"` | Scope for backend/item filtering. |
| `bufnr` | `integer\|nil` | No | current buffer (`0`) | Buffer to format. |
| `backend` | `"lsp"\|"conform"\|table\|nil` | No | both backends | Backend request selector. |
| `conform` | `table\|nil` | No | `{}` | Extra options for conform formatting logic. |
| `lsp` | `table\|nil` | No | `{}` | Extra options for `vim.lsp.buf.format`. |

## Module

All methods below:
- warn and no-op if `setup()` has not run
- warn and no-op if `formatters` is disabled
- otherwise delegate to `require("cosmic-ui.formatters").<method>(opts)`

### `require("cosmic-ui").formatters.open(opts?)`

Opens the formatter toggle UI.
Opts: `OpenOpts`.

### `require("cosmic-ui").formatters.toggle(opts?)`

Toggles backend state (`lsp`/`conform`) for selected scope.
Opts: `BackendOpts`.

### `require("cosmic-ui").formatters.enable(opts?)`

Enables backend state for selected scope.
Opts: `BackendOpts`.

### `require("cosmic-ui").formatters.disable(opts?)`

Disables backend state for selected scope.
Opts: `BackendOpts`.

### `require("cosmic-ui").formatters.toggle_item(opts)`

Toggles one item override.
Opts: `ItemOpts`.

### `require("cosmic-ui").formatters.enable_item(opts)`

Enables one item override.
Opts: `ItemOpts`.

### `require("cosmic-ui").formatters.disable_item(opts)`

Disables one item override.
Opts: `ItemOpts`.

### `require("cosmic-ui").formatters.is_item_enabled(opts)`

Returns whether one item is enabled.
Opts: `ItemOpts`.
Returns: `boolean|nil`.

### `require("cosmic-ui").formatters.reset(opts?)`

Clears backend and/or item overrides.
Opts: `ResetOpts`.

### `require("cosmic-ui").formatters.is_enabled(opts?)`

Returns effective backend state.
Opts: `BackendOpts`.
Returns:
- `boolean` when a single backend is requested
- `{ lsp = boolean, conform = boolean }` when backend is omitted or multiple

### `require("cosmic-ui").formatters.status(opts?)`

Returns formatter status snapshot.
Opts: `OpenOpts`.
Returns: status table with `backends`, `lsp_clients`, and `conform`.
Includes fallback visibility:
- `conform.fallback`:
  - `requested_mode` (`opts.conform.lsp_format` when provided)
  - `global_mode` (from `conform.default_format_opts.lsp_format`)
  - `specific_mode` + `specific_filetype` (from matching `formatters_by_ft` entry)
  - `display_global_mode` (global Conform-config mode source for header rendering)
  - `display_specific_mode` + `display_specific_filetype` (LSP header ghost text context, rendered as `<specific_mode_or_global_mode>`)
  - `mode` (configured mode before backend clamp)
  - `effective_mode` (`"never"|"fallback"|"prefer"|"first"|"last"`)
  - `source` (effective source: `"requested"|"specific"|"global"|"default"|"clamped"`)
  - `configured_source` (pre-clamp source: `"requested"|"specific"|"global"|"default"`)
  - `uses_lsp`, `eligible_clients`, `total_clients`, `reason`
- `lsp_clients[].conform_fallback`:
  - `eligible`, `reason`, `mode`, `effective_mode`, `source`, `configured_source`

### `require("cosmic-ui").formatters.format(opts?)`

Runs synchronous formatting with Conform-first routing.
Opts: `FormatOpts`.
Returns: `boolean|nil`.

Behavior:
- If Conform is installed and conform backend is enabled/requested, runs `conform.format()`.
- Else if LSP backend is enabled/requested, runs `vim.lsp.buf.format()`.
- Under Conform path:
  - LSP toggle OFF forces `conform.lsp_format = "never"`.
  - LSP toggle ON uses mode precedence:
    - `opts.conform.lsp_format` (requested) >
    - matching Conform filetype mode (`formatters_by_ft`) >
    - Conform global default (`default_format_opts.lsp_format`) >
    - `"never"` default
  - Supported `lsp_format` values:
    - `"never"`: never use LSP
    - `"fallback"`: use LSP only when no other formatters are available
    - `"prefer"`: use only LSP when available
    - `"first"`: run LSP then other formatters
    - `"last"`: run other formatters then LSP

### `require("cosmic-ui").formatters.format_async(opts?)`

Runs asynchronous formatting with the same routing rules as `format`.
Opts: `FormatOpts`.
Returns: `boolean|nil`.

## Usage

```lua
local fmt = require("cosmic-ui").formatters

fmt.open()
fmt.toggle({ backend = "lsp" })
fmt.format_async({ backend = { "conform", "lsp" } })
```

### Conform `format_on_save` example

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

Notes:
- This example makes save-formatting honor CosmicUI Conform item toggles.
- LSP code-action save hooks (for example ESLint fix-all) are separate from Conform formatting.
