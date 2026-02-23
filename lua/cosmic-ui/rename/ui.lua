local lsp = vim.lsp
local utils = require('cosmic-ui.utils')
local config = require('cosmic-ui.config')
local rename_handler = require('cosmic-ui.rename.handler')
local Text = require('nui.text')

local M = {}

M.open = function(popup_opts, opts)
  local Input = require('nui.input')
  local event = require('nui.utils.autocmd').event
  local curr_name = vim.fn.expand('<cword>')

  local clients = vim.lsp.get_clients({ bufnr = 0, method = 'textDocument/rename' })
  if #clients == 0 then
    utils.Logger:warn('No LSP clients with rename attached')
    return
  end

  local user_opts = config.module_opts('rename') or {}
  local user_border = user_opts.border or {}
  local width = 25
  if #curr_name + #(user_opts.prompt or '> ') >= width then
    width = #curr_name + #(user_opts.prompt or '> ') + 1
  end

  popup_opts = utils.merge({
    position = {
      row = 1,
      col = 0,
    },
    size = {
      width = width,
      height = 2,
    },
    relative = 'cursor',
    border = {
      highlight = user_border.highlight,
      style = user_border.style or vim.o.winborder,
      text = {
        top = Text(user_border.title, user_border.title_hl),
        top_align = user_border.title_align,
      },
    },
  }, popup_opts or {})

  opts = utils.merge({
    prompt = Text(user_opts.prompt or '> ', user_opts.prompt_hl or 'Comment'),
    default_value = curr_name,
    on_submit = function(new_name)
      if not (new_name and #new_name > 0) or new_name == curr_name then
        return
      end
      for _, client in ipairs(clients) do
        local params = lsp.util.make_position_params(0, client.offset_encoding)
        params.newName = new_name
        client:request('textDocument/rename', params, rename_handler, 0)
      end
    end,
  }, opts or {})

  local input = Input(popup_opts, opts)
  input:mount()

  utils.default_mappings(input)

  input:on(event.BufLeave, function()
    input:unmount()
  end)
end

return M
