-- big shout out to telescope
-- https://github.com/nvim-telescope/telescope.nvim/blob/master/lua/telescope/builtin/lsp.lua#L144
local Menu = require('nui.menu')
local event = require('nui.utils.autocmd').event
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
      vim.lsp.util.apply_workspace_edit(action.edit)
    end
    if type(action.command) == 'table' then
      vim.lsp.buf.execute_command(action.command)
    end
  else
    vim.lsp.buf.execute_command(action)
  end
end

M.code_actions = function(opts)
  local strings = require('plenary.strings')
  local params = vim.lsp.util.make_range_params()
  local timeout = 10000

  params.context = {
    diagnostics = vim.lsp.diagnostic.get_line_diagnostics(),
  }

  local results_lsp, _ = vim.lsp.buf_request_sync(0, 'textDocument/codeAction', params, timeout)

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    vim.notify('No results from textDocument/codeAction', vim.log.levels.WARN, {
      title = 'CosmicUI',
    })
    return
  end

  local idx = 1
  local results = {}
  local widths = {
    idx = 0,
    command_title = 0,
    client_name = 0,
  }

  local menu_items = {}

  for client_id, response in pairs(results_lsp) do
    if response.result then
      local client = vim.lsp.get_client_by_id(client_id)
      table.insert(menu_items, Menu.separator(client.name))

      for _, result in pairs(response.result) do
        local entry = {
          idx = idx,
          command_title = result.title:gsub('\r\n', '\\r\\n'):gsub('\n', '\\n'),
          client = client,
          client_name = client and client.name or '',
          command = result,
        }

        table.insert(menu_items, Menu.item(entry.command_title))

        for key, value in pairs(widths) do
          widths[key] = math.max(value, strings.strdisplaywidth(entry[key]))
        end

        table.insert(results, entry)
        idx = idx + 1
      end
    end
  end

  if #results == 0 then
    vim.notify('No code actions available', vim.log.levels.INFO, {
      title = 'CosmicUI',
    })
    return
  end

  local menu = Menu({
    position = {
      row = 1,
      col = 0,
    },
    relative = 'cursor',
    border = {
      highlight = 'FloatBorder',
      style = _G.CosmicUI_user_opts.border,
      text = {
        top = 'Code Actions',
        top_align = 'center',
      },
    },
    win_options = {
      winhighlight = 'NormalFloat:NormalFloat',
    },
  }, {
    lines = menu_items,
    separator = {
      char = '-',
      text_align = 'left',
    },
    keymap = {
      focus_next = { 'j', '<Down>', '<Tab>' },
      focus_prev = { 'k', '<Up>', '<S-Tab>' },
      close = { '<Esc>', '<C-c>' },
      submit = { '<CR>', '<Space>' },
    },
    on_submit = function(item)
      local action = results[item._index].command
      local client = results[item._index].client

      client.request('codeAction/resolve', action, function(resolved_err, resolved_action)
        if resolved_err then
          vim.notify(resolved_err.code .. ': ' .. resolved_err.message, vim.log.levels.ERROR)
          return
        end
        if resolved_action then
          execute_action(transform_action(resolved_action))
        else
          execute_action(transform_action(action))
        end
      end)
    end,
  })

  -- mount the component
  menu:mount()

  -- close menu when cursor leaves buffer
  menu:on(event.BufLeave, menu.menu_props.on_close, { once = true })
end

return M
