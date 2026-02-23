# `lua/cosmic-ui/rename/handler.lua`

## Intent

Handles LSP rename responses:
- logs rename errors with method context
- logs file-level change summaries
- applies workspace edits with the active client's offset encoding

This is an internal helper used by `lua/cosmic-ui/rename/init.lua`.

## Exposed API

This module returns a callback function:

- `handler(err, result, ctx)`: Handles LSP rename responses by logging errors, summarizing file changes, and applying workspace edits.

Parameters match standard LSP handler signatures.

## Usage

```lua
local handler = require("cosmic-ui.rename.handler")

client:request("textDocument/rename", params, handler, 0)
```
