# diagnostics

Diagnostics module for `cosmic-ui`.
This module validates setup/module enable state and provides a diagnostics picker plus location-list export.

## Setup

```lua
require("cosmic-ui").setup({
  diagnostics = {
    enabled = true,
  },
})
```

## ⚙️ Config

```lua
diagnostics = {
  enabled = true,
  scope = "buffer", -- "buffer" or "workspace"
  max_items = 300,
  min_width = nil,
  border = {
    highlight = "FloatBorder",
    style = nil, -- falls back to vim.o.winborder
    title = "Diagnostics",
    title_align = "center",
    title_hl = "FloatBorder",
  },
}
```

## Types

### `opts`

Optional diagnostics options used by `open()` and `setloclist()`.

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `scope` | `"buffer"\|"workspace"\|nil` | No | `diagnostics.scope` | Scope used to collect diagnostics. |
| `bufnr` | `integer\|nil` | No | current buffer (`0`) | Buffer used when `scope = "buffer"`. |
| `severity` | `integer\|"error"\|"warn"\|"info"\|"hint"\|nil` | No | `nil` | Optional severity filter. |
| `max_items` | `integer\|nil` | No | `diagnostics.max_items` | Max diagnostics returned in one render/export. |

## Module

### `require("cosmic-ui").diagnostics.open(opts?)`

Opens a floating diagnostics picker.

Behavior:
- warns and no-ops if `setup()` has not run
- warns and no-ops if `diagnostics` is disabled
- shows diagnostics sorted by severity, then location
- supports `q`/`<Esc>` close, `r` refresh, `<CR>` jump to selected diagnostic

```lua
vim.keymap.set("n", "<leader>gd", function()
  require("cosmic-ui").diagnostics.open()
end, { silent = true, desc = "Diagnostics (buffer)" })
```

```lua
require("cosmic-ui").diagnostics.open({
  scope = "workspace",
  severity = "error",
})
```

### `require("cosmic-ui").diagnostics.setloclist(opts?)`

Builds the window location list from diagnostics and opens it (`:lopen`) when items exist.

```lua
vim.keymap.set("n", "<leader>gD", function()
  require("cosmic-ui").diagnostics.setloclist({ scope = "workspace" })
end, { silent = true, desc = "Diagnostics to loclist" })
```
