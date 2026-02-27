local M = {}

local function next_index(ui, step)
  local total = #ui.model.actions
  if total == 0 then
    return nil
  end

  local current = ui.selected or 1
  local next_idx = current + step
  if next_idx < 1 then
    next_idx = total
  elseif next_idx > total then
    next_idx = 1
  end
  return next_idx
end

M.set_keymaps = function(ui, handlers, deps)
  local function map(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { buffer = ui.buf, silent = true, nowait = true })
  end

  local function move(step)
    local idx = next_index(ui, step)
    if not idx then
      return
    end
    ui.selected = idx
    deps.render_fn(ui)
  end

  local function submit()
    if not ui.selected then
      return
    end
    local action = ui.model.actions[ui.selected]
    if not action then
      return
    end

    deps.close_fn()
    handlers.submit_action(action)
  end

  map('n', 'j', function()
    move(1)
  end)
  map('n', '<Down>', function()
    move(1)
  end)
  map('n', '<Tab>', function()
    move(1)
  end)

  map('n', 'k', function()
    move(-1)
  end)
  map('n', '<Up>', function()
    move(-1)
  end)
  map('n', '<S-Tab>', function()
    move(-1)
  end)

  map('n', '<CR>', submit)
  map('n', '<Space>', submit)

  map('n', '<Esc>', deps.close_fn)
  map('n', '<C-c>', deps.close_fn)
end

return M
