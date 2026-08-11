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

  it('places cursor floats below the cursor when there is room', function()
    local window = require('cosmic-ui.window')

    local config = window.cursor_float_config({
      row = 4,
      col = 10,
      above = 4,
      below = 18,
    }, 30, 6, { border = 'single' })

    assert.are.equal('editor', config.relative)
    assert.are.equal('NW', config.anchor)
    assert.are.equal(5, config.row)
    assert.are.equal(10, config.col)
    assert.are.equal(6, config.height)
  end)

  it('flips cursor floats above the cursor when space below is insufficient', function()
    local window = require('cosmic-ui.window')

    local config = window.cursor_float_config({
      row = 18,
      col = 10,
      above = 18,
      below = 4,
    }, 30, 6, { border = 'single' })

    assert.are.equal('editor', config.relative)
    assert.are.equal('SW', config.anchor)
    assert.are.equal(18, config.row)
    assert.are.equal(10, config.col)
    assert.are.equal(6, config.height)
  end)

  it('keeps cursor floats below when neither side fits but below is larger', function()
    local window = require('cosmic-ui.window')

    local config = window.cursor_float_config({
      row = 4,
      col = 0,
      above = 4,
      below = 10,
    }, 30, 20, { border = 'single' })

    assert.are.equal('NW', config.anchor)
    assert.are.equal(5, config.row)
    assert.are.equal(8, config.height)
  end)

  it('clamps flipped cursor floats to the space above the cursor', function()
    local window = require('cosmic-ui.window')

    local config = window.cursor_float_config({
      row = 15,
      col = 0,
      above = 15,
      below = 3,
    }, 30, 20, { border = 'single' })

    assert.are.equal('SW', config.anchor)
    assert.are.equal(15, config.row)
    assert.are.equal(13, config.height)
  end)

  it('clamps cursor float columns to the editor width', function()
    local window = require('cosmic-ui.window')
    local original_columns = vim.o.columns

    local ok, err = pcall(function()
      vim.o.columns = 40

      local config = window.cursor_float_config({
        row = 2,
        col = 35,
        above = 2,
        below = 15,
      }, 20, 4, { border = 'single' })

      assert.are.equal(18, config.col)
    end)

    vim.o.columns = original_columns

    assert.is_true(ok, err)
  end)
end)
