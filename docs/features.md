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

### API: `require("cosmic-ui").codeactions.range(opts?)`

Fetches and displays code actions for the active visual selection.

`opts` definition:

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `opts` | `table\|nil` | No | `{}` | Extra options merged into visual-range request opts. |
| `opts.params` | `table\|nil` | No | `nil` | Optional explicit params override. |
| `opts.range` | `table\|nil` | No | visual selection range | Optional range override. |

Behavior:
- Wrapper builds `range` from `'<` and `'>` marks.
- User `opts` are merged on top, so user-provided `opts.range` can override the visual range.

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
  - If LSP backend is enabled, explicit `conform.lsp_format` is respected.
  - If LSP backend is enabled and `conform.lsp_format` is omitted, default is `"fallback"`.
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
