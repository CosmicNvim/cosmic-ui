local lsp = vim.lsp
local utils = require('cosmic-ui.utils')
local rename_handler = require('cosmic-ui.rename.handler')

local function rename(popup_opts, opts)
  opts = opts or {}
  local Input = require('nui.input')
  local event = require('nui.utils.autocmd').event
  local curr_name = vim.fn.expand('<cword>')
  local default_popup_opts = {
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
  }

  local default_opts = {
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
  }

  local input = Input(utils.merge(default_popup_opts, popup_opts), utils.merge(default_opts, opts))

  -- mount/open the component
  input:mount()

  utils.default_mappings(input)

  -- unmount component when cursor leaves buffer
  input:on(event.BufLeave, function()
    input:unmount()
  end)
end

return rename
