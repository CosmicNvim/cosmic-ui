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
| `backend` | `"lsp"\|"conform"\|table\|nil` | No | both backends | Backend(s) to run. |
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

### `require("cosmic-ui").formatters.format(opts?)`

Runs synchronous formatting for enabled backends.
Opts: `FormatOpts`.
Returns: `boolean|nil`.

### `require("cosmic-ui").formatters.format_async(opts?)`

Runs asynchronous formatting for enabled backends.
Opts: `FormatOpts`.
Returns: `boolean|nil`.

## Usage

```lua
local fmt = require("cosmic-ui").formatters

fmt.open()
fmt.toggle({ backend = "lsp" })
fmt.format_async({ backend = { "conform", "lsp" } })
```
