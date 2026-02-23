local Menu = require('nui.menu')
local Text = require('nui.text')
local event = require('nui.utils.autocmd').event
local utils = require('cosmic-ui.utils')
local transform = require('cosmic-ui.code-action.transform')
local logger = utils.Logger

local M = {}

M.open = function(results_lsp, user_opts)
  if not results_lsp or next(results_lsp) == nil then
    logger:warn('No results from textDocument/codeAction')
    return
  end

  local menu_items = {}
  local result_items = {}
  local min_width = 0

  for _, response in pairs(results_lsp) do
    if response.result and next(response.result) ~= nil then
      local client = response.client

      if client and client.name then
        table.insert(menu_items, Menu.separator(Text('(' .. client.name .. ')', 'Comment')))

        for _, result in pairs(response.result) do
          local command_title = result.title:gsub('\r\n', '\\r\\n'):gsub('\n', '\\n')

          local item = Menu.item(command_title)
          item.ctx = {
            command_title = command_title,
            client = client,
            client_name = client and client.name or '',
            command = result,
          }

          min_width = math.max(min_width, #command_title, 30)
          table.insert(menu_items, item)
          table.insert(result_items, item)
        end
      end
    end
  end

  if #menu_items == 0 then
    logger:log('No code actions available')
    return
  end

  local user_border = user_opts.border or {}
  local popup_opts = {
    position = {
      row = 1,
      col = 0,
    },
    relative = 'cursor',
    border = {
      highlight = user_border.highlight,
      style = user_border.style or vim.o.winborder,
      text = {
        top = Text(user_border.title, user_border.title_hl),
        top_align = user_border.title_align,
      },
      padding = { 0, 1 },
    },
  }

  local menu = Menu(popup_opts, {
    lines = menu_items,
    min_width = user_opts.min_width or min_width,
    separator = {
      char = ' ',
      text_align = 'center',
    },
    keymap = {
      focus_next = { 'j', '<Down>', '<Tab>' },
      focus_prev = { 'k', '<Up>', '<S-Tab>' },
      close = { '<Esc>', '<C-c>' },
      submit = { '<CR>', '<Space>' },
    },
    on_change = function(item, menu_obj)
      local pos = utils.index_of(result_items, item)
      local text = '(' .. tostring(pos) .. '/' .. #result_items .. ')'
      menu_obj.border:set_text('bottom', Text(text, user_border.bottom_hl), 'right')
    end,
    on_submit = function(item)
      local action = item.ctx.command
      local client = item.ctx.client

      if not client then
        logger:warn('Code action client is no longer available')
        return
      end

      if not action.edit and transform.supports_code_action_resolve(client) then
        client:request('codeAction/resolve', action, function(resolved_err, resolved_action)
          if resolved_err then
            logger:error(resolved_err.code .. ': ' .. resolved_err.message)
            return
          end
          if resolved_action then
            transform.execute_action(transform.transform_action(resolved_action), client)
          else
            transform.execute_action(transform.transform_action(action), client)
          end
        end)
      else
        transform.execute_action(transform.transform_action(action), client)
      end
    end,
  })

  menu:mount()

  vim.api.nvim_buf_call(menu.bufnr, function()
    if vim.fn.mode() ~= 'n' then
      vim.api.nvim_input('<Esc>')
    end
  end)

  menu:on(event.BufLeave, menu.menu_props.on_close, { once = true })
end

return M
