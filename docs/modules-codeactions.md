# codeactions

Code actions wrapper for `cosmic-ui`.
This module validates setup and module enable state, then forwards calls to `cosmic-ui.code-action`.

## Setup

```lua
require("cosmic-ui").setup({
  codeactions = {
    enabled = true,
  },
})
```

## ⚙️ Config

```lua
codeactions = {
  enabled = true,
  min_width = nil,
  border = {
    bottom_hl = "FloatBorder",
    highlight = "FloatBorder",
    style = nil, -- falls back to vim.o.winborder
    title = "Code Actions",
    title_align = "center",
    title_hl = "FloatBorder",
  },
}
```

## Types

### `opts`

Optional request options passed to the code action core module.

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `params` | `table\|nil` | No | `nil` | Explicit LSP request params. |
| `range` | `table\|nil` | No | `nil` | Optional range `{ start, end }`. |
| `range.start` | `{integer, integer}\|nil` | No | `nil` | Optional start position `{line, col}`. |
| `range.end` | `{integer, integer}\|nil` | No | `nil` | Optional end position `{line, col}`. |

## Module

### `require("cosmic-ui").codeactions.open(opts?)`

Requests and opens code actions at the current cursor context.

Behavior:
- warns and no-ops if `setup()` has not run
- warns and no-ops if `codeactions` is disabled
- forwards `opts` to `require("cosmic-ui.code-action").code_actions(opts)`
- menu groups are ordered deterministically by client name (tie-break: client id)
- actions within each client group keep server response order

```lua
require("cosmic-ui").codeactions.open()
```

```lua
require("cosmic-ui").codeactions.open({
  params = { context = { only = { "quickfix" } } },
})
```

### `require("cosmic-ui").codeactions.range(opts?)`

Requests code actions for the active visual selection.

Behavior:
- uses `opts.range` when provided
- else uses `opts.params` when provided
- else builds range from visual marks `'<` and `'>`
- warns and no-ops if `setup()` has not run or module is disabled

```lua
vim.keymap.set("v", "<leader>ga", function()
  require("cosmic-ui").codeactions.range()
end)
```

```lua
require("cosmic-ui").codeactions.range({
  range = { start = { 10, 0 }, ["end"] = { 12, 0 } },
})
```
