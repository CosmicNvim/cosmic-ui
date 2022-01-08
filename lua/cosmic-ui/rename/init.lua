local lsp = vim.lsp
local utils = require('cosmic-ui.utils')
local rename_handler = require('cosmic-ui.rename.handler')

local function rename(popup_opts, opts)
  local Input = require('nui.input')
  local event = require('nui.utils.autocmd').event
  local curr_name = vim.fn.expand('<cword>')

  popup_opts = utils.merge({
    position = {
      row = 1,
      col = 0,
    },
    size = {
      width = 25,
      height = 2,
    },
    relative = 'cursor',
    border = {
      highlight = 'FloatBorder',
      style = _G.CosmicUI_user_opts.border,
      text = {
        top = ' Rename ',
        top_align = 'left',
      },
    },
    win_options = {
      winhighlight = 'Normal:Normal',
    },
  }, _G.CosmicUI_user_opts.rename.popup_opts or {}, popup_opts or {})

  opts = utils.merge({
    prompt = _G.CosmicUI_user_opts.rename.prompt,
    default_value = curr_name,
    on_submit = function(new_name)
      if not (new_name and #new_name > 0) or new_name == curr_name then
        return
      end
      local params = lsp.util.make_position_params()
      params.newName = new_name
      lsp.buf_request(0, 'textDocument/rename', params, rename_handler)
    end,
  }, opts or {})

  local input = Input(popup_opts, opts)

  -- mount/open the component
  input:mount()

  -- las value is length of highlight
  -- vim.api.nvim_buf_add_highlight(input.bufnr, -1, 'LspRenamePrompt', 0, 0, #opts.prompt)
  -- vim.cmd('hi link LspRenamePrompt Comment')

  utils.default_mappings(input)

  -- unmount component when cursor leaves buffer
  input:on(event.BufLeave, function()
    input:unmount()
  end)
end

return rename
