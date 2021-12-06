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
  - Autocompletion documentation
  - Rename floating popup
  - Rename file change notification

_Coming soon..._

- Code Actions
- Highlights?

## 🛠 Installation

```lua
  use({
    'CosmicNvim/cosmic-ui',
    config = function()
      require('cosmic-ui').setup()
    end,
    requires = { 'MunifTanjim/nui.nvim', 'nvim-lua/plenary.nvim' },
  })
```

To enable `lsp_signature` integration, ensure that `cosmic-ui` initializes _after_ your LSP servers

```lua
  use({
    'CosmicNvim/cosmic-ui',
    config = function()
      require('cosmic-ui').setup()
    end,
    requires = { 'MunifTanjim/nui.nvim', 'nvim-lua/plenary.nvim', 'ray-x/lsp_signature.nvim' },
    after = 'nvim-lspconfig',
  })
```

Autocomplete functionality is disabled by default, if you would like to set it up. Ensure that Cosmic-UI is also initialized after nvim-cmp.

```lua
  use({
    'CosmicNvim/cosmic-ui',
    requires = { 'MunifTanjim/nui.nvim', 'nvim-lua/plenary.nvim', 'ray-x/lsp_signature.nvim' },
    config = function()
      require('cosmic-ui').setup({
          autocomplete = {
            -- add any nvim-cmp settings you would like to override
          }
      })
    end,
  })
```

If you would like to continue to lazy load nvim-cmp, you may alter your setup to the below.

```lua
  use({
    'hrsh7th/nvim-cmp',
    config = function()
      require('cosmic-ui').setup_autocomplete({
          -- add any nvim-cmp settings you would like to override
      })
    end,
    requires = {...},
    event = 'InsertEnter',
    disable = vim.tbl_contains(user_plugins.disable, 'autocomplete'),
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

  -- autocomplete settings, see `:h cmp-config`
  autocomplete = false,

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
    bind = true,
    handler_opts = {
      -- override border if desired
      border = 'rounded',
    },
  },

}
```

## ✨ Utilities

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

## 📷 Screenshots

### Rename Floating Popup

<img width="341" alt="Screen Shot 2021-12-04 at 5 21 50 PM" src="https://user-images.githubusercontent.com/3721204/144729678-ab054d0b-98bb-45c7-9d2a-e380cc5cc1bd.png">

_More coming soon..._
