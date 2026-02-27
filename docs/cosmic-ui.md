# `lua/cosmic-ui/init.lua`

## Intent

Root plugin module that users require (`require("cosmic-ui")`).
It stores setup state indirectly via `cosmic-ui.config` and lazily loads feature modules (`rename`, `codeactions`, `formatters`) on first access.

## Exposed API

### `setup(user_opts)`

Initializes cosmic-ui config state and stores merged module options.

`user_opts` definition:

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `notify_title` | `string\|nil` | No | `"CosmicUI"` | Notification title used by module logging/warnings. |
| `rename` | `table\|nil` | No | disabled if omitted | Rename module config; set table to enable module. |
| `rename.enabled` | `boolean\|nil` | No | `true` when table exists | Explicit enable/disable switch for rename module. |
| `codeactions` | `table\|nil` | No | disabled if omitted | Codeactions module config; set table to enable module. |
| `codeactions.enabled` | `boolean\|nil` | No | `true` when table exists | Explicit enable/disable switch for codeactions module. |
| `formatters` | `table\|nil` | No | disabled if omitted | Formatters module config; set table to enable module. |
| `formatters.enabled` | `boolean\|nil` | No | `true` when table exists | Explicit enable/disable switch for formatters module. |

Module enable semantics:
- Missing module key (`rename`, `codeactions`, `formatters`) means disabled.
- `enabled = false` inside a module table disables that module.

### `is_setup() -> boolean`

Returns whether `setup()` has already been called.

### `rename`

Lazy-loaded proxy to `require("cosmic-ui").rename` module methods.

### `codeactions`

Lazy-loaded proxy to `require("cosmic-ui").codeactions` module methods.

### `formatters`

Lazy-loaded proxy to `require("cosmic-ui").formatters` module methods.

## Usage

```lua
local CosmicUI = require("cosmic-ui")

CosmicUI.setup({
  rename = {},
  codeactions = {},
  formatters = {},
})
```

```lua
if require("cosmic-ui").is_setup() then
  require("cosmic-ui").codeactions.open()
end
```
