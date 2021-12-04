local utils = require('cosmic-ui.utils')

local function rename(popup_opts, opts)
  opts = opts or {}
  local Input = require('nui.input')
  local event = require('nui.utils.autocmd').event
  local default_popup_opts = {
    position = {
      row = 1,
      col = 0,
    },
    size = {
      width = 20,
      height = 2,
    },
    relative = 'cursor',
    border = {
      highlight = 'FloatBorder',
      style = 'rounded',
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
    prompt = '> ',
    default_value = vim.fn.expand('<cword>'),
    on_close = function()
      print('Input closed!')
    end,
    on_submit = function(value)
      print('You are ' .. value .. ' years old')
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
