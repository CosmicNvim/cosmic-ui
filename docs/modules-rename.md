# rename

Rename UI wrapper for `cosmic-ui`.
This module validates setup and module enable state, then forwards calls to `cosmic-ui.rename`.

## Setup

```lua
require("cosmic-ui").setup({
  rename = {
    enabled = true,
  },
})
```

## ⚙️ Config

```lua
rename = {
  enabled = true,
  border = {
    highlight = "FloatBorder",
    style = nil, -- falls back to vim.o.winborder
    title = "Rename",
    title_align = "left",
    title_hl = "FloatBorder",
  },
  prompt = "> ",
  prompt_hl = "Comment",
}
```

## Types

### `popup_opts`

NUI popup options forwarded to rename input popup.

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `position` | `table\|nil` | No | `{ row = 1, col = 0 }` | Cursor-relative popup position. |
| `size` | `table\|nil` | No | computed width, `height = 2` | Popup size for rename input window. |
| `relative` | `string\|nil` | No | `"cursor"` | Popup anchor mode. |
| `border` | `table\|nil` | No | from rename config | Border styling and title options. |

### `opts`

NUI input options forwarded to rename input behavior.

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `prompt` | `any\|nil` | No | `Text(prompt)` | Prompt content shown in input. |
| `default_value` | `string\|nil` | No | current word | Initial value in rename input. |
| `on_submit` | `function\|nil` | No | built-in rename submit | Callback executed when user submits value. |

## Module

### `require("cosmic-ui").rename.open(popup_opts?, opts?)`

Opens the rename input UI for the symbol under cursor.

Behavior:
- warns and no-ops if `setup()` has not run
- warns and no-ops if `rename` is disabled
- forwards to `require("cosmic-ui.rename")(popup_opts, opts)` when enabled

```lua
require("cosmic-ui").rename.open()
```

```lua
require("cosmic-ui").rename.open(
  { size = { width = 40, height = 2 } },
  { default_value = "new_symbol_name" }
)
```
