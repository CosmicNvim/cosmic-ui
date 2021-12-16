<h1 align="center">💫 Cosmic-UI</h1>

<p align="center">
  <img alt="Neovim Minimum Version" src="https://img.shields.io/badge/Neovim-0.6.0+-blueviolet.svg?style=flat-square&logo=Neovim&logoColor=white)](https://github.com/neovim/neovim">
  <img alt="GitHub last commit" src="https://img.shields.io/github/last-commit/CosmicNvim/cosmic-ui?style=flat-square&logo=Github">
  <a href="https://discord.gg/EwdrKzVbvJ">
    <img alt="Discord" src="https://img.shields.io/discord/901609359291854899?style=flat-square&logo=Discord">
  </a>
</p>

## 🚀 Stellar Features

Cosmic-UI is a simple wrapper around specific vim functionality. Built in order to provide a quick and easy way to create a Cosmic UI experience with Neovim!

- Diagnostics UI
  - Sane `vim.diagnostic` default settings
  - Pretty sign icons
- LSP UI
  - Signature help
  - Hover
  - Rename floating popup & file change notification
  - Code Actions
- Exports values such as the border value set in `.setup` to use elsewhere in your configuration

_Coming soon..._

- Highlighting documentation

## 📷 Screenshots

### Code Actions

<img width="613" alt="Screen Shot 2021-12-10 at 3 37 38 PM" src="https://user-images.githubusercontent.com/3721204/145654798-84c88a69-414e-457b-b595-e76b767ea5d3.png">

### Rename Floating Popup

<img width="498" alt="Screen Shot 2021-12-10 at 4 22 28 PM" src="https://user-images.githubusercontent.com/3721204/145656501-e1aec4be-c8bc-4e59-8c2f-2d99d50bbea2.png">

## 🛠 Installation

```lua
  use({
    'CosmicNvim/cosmic-ui',
    requires = { 'MunifTanjim/nui.nvim', 'nvim-lua/plenary.nvim' },
    config = function()
      require('cosmic-ui').setup()
    end,
  })
```

To enable `lsp_signature` integration, ensure that `cosmic-ui` initializes _after_ your LSP servers. This is a requirement of `lsp_signature` itself.

```lua
  use({
    'CosmicNvim/cosmic-ui',
    requires = { 'MunifTanjim/nui.nvim', 'nvim-lua/plenary.nvim', 'ray-x/lsp_signature.nvim' },
    config = function()
      require('cosmic-ui').setup()
    end,
    after = 'nvim-lspconfig',
  })
```

<!-- This is because `Cosmic-UI` will initialize `lsp_signature.nvim`, which must be set up after LSP server in order to properly hook into the correct LSP handler. -->

## ⚙️ Configuration

You may override any of the settings below by passing a config object to `.setup`

```lua
{
  -- default border to use
  -- 'single', 'double', 'rounded', 'solid', 'shadow'
  border = 'rounded'

  -- icons used for lsp diagnostic signs
  icons = {
    warn = '',
    info = '',
    error = '',
    hint = '',
  },

  -- see h: vim.diagnostic.config
  -- `false` to disable
  diagnostic = {
    underline = true,
    signs = true,
    update_in_insert = false,
    severity_sort = true,
    float = {
      header = false,
      source = 'always',
      -- override border if desired
      border = 'rounded',
    },
    virtual_text = {
      spacing = 4,
      source = 'always',
      severity = {
        min = vim.diagnostic.severity.HINT,
      },
    },
  },

  -- settings for vim.lsp.handlers['textDocument/hover']
  -- `false` to disable
  hover = {

    -- override default handler
    handler = vim.lsp.handlers.hover,

    -- see :h lsp-handlers
    float = {
      -- override border if desired
      border = 'rounded',
    },

  },

  -- settings for vim.lsp.handlers['textDocument/signatureHelp']
  -- `false` to disable
  signature_help = {

    -- override default handler
    handler = vim.lsp.handlers.signature_help,

    -- see :h lsp-handlers
    float = {
      -- override border if desired
      border = 'rounded',
    },

  },

  -- lsp_signature settings
  -- `false` to disable
  lsp_signature = {
    handler_opts = {
      -- override border if desired
      border = 'rounded',
    },
  },

  -- rename popup settings
  rename = {
    prompt = '> '
  }

  code_actions = {
    popup_opts = {
      position = {
        row = 1,
        col = 0,
      },
      relative = 'cursor',
      border = {
        highlight = 'FloatBorder',
        text = {
          top = 'Code Actions',
          top_align = 'center',
        },
        padding = { 0, 1 },
      },
    },
    min_width = {}
  }
}
```

## ✨ Usage

#### Rename

```lua
function map(mode, lhs, rhs, opts)
  local options = { noremap = true, silent = true }
  if opts then
    options = vim.tbl_extend('force', options, opts)
  end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

map('n', 'gn', '<cmd>lua require("cosmic-ui").rename()<cr>')
```

#### Code Actions

```lua
map('n', '<leader>ga', '<cmd>lua require("cosmic-ui").code_actions()<cr>')
map('v', '<leader>ga', '<cmd>lua require("cosmic-ui").range_code_actions()<cr>')
```

#### Get border

```lua
local cosmic_ui = require('cosmic-ui')
local border = cosmic_ui.get_border()
```

_More coming soon..._
