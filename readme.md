<h1 align="center">💫 Cosmic-UI</h1>

<p align="center">
  <img alt="Neovim Minimum Version" src="https://img.shields.io/badge/Neovim-0.11.0+-blueviolet.svg?style=flat-square&logo=Neovim&logoColor=white)](https://github.com/neovim/neovim">
  <img alt="GitHub last commit" src="https://img.shields.io/github/last-commit/CosmicNvim/cosmic-ui?style=flat-square&logo=Github">
  <a href="https://discord.gg/EwdrKzVbvJ">
    <img alt="Discord" src="https://img.shields.io/discord/901609359291854899?style=flat-square&logo=Discord">
  </a>
</p>

## 🚀 Stellar Features

_Warning: Under heavy development_

Cosmic-UI is a simple wrapper around specific vim functionality. Built in order to provide a quick and easy way to create a Cosmic UI experience with Neovim!

- Rename floating popup & file change notification
- Code Actions
- Formatter toggles (LSP + Conform.nvim)

## 📷 Screenshots

### Code Actions

<img width="613" alt="Screen Shot 2021-12-10 at 3 37 38 PM" src="https://user-images.githubusercontent.com/3721204/145654798-84c88a69-414e-457b-b595-e76b767ea5d3.png">

### Rename Floating Popup

<img width="498" alt="Screen Shot 2021-12-10 at 4 22 28 PM" src="https://user-images.githubusercontent.com/3721204/145656501-e1aec4be-c8bc-4e59-8c2f-2d99d50bbea2.png">

## 🛠 Installation

```lua
  use({
    'CosmicNvim/cosmic-ui',
    requires = {
      'MunifTanjim/nui.nvim',
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    config = function()
      require('cosmic-ui').setup()
    end,
  })
```

## ⚙️ Configuration

Call `setup()` before using any module. Calling module APIs before setup will warn and no-op.

Modules are enabled only when their key is present as a table in setup.

You may override any of the settings below by passing a config object to `.setup`:

```lua
{
  notify_title = "CosmicUI",

  rename = {
    enabled = true, -- optional (defaults to true when table exists)
    border = {
      highlight = 'FloatBorder',
      style = nil, -- falls back to vim.o.winborder
      title = 'Rename',
      title_align = 'left',
      title_hl = 'FloatBorder',
    },
    prompt = '> ',
    prompt_hl = 'Comment',
  },

  codeactions = {
    enabled = true, -- optional (defaults to true when table exists)
    min_width = nil,
    border = {
      bottom_hl = 'FloatBorder',
      highlight = 'FloatBorder',
      style = nil, -- falls back to vim.o.winborder
      title = 'Code Actions',
      title_align = 'center',
      title_hl = 'FloatBorder',
    },
  },

  formatters = {
    enabled = true, -- optional (defaults to true when table exists)
  },
}
```

Notes:
- Missing module key means disabled.
- `enabled = false` disables a module.
- Unknown setup keys are ignored with a warning.
- `code_actions` is not a supported key; use `codeactions`.

## ✨ Usage

```lua
local CosmicUI = require("cosmic-ui")

CosmicUI.setup({
  rename = {},
  codeactions = {},
  formatters = {},
})
```

#### Rename

```lua
vim.keymap.set("n", "gn", function()
  require("cosmic-ui").rename.open()
end, { silent = true })
```

#### Code Actions

```lua
vim.keymap.set("n", "<leader>ga", function()
  require("cosmic-ui").codeactions.open()
end, { silent = true })

vim.keymap.set("v", "<leader>ga", function()
  require("cosmic-ui").codeactions.range()
end, { silent = true })
```

#### Formatters

```lua
vim.keymap.set("n", "<leader>gf", function()
  require("cosmic-ui").formatters.open()
end, { silent = true })

vim.keymap.set("n", "<leader>gF", function()
  require("cosmic-ui").formatters.open({ scope = "global" })
end, { silent = true })

vim.keymap.set("n", "<leader>fm", function()
  require("cosmic-ui").formatters.format()
end, { silent = true })

vim.keymap.set("n", "<leader>fM", function()
  require("cosmic-ui").formatters.format_async()
end, { silent = true })
```

`formatters.open()` uses a native Neovim floating window and requires `nvim-web-devicons`.

- Default scope is `buffer` unless you pass `{ scope = "global" }`.
- `<Tab>` toggles the selected formatter row.
- `s` switches scope on the fly.
- `a` toggles all visible formatter rows in the active scope.
- `r` resets the active scope.
- `f` formats then closes the window.
- `<CR>`, `<Esc>`, and `q` close the window.
- Conform formatter rows come from `conform.list_formatters_to_run()`.
- Conform is optional; if not installed, the Conform section shows as unavailable.
- Row states use icons: `` enabled, `󰄱` disabled, `` unavailable.
- UI colors are semantic and theme-linked (header, sections, key hints, and row states).

Per-item APIs:

```lua
require("cosmic-ui").formatters.toggle_item({
  source = "lsp", -- "lsp" or "conform"
  name = "lua_ls",
  scope = "buffer", -- default
})

require("cosmic-ui").formatters.disable_item({
  source = "conform",
  name = "stylua",
  scope = "global",
})
```

LSP row states:
- `ON`: formatter gate is enabled and at least one LSP client can format.
- `OFF`: formatter gate is disabled.
- `UNAVAILABLE`: gate is enabled, but attached clients are disabled for formatting or do not support formatting.

_More coming soon..._
