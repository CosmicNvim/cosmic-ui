describe('cosmic-ui.formatters.ui.input', function()
  it('moves the selection with j and Tab and toggles the selected row with Enter', function()
    local input = require('cosmic-ui.formatters.ui.input')
    local original_buf = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_create_buf(false, true)
    local target_buf = vim.api.nvim_create_buf(false, true)
    local ui = {
      buf = buf,
      selected = 2,
      scope = 'buffer',
      target_bufnr = target_buf,
      rows = {
        { kind = 'section', text = 'Conform' },
        {
          kind = 'item',
          toggleable = true,
          action = { kind = 'item', source = 'conform', name = 'stylua' },
        },
        {
          kind = 'item',
          toggleable = true,
          action = { kind = 'item', source = 'conform', name = 'prettier' },
        },
      },
    }
    local render_calls = 0
    local update_calls = 0
    local toggle_calls = 0

    vim.api.nvim_set_current_buf(buf)

    input.set_keymaps(ui, {
      reset_fn = function() end,
      format_async_fn = function() end,
    }, {
      close_fn = function() end,
      update_selection_fn = function(target_ui)
        update_calls = update_calls + 1
        assert.are.equal(ui, target_ui)
      end,
      render_fn = function()
        render_calls = render_calls + 1
      end,
      state = {
        get_effective_item_state = function()
          return true
        end,
        set_item_state = function()
          toggle_calls = toggle_calls + 1
        end,
      },
    })

    vim.api.nvim_feedkeys('j', 'xt', false)
    vim.cmd('redraw')

    assert.are.equal(3, ui.selected)
    assert.are.equal(1, update_calls)
    assert.are.equal(0, render_calls)

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Tab>', true, false, true), 'xt', false)
    vim.cmd('redraw')

    assert.are.equal(2, ui.selected)
    assert.are.equal(2, update_calls)
    assert.are.equal(0, render_calls)
    assert.are.equal(0, toggle_calls)

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, false, true), 'xt', false)
    vim.cmd('redraw')

    vim.api.nvim_set_current_buf(original_buf)
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.api.nvim_buf_delete(target_buf, { force = true })

    assert.are.equal(2, ui.selected)
    assert.are.equal(2, update_calls)
    assert.are.equal(1, render_calls)
    assert.are.equal(1, toggle_calls)
  end)

  it('closes the panel before formatting its target buffer', function()
    local input = require('cosmic-ui.formatters.ui.input')
    local original_buf = vim.api.nvim_get_current_buf()
    local panel_buf = vim.api.nvim_create_buf(false, true)
    local target_buf = vim.api.nvim_create_buf(false, true)
    local calls = {}
    local ui = {
      buf = panel_buf,
      selected = 1,
      scope = 'buffer',
      target_bufnr = target_buf,
      rows = {},
    }

    vim.api.nvim_set_current_buf(panel_buf)
    input.set_keymaps(ui, {
      reset_fn = function() end,
      format_async_fn = function(opts)
        table.insert(calls, {
          kind = 'format',
          opts = opts,
          current_buf = vim.api.nvim_get_current_buf(),
        })
      end,
    }, {
      close_fn = function()
        table.insert(calls, { kind = 'close' })
        vim.api.nvim_set_current_buf(target_buf)
      end,
      update_selection_fn = function() end,
      render_fn = function() end,
      state = {},
    })

    vim.api.nvim_feedkeys('f', 'xt', false)
    vim.cmd('redraw')

    vim.api.nvim_set_current_buf(original_buf)
    vim.api.nvim_buf_delete(panel_buf, { force = true })
    vim.api.nvim_buf_delete(target_buf, { force = true })

    assert.are.same({
      { kind = 'close' },
      {
        kind = 'format',
        opts = { scope = 'buffer', bufnr = target_buf },
        current_buf = target_buf,
      },
    }, calls)
  end)
end)
