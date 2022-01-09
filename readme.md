<h1 align="center">💫 Cosmic-UI</h1>

<p align="center">
  <img alt="Neovim Minimum Version" src="https://img.shields.io/badge/Neovim-0.6.0+-blueviolet.svg?style=flat-square&logo=Neovim&logoColor=white)](https://github.com/neovim/neovim">
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

## ⚙️ Configuration

You may override any of the settings below by passing a config object to `.setup`

```lua
{
  -- default border to use
  -- 'single', 'double', 'rounded', 'solid', 'shadow'
  border_style = 'single',

  -- rename popup settings
  rename = {
    border = {
      highlight = 'FloatBorder',
      style = 'single',
      title = ' Rename ',
      title_align = 'left',
      title_hl = 'FloatBorder',
    },
    prompt = '> ',
    prompt_hl = 'Comment',
  },

  code_actions = {
    min_width = nil,
    border = {
      bottom_hl = 'FloatBorder',
      highlight = 'FloatBorder',
      style = 'single',
      title = 'Code Actions',
      title_align = 'center',
      title_hl = 'FloatBorder',
    },
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

_More coming soon..._
