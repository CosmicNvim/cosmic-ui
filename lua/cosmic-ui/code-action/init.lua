-- big shout out to telescope
-- https://github.com/nvim-telescope/telescope.nvim/blob/master/lua/telescope/builtin/lsp.lua#L144
local Menu = require('nui.menu')
local Text = require('nui.text')
local event = require('nui.utils.autocmd').event
local utils = require('cosmic-ui.utils')
local config = require('cosmic-ui.config')
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

local function execute_action(action, client)
  if action.edit or type(action.command) == 'table' then
    if action.edit then
      vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
    end
    if type(action.command) == 'table' then
      client:exec_cmd(action.command)
    end
  else
    client:exec_cmd(action)
  end
end

local function supports_code_action_resolve(client)
  if not client then
    return false
  end

  if type(client.supports_method) == 'function' and client:supports_method('codeAction/resolve') then
    return true
  end

  local server_capabilities = client.server_capabilities or {}
  local code_action_provider = server_capabilities.codeActionProvider or server_capabilities.codeAction

  return type(code_action_provider) == 'table'
      and (code_action_provider.resolveProvider or code_action_provider.resolve_provider)
end

local function code_action_diagnostics(client_id, bufnr, lnum)
  local diagnostics = {}
  local ns_push = vim.lsp.diagnostic.get_namespace(client_id, false)
  local ns_pull = vim.lsp.diagnostic.get_namespace(client_id, true)

  vim.list_extend(diagnostics, vim.diagnostic.get(bufnr, { namespace = ns_pull, lnum = lnum }))
  vim.list_extend(diagnostics, vim.diagnostic.get(bufnr, { namespace = ns_push, lnum = lnum }))

  local lsp_diagnostics = {}
  for _, diagnostic in ipairs(diagnostics) do
    local lsp_diagnostic = diagnostic.user_data and diagnostic.user_data.lsp
    if lsp_diagnostic then
      table.insert(lsp_diagnostics, lsp_diagnostic)
    end
  end

  return lsp_diagnostics
end

M.code_actions = function(opts)
  local bufnr = 0
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/codeAction' })
  if #clients == 0 then
    logger:warn('No LSP clients with code actions attached')
    return
  end

  opts = utils.merge({ params = nil, range = nil }, opts or {})
  local user_opts = config.module_opts('codeactions') or {}
  local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
  local pending = #clients
  local results_lsp = {}

  local function on_result(client)
    return function(err, result)
      results_lsp[client.id] = {
        error = err,
        result = result,
        client = client,
      }

      pending = pending - 1
      if pending > 0 then
        return
      end

      if not results_lsp or next(results_lsp) == nil then
        logger:warn('No results from textDocument/codeAction')
        return
      end

      -- items for menu
      local menu_items = {}
      -- result items to filter through
      local result_items = {}
      local min_width = 0

      for _, response in pairs(results_lsp) do
        if response.result and next(response.result) ~= nil then
          local client = response.client

          -- Client can detach between request and UI render.
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
        on_change = function(item, menu)
          local pos = utils.index_of(result_items, item)
          local text = '(' .. tostring(pos) .. '/' .. #result_items .. ')'
          menu.border:set_text('bottom', Text(text, user_border.bottom_hl), 'right')
        end,
        on_submit = function(item)
          local action = item.ctx.command
          local client = item.ctx.client

          if not client then
            logger:warn('Code action client is no longer available')
            return
          end

          if not action.edit and supports_code_action_resolve(client) then
            client:request('codeAction/resolve', action, function(resolved_err, resolved_action)
              if resolved_err then
                logger:error(resolved_err.code .. ': ' .. resolved_err.message)
                return
              end
              if resolved_action then
                execute_action(transform_action(resolved_action), client)
              else
                execute_action(transform_action(action), client)
              end
            end)
          else
            execute_action(transform_action(action), client)
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
  end

  for _, client in ipairs(clients) do
    local params
    if opts.range and opts.range.start and opts.range['end'] then
      params = vim.lsp.util.make_given_range_params(opts.range.start, opts.range['end'], bufnr, client.offset_encoding)
    elseif opts.params then
      params = vim.deepcopy(opts.params)
    else
      params = vim.lsp.util.make_range_params(0, client.offset_encoding)
    end

    local context = vim.deepcopy(params.context or {})

    if not context.diagnostics then
      context.diagnostics = code_action_diagnostics(client.id, bufnr, lnum)
    end

    params.context = context
    client:request('textDocument/codeAction', params, on_result(client), bufnr)
  end
end

return M
