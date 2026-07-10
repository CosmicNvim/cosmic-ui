describe('cosmic-ui.window', function()
  it('fits centered floats inside a small editor', function()
    local window = require('cosmic-ui.window')
    local original = {
      columns = vim.o.columns,
      lines = vim.o.lines,
      cmdheight = vim.o.cmdheight,
    }

    local ok, err = pcall(function()
      vim.o.columns = 20
      vim.o.lines = 10
      vim.o.cmdheight = 1

      local width, height = window.fit_float_size(64, 14, {
        width_ratio = 0.9,
        height_ratio = 0.8,
        border = 'rounded',
      })
      local centered = window.centered_float_config(64, 14, {
        width_ratio = 0.9,
        height_ratio = 0.8,
        border = 'rounded',
      })

      assert.are.same({ 16, 5 }, { width, height })
      assert.are.same({
        width = 16,
        height = 5,
        row = 1,
        col = 1,
      }, centered)
    end)

    vim.o.columns = original.columns
    vim.o.lines = original.lines
    vim.o.cmdheight = original.cmdheight

    assert.is_true(ok, err)
  end)
end)
