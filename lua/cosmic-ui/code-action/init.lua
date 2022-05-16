-- big shout out to telescope
-- https://github.com/nvim-telescope/telescope.nvim/blob/master/lua/telescope/builtin/lsp.lua#L144
local Menu = require('nui.menu')
local Text = require('nui.text')
local event = require('nui.utils.autocmd').event
local utils = require('cosmic-ui.utils')
local logger = utils.Logger
local M = {}

local function fix_zero_version(workspace_edit)
  if workspace_edit and workspace_edit.documentChanges then
    for _, change in pairs(workspace_edit.documentChanges) do
      local text_document = change.textDocument
      if text_document and text_document.version and text_document.version == 0 then
        text_document.version = nil
      end
    end
  end
  return workspace_edit
end

local function transform_action(action)
  -- Remove 0 -version from LSP codeaction request payload.
  -- Is only run on the "java.apply.workspaceEdit" codeaction.
  -- Fixed Java/jdtls compatibility with Telescope
  -- See fix_zero_version commentary for more information
  local command = (action.command and action.command.command) or action.command
  if not (command == 'java.apply.workspaceEdit') then
    return action
  end
  local arguments = (action.command and action.command.arguments) or action.arguments
  action.edit = fix_zero_version(arguments[1])
  return action
end

local function execute_action(action)
  if action.edit or type(action.command) == 'table' then
    if action.edit then
      vim.lsp.util.apply_workspace_edit(action.edit, 'utf-8')
    end
    if type(action.command) == 'table' then
      vim.lsp.buf.execute_command(action.command)
    end
  else
    vim.lsp.buf.execute_command(action)
  end
end

M.code_actions = function(opts)
  opts = utils.merge({
    timeout = 2000,
    params = vim.lsp.util.make_range_params(),
  }, opts or {})

  opts.params.context = {
    diagnostics = vim.lsp.diagnostic.get_line_diagnostics(),
  }

  local results_lsp, _ = vim.lsp.buf_request_sync(0, 'textDocument/codeAction', opts.params, opts.timeout)

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    logger:warn('No results from textDocument/codeAction')
    return
  end

  -- items for menu
  local menu_items = {}
  -- result items to filter through
  local result_items = {}
  local min_width = 0

  for client_id, response in pairs(results_lsp) do
    if response.result and not vim.tbl_isempty(response.result) then
      local client = vim.lsp.get_client_by_id(client_id)

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

  if #menu_items == 0 then
    logger:log('No code actions available')
    return
  end

  local user_border = _G.CosmicUI_user_opts.code_actions.border
  local popup_opts = {
    position = {
      row = 1,
      col = 0,
    },
    relative = 'cursor',
    border = {
      highlight = user_border.highlight,
      style = user_border.style or _G.CosmicUI_user_opts.border_style,
      text = {
        top = Text(user_border.title, user_border.title_hl),
        top_align = user_border.title_align,
      },
      padding = { 0, 1 },
    },
  }

  local menu = Menu(popup_opts, {
    lines = menu_items,
    min_width = _G.CosmicUI_user_opts.code_actions.min_width or min_width,
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
    on_change = function(item, menu)
      local pos = utils.index_of(result_items, item)
      local text = '(' .. tostring(pos) .. '/' .. #result_items .. ')'
      menu.border:set_text('bottom', Text(text, user_border.bottom_hl), 'right')
    end,
    on_submit = function(item)
      local action = item.ctx.command
      local client = item.ctx.client

      if
        not action.edit
        and client
        and type(client.server_capabilities.codeAction) == 'table'
        and client.server_capabilities.codeAction.resolveProvider
      then
        client.request('codeAction/resolve', action, function(resolved_err, resolved_action)
          if resolved_err then
            logger:error(resolved_err.code .. ': ' .. resolved_err.message)
            return
          end
          if resolved_action then
            execute_action(transform_action(resolved_action))
          else
            execute_action(transform_action(action))
          end
        end)
      else
        execute_action(transform_action(action))
      end
    end,
  })

  -- mount the component
  menu:mount()

  vim.api.nvim_buf_call(menu.bufnr, function()
    if vim.fn.mode() ~= 'n' then
      vim.api.nvim_input('<Esc>')
    end
  end)

  -- close menu when cursor leaves buffer
  menu:on(event.BufLeave, menu.menu_props.on_close, { once = true })
end

return M
