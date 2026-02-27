# `lua/cosmic-ui/config.lua`

## Intent

Holds plugin configuration defaults, merged setup options, module enable/disable state, and warnings for invalid usage.
This module is the gatekeeper used by feature entry modules before any feature runs.

## Exposed API

- `setup(user_opts)`: Validates and merges user config into module defaults, then marks config as initialized.
- `is_setup() -> boolean`: Returns whether setup has been called.
- `get() -> table`: Returns merged runtime config currently in use.
- `module_enabled(module_name) -> boolean`: Returns whether a module is enabled by setup input.
- `module_opts(module_name) -> table|nil`: Returns merged options for one module.
- `warn_not_setup(method_name)`: Emits a one-time warning for APIs called before setup.
- `warn_module_disabled(module_name)`: Emits a one-time warning when a disabled module is used.

## Usage

```lua
local config = require("cosmic-ui.config")

config.setup({
  notify_title = "CosmicUI",
  rename = { enabled = true },
  codeactions = { enabled = true },
  formatters = { enabled = true },
})
```

```lua
local config = require("cosmic-ui.config")

if not config.is_setup() then
  config.warn_not_setup("formatters.open(...)")
  return
end

if not config.module_enabled("formatters") then
  config.warn_module_disabled("formatters")
  return
end
```
