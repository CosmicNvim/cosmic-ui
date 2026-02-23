# `lua/cosmic-ui/utils.lua`

## Intent

Provides shared helper functions used across rename/code actions/formatters, plus a logger wrapper that standardizes `vim.notify` calls with the configured title.

## Exposed API

- `merge(...) -> table`: Deep-merges tables using `vim.tbl_deep_extend("force", ...)`.
- `get_relative_path(file_path) -> string`: Converts an absolute URI/path into a path relative to current working directory.
- `index_of(tbl, item) -> integer|nil`: Returns the first list index matching `item`, or `nil` if not found.
- `default_mappings(input)`: Applies default NUI input mappings for close and prompt-safe backspace behavior.
- `Logger:log(msg, opts?)`: Emits an info notification using the configured notify title.
- `Logger:warn(msg, opts?)`: Emits a warning notification using the configured notify title.
- `Logger:error(msg, opts?)`: Emits an error notification using the configured notify title.

## Usage

```lua
local utils = require("cosmic-ui.utils")

local merged = utils.merge(
  { a = 1, nested = { x = true } },
  { nested = { y = true } }
)
```

```lua
local logger = require("cosmic-ui.utils").Logger
logger:warn("No LSP clients with code actions attached")
```
