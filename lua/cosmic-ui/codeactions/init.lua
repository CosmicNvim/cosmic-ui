local utils = require('cosmic-ui.utils')
local config = require('cosmic-ui.config')
local guard = require('cosmic-ui.guard')
local request = require('cosmic-ui.codeactions.request')
local execute = require('cosmic-ui.codeactions.execute')
local ui = require('cosmic-ui.codeactions.ui')
local logger = utils.Logger

local M = {}

local function collect_actions(results_lsp)
  local actions = {}

  for _, response in pairs(results_lsp or {}) do
    if response.client and type(response.result) == 'table' then
      for _, action in ipairs(response.result) do
        table.insert(actions, {
          client = response.client,
          command = action,
        })
      end
    end
  end

  return actions
end

local function select_preferred(actions)
  local preferred = {}
  for _, action in ipairs(actions) do
    if action.command and action.command.isPreferred == true then
      table.insert(preferred, action)
    end
  end

  if #preferred == 1 then
    return preferred[1], 'single'
  end

  if #preferred == 0 then
    return nil, 'none'
  end

  return nil, 'multiple'
end

local function apply_preferred(results_lsp, warn_on_failure)
  local actions = collect_actions(results_lsp)
  local selected, reason = select_preferred(actions)
  if selected then
    execute.execute(selected.command, selected.client)
    logger:log(('Applied preferred code action: %s'):format(selected.command.title or ''))
    return true
  end

  if warn_on_failure then
    if reason == 'none' then
      logger:warn('No preferred code action available in this context')
    else
      logger:warn('Multiple preferred code actions available; open menu to choose one')
    end
  end

  return false
end

local function run_code_actions(opts, mode)
  local bufnr = 0
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/codeAction' })
  if #clients == 0 then
    logger:warn('No LSP clients with code actions attached')
    return
  end

  local request_opts = utils.merge({
    params = nil,
    range = nil,
    fallback_to_menu = true,
  }, opts or {})
  local module_opts = config.module_opts('codeactions') or {}

  request.collect({
    bufnr = bufnr,
    clients = clients,
    user_opts = request_opts,
    on_complete = function(results_lsp)
      if mode == 'preferred' then
        if apply_preferred(results_lsp, request_opts.fallback_to_menu == false) then
          return
        end

        if request_opts.fallback_to_menu == false then
          return
        end
      elseif module_opts.auto_apply_preferred_if_single then
        if apply_preferred(results_lsp, false) then
          return
        end
      end

      ui.open(results_lsp, module_opts)
    end,
  })
end

M.open = function(opts)
  if not guard.can_run('codeactions', 'codeactions.open(...)') then
    return
  end

  return run_code_actions(opts, 'menu')
end

M.range = function(opts)
  if not guard.can_run('codeactions', 'codeactions.range(...)') then
    return
  end

  opts = opts or {}
  if not opts.range and not opts.params then
    local bufnr = 0
    local start_pos = vim.api.nvim_buf_get_mark(bufnr, '<')
    local end_pos = vim.api.nvim_buf_get_mark(bufnr, '>')
    opts = utils.merge({
      range = {
        start = { start_pos[1], start_pos[2] },
        ['end'] = { end_pos[1], end_pos[2] },
      },
    }, opts)
  end

  return run_code_actions(opts, 'menu')
end

M.preferred = function(opts)
  if not guard.can_run('codeactions', 'codeactions.preferred(...)') then
    return
  end

  return run_code_actions(opts, 'preferred')
end

return M
