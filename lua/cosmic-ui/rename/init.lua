local lsp = vim.lsp
local utils = require('cosmic-ui.utils')
local rename_handler = require('cosmic-ui.rename.handler')
local Text = require('nui.text')

local function rename(popup_opts, opts)
  local Input = require('nui.input')
  local event = require('nui.utils.autocmd').event
  local curr_name = vim.fn.expand('<cword>')

  local clients = vim.lsp.get_clients({ bufnr = 0, method = 'textDocument/rename' })
  if #clients == 0 then
    utils.Logger:warn('No LSP clients with rename attached')
    return
  end

  local user_border = _G.CosmicUI_user_opts.rename.border
  local width = 25
  if #curr_name + #_G.CosmicUI_user_opts.rename.prompt >= width then
    -- consider prompt and one free space, otherwise the textbox scrolls
    -- and shows an -- seemingly -- empty textbox
    width = #curr_name + #_G.CosmicUI_user_opts.rename.prompt + 1
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
    prompt = Text(_G.CosmicUI_user_opts.rename.prompt, _G.CosmicUI_user_opts.rename.prompt_hl),
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

  -- mount/open the component
  input:mount()

  utils.default_mappings(input)

  -- unmount component when cursor leaves buffer
  input:on(event.BufLeave, function()
    input:unmount()
  end)
end

return rename
