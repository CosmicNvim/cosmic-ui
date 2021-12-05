<h1 align="center">💫 Cosmic-UI</h1>

## 🚀 Stellar Features

Cosmic-UI is a simple wrapper around specific vim (and common plugin) functionality in order to provide a quick and easy way to create a Cosmic Neovim experience!

It provides customizable UI defaults as well as utility methods.

- Sane `vim.diagnostics` defaults
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
      -- set up diagnostics
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
      -- set up diagnostics
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
  -- lsp_signature settings
  lsp_signature = {
    bind = true, -- This is mandatory, otherwise border config won't get registered.
    handler_opts = {
      border = 'rounded',
    },
  },
  -- icons used for lsp diagnostic signs
  icons = {
    warn = '',
    info = '',
    error = '',
    hint = '',
  },
  -- see h: vim.diagnostic.config
  diagnostics = {
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
  hover = {
    -- override default handler
    handler = vim.lsp.handlers.hover,
    -- see h: lsp-handler-configuration
    float = {
      border = 'rounded',
    },
  },
  -- settings for vim.lsp.handlers['textDocument/signatureHelp']
  signature_help = {
    -- override default handler
    handler = vim.lsp.handlers.signature_help,
    -- see h: lsp-handler-configuration
    float = {
      border = 'rounded',
    },
  },
}
```
