local utils = require('cosmic-ui.utils')
local config = require('cosmic-ui.config')
local guard = require('cosmic-ui.guard')
local request = require('cosmic-ui.codeactions.request')
local execute = require('cosmic-ui.codeactions.execute')
local ui = require('cosmic-ui.codeactions.ui')
local model = require('cosmic-ui.codeactions.ui.model')
local logger = utils.Logger

local M = {}
local state = {
  last_action = nil,
}

local function remember_last_action(executed)
  local client = executed.client
  state.last_action = {
    title = executed.title or '',
    action_kind = executed.kind,
    client_name = client and client.name or nil,
  }
end

local function find_matching_action(actions, previous)
  local function action_matches(action, require_client_name)
    if action.title ~= previous.title then
      return false
    end

    if action.action_kind ~= previous.action_kind then
      return false
    end

    if not require_client_name then
      return true
    end

    local action_client_name = action.client and action.client.name or nil
    return action_client_name == previous.client_name
  end

  for _, action in ipairs(actions) do
    if action_matches(action, true) then
      return action
    end
  end

  for _, action in ipairs(actions) do
    if action_matches(action, false) then
      return action
    end
  end

  return nil
end

local function get_codeaction_clients(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/codeAction' })
  if #clients == 0 then
    logger:warn('No LSP clients with code actions attached')
    return nil
  end
  return clients
end

local function run_code_actions(opts)
  local bufnr = 0
  local clients = get_codeaction_clients(bufnr)
  if not clients then
    return
  end

  opts = utils.merge({ params = nil, range = nil, on_action_executed = nil }, opts or {})
  local user_opts = config.module_opts('codeactions') or {}

  request.collect({
    bufnr = bufnr,
    clients = clients,
    user_opts = opts,
    on_complete = function(results_lsp)
      ui.open(results_lsp, utils.merge(user_opts, {
        on_action_executed = opts.on_action_executed,
      }))
    end,
  })
end

M.open = function(opts)
  if not guard.can_run('codeactions', 'codeactions.open(...)') then
    return
  end

  opts = opts or {}
  opts.on_action_executed = remember_last_action
  return run_code_actions(opts)
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

  opts.on_action_executed = remember_last_action
  return run_code_actions(opts)
end

M.repeat_last = function(opts)
  if not guard.can_run('codeactions', 'codeactions.repeat_last(...)') then
    return
  end

  local previous = state.last_action
  if not previous then
    logger:warn('No previous code action to repeat')
    return
  end

  local bufnr = 0
  local clients = get_codeaction_clients(bufnr)
  if not clients then
    return
  end

  opts = utils.merge({ params = nil, range = nil }, opts or {})

  request.collect({
    bufnr = bufnr,
    clients = clients,
    user_opts = opts,
    on_complete = function(results_lsp)
      local built = model.build(results_lsp)
      if #built.actions == 0 then
        logger:log('No code actions available')
        return
      end

      local matched = find_matching_action(built.actions, previous)
      if not matched then
        logger:warn('No matching code action found for "' .. previous.title .. '" in current context')
        return
      end

      execute.run(matched, remember_last_action)
    end,
  })
end

return M
