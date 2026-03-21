describe("cosmic-ui.rename.model", function()
  it("rejects empty submissions without dispatching rename", function()
    local model = require("cosmic-ui.rename.model")
    local result = model.normalize_submission("> ", "> ", "> ")

    assert.are.same({ ok = false, reason = "empty" }, result)
  end)

  it("rejects unchanged submissions", function()
    local model = require("cosmic-ui.rename.model")
    local result = model.normalize_submission("> ", "> current_name", "current_name")

    assert.are.same({ ok = false, reason = "unchanged" }, result)
  end)
end)

describe("cosmic-ui.rename.ui", function()
  local original_get_clients
  local original_expand

  local function stub_rename_context(current_name)
    original_get_clients = vim.lsp.get_clients
    original_expand = vim.fn.expand

    vim.lsp.get_clients = function()
      return {
        { id = 1, name = "lua_ls" },
      }
    end

    vim.fn.expand = function(expr)
      if expr == "<cword>" then
        return current_name
      end

      return original_expand(expr)
    end
  end

  local function restore_rename_context()
    if original_get_clients then
      vim.lsp.get_clients = original_get_clients
      original_get_clients = nil
    end

    if original_expand then
      vim.fn.expand = original_expand
      original_expand = nil
    end
  end

  local function press(keys)
    vim.api.nvim_feedkeys(vim.keycode(keys), "xt", false)
  end

  after_each(function()
    restore_rename_context()

    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local config = vim.api.nvim_win_get_config(win)
      if config.relative ~= "" then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end

    vim.cmd("silent! only")
  end)

  it("restores focus to the origin window on submit", function()
    stub_rename_context("current_name")

    local ui = require("cosmic-ui.rename.ui")
    local origin_win = vim.api.nvim_get_current_win()
    local submitted

    vim.cmd("split")
    vim.api.nvim_set_current_win(origin_win)

    ui.open({
      default_value = "next_name",
      on_submit = function(new_name)
        submitted = {
          name = new_name,
          win = vim.api.nvim_get_current_win(),
        }
      end,
    })

    press("<CR>")
    vim.wait(1000, function()
      return submitted ~= nil
    end)

    assert.are.equal(origin_win, vim.api.nvim_get_current_win())
    assert.are.same({
      name = "next_name",
      win = origin_win,
    }, submitted)
  end)

  it("rejects empty submit from the panel without dispatching rename", function()
    stub_rename_context("current_name")

    local ui = require("cosmic-ui.rename.ui")
    local submissions = 0

    ui.open({
      default_value = "",
      on_submit = function()
        submissions = submissions + 1
      end,
    })

    press("<CR>")
    vim.wait(1000, function()
      local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false)
      return vim.tbl_contains(lines, " Name cannot be empty ")
    end)

    assert.are.equal(0, submissions)
    assert.is_true(vim.api.nvim_win_get_config(vim.api.nvim_get_current_win()).relative ~= "")
    assert.is_true(vim.tbl_contains(
      vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false),
      " Name cannot be empty "
    ))
  end)

  it("rejects unchanged submit from the panel without dispatching rename", function()
    stub_rename_context("current_name")

    local ui = require("cosmic-ui.rename.ui")
    local submissions = 0

    ui.open({
      default_value = "current_name",
      on_submit = function()
        submissions = submissions + 1
      end,
    })

    press("<CR>")
    vim.wait(1000, function()
      local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false)
      return vim.tbl_contains(lines, " Name is unchanged ")
    end)

    assert.are.equal(0, submissions)
    assert.is_true(vim.api.nvim_win_get_config(vim.api.nvim_get_current_win()).relative ~= "")
    assert.is_true(vim.tbl_contains(
      vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false),
      " Name is unchanged "
    ))
  end)

  it("restores focus to the origin window on cancel", function()
    stub_rename_context("current_name")

    local ui = require("cosmic-ui.rename.ui")
    local origin_win = vim.api.nvim_get_current_win()

    vim.cmd("split")
    vim.api.nvim_set_current_win(origin_win)

    ui.open({
      default_value = "next_name",
      on_submit = function()
        error("rename should not submit on cancel")
      end,
    })

    press("<Esc>")
    vim.wait(1000, function()
      return vim.api.nvim_get_current_win() == origin_win
    end)

    assert.are.equal(origin_win, vim.api.nvim_get_current_win())
  end)
end)
