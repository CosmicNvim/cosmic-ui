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

It provides customizable UI defaults as well as utility methods.

- Sane `vim.diagnostic` defaults
- Sets borders around common UI elements
  - Signature help
  - Hover
  - Diagnostics UI
- Pretty diagnostic sign icons
- LSP rename floating window

_Coming soon..._

- Code Actions
- ???

_Why not autocomplete?_

Well.. Not everyone uses autocomplete and on top of that,
there are quite a few common autocompletion plugins that being able to
provide integrations for all of them is unmanagable.

## 🛠 Installation

Without `lsp_signature.nvim`

```lua
  use({
    '~/dev/cosmic/cosmic-ui',
    requires = { 'MunifTanjim/nui.nvim', 'nvim-lua/plenary.nvim' },
    config = function()
      require('cosmic-ui').setup({})
    end,
  })
```

With `lsp_signature.nvim`

```lua
  use({
    '~/dev/cosmic/cosmic-ui',
    requires = { 'MunifTanjim/nui.nvim', 'nvim-lua/plenary.nvim', 'ray-x/lsp_signature.nvim' },
    config = function()
      require('cosmic-ui').setup({})
    end,
    after = 'nvim-lspconfig',
  })
```

If using `lsp_signature.nvim`, you must ensure that `Cosmic-UI` loads _after_ `nvim-lspconfig` (or after LSP servers setup).

<!-- This is because `Cosmic-UI` will initialize `lsp_signature.nvim`, which must be set up after LSP server in order to properly hook into the correct LSP handler. -->

## ⚙️ Configuration

You may override any of the settings below by passing a config object to `.setup`

```lua
{
  -- icons used for lsp diagnostic signs
  icons = {
    warn = '',
    info = '',
    error = '',
    hint = '',
  },

  -- lsp_signature settings
  -- `false` to disable
  lsp_signature = {
    bind = true,
    handler_opts = {
      border = 'rounded',
    },
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

<img width="341" alt="Screen Shot 2021-12-04 at 5 21 50 PM" src="https://user-images.githubusercontent.com/3721204/144729678-ab054d0b-98bb-45c7-9d2a-e380cc5cc1bd.png">

