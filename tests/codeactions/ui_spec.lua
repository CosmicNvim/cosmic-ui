describe("cosmic-ui.codeactions.ui", function()
  local lifecycle

  before_each(function()
    lifecycle = require("cosmic-ui.codeactions.ui.lifecycle")
    lifecycle.close_current()
  end)

  after_each(function()
    lifecycle.close_current()
  end)

  it("opens an explicit empty-state panel when no actions are available", function()
    local ui = require("cosmic-ui.codeactions.ui")

    ui.open({
      [1] = {
        client = { id = 1, name = "lua_ls" },
        result = {},
      },
    }, {})

    local state = lifecycle.get_state()
    assert.is_not_nil(state.ui)
    assert.is_true(vim.api.nvim_buf_is_valid(state.ui.buf))
    assert.is_true(vim.tbl_contains(vim.api.nvim_buf_get_lines(state.ui.buf, 0, -1, false), " No code actions available "))
  end)

  it("supports numeric direct picks for the first visible actions", function()
    local input = require("cosmic-ui.codeactions.ui.input")

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_get_current_win()
    local selected
    local closed = 0

    local ui = {
      buf = buf,
      win = win,
      selected = 1,
      model = {
        actions = {
          { text = "First action" },
          { text = "Second action" },
          { text = "Third action" },
        },
      },
    }

    input.set_keymaps(ui, {
      submit_action = function(action)
        selected = action.text
      end,
    }, {
      close_fn = function()
        closed = closed + 1
      end,
      render_fn = function() end,
    })

    vim.api.nvim_set_current_win(win)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_feedkeys("2", "xt", false)

    assert.are.equal("Second action", selected)
    assert.are.equal(1, closed)
  end)
end)
