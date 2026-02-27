# rename

Rename UI module for `cosmic-ui`.
This module validates setup and module enable state, then runs rename UI logic directly.

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
  prompt_hl = "Comment", -- highlight group for the prompt prefix text
}
```

## Types

### `opts`

Rename input options.

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `prompt` | `string\|nil` | No | from config (`rename.prompt`) | Prompt text shown in the input. |
| `default_value` | `string\|nil` | No | current word | Initial value in rename input. |
| `on_submit` | `function\|nil` | No | built-in rename submit | Callback executed when user submits value. |
| `window` | `table\|nil` | No | internal defaults + rename config | Native float window overrides. |
| `window.relative` | `string\|nil` | No | `"cursor"` | Float anchor mode. |
| `window.row` | `integer\|nil` | No | `1` | Float row offset. |
| `window.col` | `integer\|nil` | No | `0` | Float column offset. |
| `window.width` | `integer\|nil` | No | auto-fit prompt + symbol | Float width. |
| `window.height` | `integer\|nil` | No | `1` | Float height. |
| `window.zindex` | `integer\|nil` | No | `50` | Float z-index. |
| `window.border` | `table\|nil` | No | from rename border config | Border/title overrides. |
| `window.border.style` | `string\|table\|nil` | No | `vim.o.winborder` | Native border style. |
| `window.border.title` | `string\|nil` | No | from config (`rename.border.title`) | Float title. |
| `window.border.title_align` | `"left"\|"center"\|"right"\|nil` | No | from config | Float title alignment. |
| `window.border.highlight` | `string\|nil` | No | from config | Applied to `FloatBorder` via `winhl`. |
| `window.border.title_hl` | `string\|nil` | No | from config | Applied to `FloatTitle` via `winhl`. |

## Module

### `require("cosmic-ui").rename.open(opts?)`

Opens the rename input UI for the symbol under cursor.

Behavior:
- warns and no-ops if `setup()` has not run
- warns and no-ops if `rename` is disabled
- opens rename UI when enabled
- uses Neovim's native rename flow (`vim.lsp.buf.rename`) after submit
- throws an error on invalid arguments

```lua
require("cosmic-ui").rename.open()
```

```lua
require("cosmic-ui").rename.open({
  default_value = "new_symbol_name",
  window = {
    width = 40,
    border = { title = "Rename Symbol" },
  },
})
```
