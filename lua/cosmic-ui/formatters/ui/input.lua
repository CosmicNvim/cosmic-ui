local M = {}

local function next_toggleable_index(rows, start_idx, step)
  if #rows == 0 then
    return nil
  end

  local idx = start_idx
  for _ = 1, #rows do
    idx = idx + step
    if idx < 1 then
      idx = #rows
    elseif idx > #rows then
      idx = 1
    end

    if rows[idx].toggleable then
      return idx
    end
  end

  return nil
end

local function move_selection(ui, delta, handlers, deps)
  if not ui.rows or #ui.rows == 0 then
    return
  end

  local start = ui.selected or 1
  local next_idx = next_toggleable_index(ui.rows, start, delta)
  if next_idx then
    ui.selected = next_idx
    deps.render_fn(ui, handlers)
  end
end

local function toggle_action(action, ui, state)
  if not action or action.kind ~= 'item' then
    return
  end

  local current = state.get_effective_item_state(action.source, action.name, ui.scope, ui.target_bufnr)
  state.set_item_state(action.source, action.name, ui.scope, ui.target_bufnr, not current)
end

local function toggle_row(ui, handlers, deps)
  if not ui.selected then
    return
  end

  local row = ui.rows and ui.rows[ui.selected]
  if not row or not row.toggleable then
    return
  end

  toggle_action(row.action, ui, deps.state)
  deps.render_fn(ui, handlers)
end

local function toggle_all_rows(ui, handlers, deps)
  if not ui.rows then
    return
  end

  local toggleable = {}
  for _, row in ipairs(ui.rows) do
    if row.toggleable and row.action and row.action.kind == 'item' then
      table.insert(toggleable, row)
    end
  end

  if #toggleable == 0 then
    return
  end

  local all_enabled = true
  for _, row in ipairs(toggleable) do
    local is_enabled = deps.state.get_effective_item_state(row.action.source, row.action.name, ui.scope, ui.target_bufnr)
    if not is_enabled then
      all_enabled = false
      break
    end
  end

  for _, row in ipairs(toggleable) do
    if all_enabled then
      deps.state.set_item_state(row.action.source, row.action.name, ui.scope, ui.target_bufnr, false)
    else
      deps.state.set_item_state(row.action.source, row.action.name, ui.scope, ui.target_bufnr, true)
    end
  end

  deps.render_fn(ui, handlers)
end

M.set_keymaps = function(ui, handlers, deps)
  local function map(lhs, rhs)
    vim.keymap.set('n', lhs, rhs, { buffer = ui.buf, silent = true, nowait = true })
  end

  map('j', function()
    move_selection(ui, 1, handlers, deps)
  end)
  map('<Down>', function()
    move_selection(ui, 1, handlers, deps)
  end)

  map('k', function()
    move_selection(ui, -1, handlers, deps)
  end)
  map('<Up>', function()
    move_selection(ui, -1, handlers, deps)
  end)

  map('<Tab>', function()
    toggle_row(ui, handlers, deps)
  end)

  map('a', function()
    toggle_all_rows(ui, handlers, deps)
  end)

  map('r', function()
    handlers.reset_fn({ scope = ui.scope, bufnr = ui.target_bufnr })
    deps.render_fn(ui, handlers)
  end)

  map('s', function()
    ui.scope = (ui.scope == 'buffer') and 'global' or 'buffer'
    deps.render_fn(ui, handlers)
  end)

  map('f', function()
    handlers.format_async_fn({ scope = ui.scope, bufnr = ui.target_bufnr })
    deps.close_fn()
  end)

  map('<CR>', deps.close_fn)
  map('<Esc>', deps.close_fn)
  map('q', deps.close_fn)
end

return M
