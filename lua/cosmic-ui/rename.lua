local lsp = vim.lsp
local utils = require('cosmic-ui.utils')

local function rename_handler(...)
  local result
  local method
  local err = select(1, ...)
  local is_new = not select(4, ...) or type(select(4, ...)) ~= 'number'
  if is_new then
    method = select(3, ...).method
    result = select(2, ...)
  else
    method = select(2, ...)
    result = select(3, ...)
  end

  if err then
    vim.notify(("Error running LSP query '%s': %s"):format(method, err), vim.log.levels.ERROR, {
      title = 'Cosmic-UI',
    })
    return
  end

  local new_word = ''
  if result and result.changes then
    local msg = {}
    for f, c in pairs(result.changes) do
      new_word = c[1].newText
      table.insert(msg, ('%d changes -> %s'):format(#c, utils.get_relative_path(f)))
    end
    local currName = vim.fn.expand('<cword>')
    vim.notify(msg, vim.log.levels.INFO, { title = ('Rename: %s -> %s'):format(currName, new_word) })
  end

  vim.lsp.handlers[method](...)
end

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
