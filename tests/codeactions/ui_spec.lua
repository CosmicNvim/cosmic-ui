describe('cosmic-ui.codeactions.ui', function()
  local lifecycle
  local function collect_highlights(bufnr, ns)
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
    local collected = {}

    for _, mark in ipairs(marks) do
      table.insert(collected, {
        lnum = mark[2],
        col = mark[3],
        end_col = mark[4].end_col,
        hl_group = mark[4].hl_group,
      })
    end

    return collected
  end

  local function has_highlight(highlights, expected)
    for _, highlight in ipairs(highlights) do
      if vim.deep_equal(highlight, expected) then
        return true
      end
    end

    return false
  end

  before_each(function()
    lifecycle = require('cosmic-ui.codeactions.ui.lifecycle')
    lifecycle.close_current()
  end)

  after_each(function()
    lifecycle.close_current()
  end)

  it('opens an explicit empty-state panel when no actions are available', function()
    local ui = require('cosmic-ui.codeactions.ui')

    ui.open({
      [1] = {
        client = { id = 1, name = 'lua_ls' },
        result = {},
      },
    }, {})

    local state = lifecycle.get_state()
    assert.is_not_nil(state.ui)
    assert.is_true(vim.api.nvim_buf_is_valid(state.ui.buf))
    assert.is_true(
      vim.tbl_contains(vim.api.nvim_buf_get_lines(state.ui.buf, 0, -1, false), ' No code actions available ')
    )
  end)

  it('requests normal-mode normalization when opened outside normal mode', function()
    local ui = require('cosmic-ui.codeactions.ui')
    local original_mode = vim.fn.mode
    local original_input = vim.api.nvim_input
    local seen = {}

    vim.fn.mode = function()
      return 'i'
    end
    vim.api.nvim_input = function(keys)
      table.insert(seen, keys)
      return ''
    end

    local ok, err = pcall(function()
      ui.open({
        [1] = {
          client = { id = 1, name = 'lua_ls' },
          result = {
            { title = 'Fix' },
          },
        },
      }, {})
    end)

    vim.fn.mode = original_mode
    vim.api.nvim_input = original_input

    if not ok then
      error(err)
    end

    ui.close()
    assert.are.same({ '<Esc>' }, seen)
  end)

  it('does not render in-buffer footer helper rows', function()
    local ui = require('cosmic-ui.codeactions.ui')

    ui.open({
      [1] = {
        client = { id = 1, name = 'lua_ls' },
        result = {
          { title = 'Fix' },
        },
      },
    }, {})

    local state = lifecycle.get_state()
    local lines = vim.api.nvim_buf_get_lines(state.ui.buf, 0, -1, false)

    assert.is_false(vim.tbl_contains(lines, ' Esc:close '))
    assert.is_false(vim.tbl_contains(lines, ' Enter:apply  Esc:close '))
  end)

  it('preserves configured min width and border metadata on the float', function()
    local ui = require('cosmic-ui.codeactions.ui')

    ui.open({
      [1] = {
        client = { id = 1, name = 'lua_ls' },
        result = {
          { title = 'Fix' },
        },
      },
    }, {
      min_width = 50,
      border = {
        style = 'single',
        title = 'Custom Actions',
        title_align = 'left',
        title_hl = 'Title',
        bottom_hl = 'Question',
        highlight = 'Identifier',
      },
    })

    local state = lifecycle.get_state()
    local cfg = vim.api.nvim_win_get_config(state.ui.win)

    assert.are.equal(52, cfg.width)
    assert.are.equal('table', type(cfg.border))
    assert.are.equal('┌', cfg.border[1])
    assert.are.equal('Custom Actions', cfg.title[1][1])
    assert.are.equal('left', cfg.title_pos)
    assert.are.equal('(1/1)', cfg.footer[1][1])
    assert.are.equal('right', cfg.footer_pos)
    assert.is_true(string.find(vim.wo[state.ui.win].winhl, 'FloatBorder:Identifier', 1, true) ~= nil)
    assert.is_true(string.find(vim.wo[state.ui.win].winhl, 'FloatTitle:Title', 1, true) ~= nil)
    assert.is_true(string.find(vim.wo[state.ui.win].winhl, 'FloatFooter:Question', 1, true) ~= nil)
  end)

  it('renders footer text and highlight spans with the shared panel footer output', function()
    local panel = require('cosmic-ui.ui.panel')
    local render = require('cosmic-ui.codeactions.ui.render')
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_get_current_win()
    local ui = {
      buf = buf,
      win = win,
      ns = vim.api.nvim_create_namespace('cosmic-ui-codeactions-footer-spec'),
      min_width = 30,
      model = { actions = {} },
      panel = panel.build({
        footer = {
          'Enter:apply',
          'Esc:close',
        },
      }),
    }

    render.render(ui)

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local extmarks = collect_highlights(buf, ui.ns)

    assert.are.same({ ' Enter:apply  Esc:close ' }, lines)
    assert.is_true(has_highlight(extmarks, {
      lnum = 0,
      col = 1,
      end_col = 6,
      hl_group = 'CosmicUiPanelHintKey',
    }))
    assert.is_true(has_highlight(extmarks, {
      lnum = 0,
      col = 7,
      end_col = 12,
      hl_group = 'CosmicUiPanelHintText',
    }))
    assert.is_true(has_highlight(extmarks, {
      lnum = 0,
      col = 14,
      end_col = 17,
      hl_group = 'CosmicUiPanelHintKey',
    }))
    assert.is_true(has_highlight(extmarks, {
      lnum = 0,
      col = 18,
      end_col = 23,
      hl_group = 'CosmicUiPanelHintText',
    }))

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  it('keeps the standard code-actions render output unchanged after shared prep extraction', function()
    local panel = require('cosmic-ui.ui.panel')
    local render = require('cosmic-ui.codeactions.ui.render')
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, false, {
      relative = 'editor',
      row = 1,
      col = 1,
      width = 40,
      height = 8,
      style = 'minimal',
      border = 'single',
    })
    local ui = {
      buf = buf,
      win = win,
      ns = vim.api.nvim_create_namespace('cosmic-ui-codeactions-standard-render-spec'),
      min_width = 30,
      selected = 1,
      border = {},
      model = {
        actions = {
          { text = 'Fix A' },
          { text = 'Fix B' },
        },
      },
      panel = panel.build({
        footer = {
          'Enter:apply',
          'Esc:close',
        },
        rows = {
          { kind = 'section', text = 'alpha' },
          { kind = 'action', text = 'Fix A' },
          { kind = 'separator', text = 'beta' },
          { kind = 'action', text = 'Fix B' },
        },
      }),
    }

    render.render(ui)

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local extmarks = collect_highlights(buf, ui.ns)

    assert.are.same({
      '             alpha              ',
      ' Fix A ',
      '',
      '              beta              ',
      ' Fix B ',
      '',
      ' Enter:apply  Esc:close ',
    }, lines)
    assert.is_true(has_highlight(extmarks, {
      lnum = 0,
      col = 0,
      end_col = 0,
      hl_group = 'CosmicUiPanelSection',
    }))
    assert.is_true(has_highlight(extmarks, {
      lnum = 3,
      col = 0,
      end_col = 0,
      hl_group = 'CosmicUiPanelSection',
    }))
    assert.are.same({
      [1] = 2,
      [2] = 5,
    }, ui.action_line_by_idx)

    vim.api.nvim_win_close(win, true)
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  it('updates selection without rebuilding layout state', function()
    local panel = require('cosmic-ui.ui.panel')
    local render = require('cosmic-ui.codeactions.ui.render')
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, false, {
      relative = 'editor',
      row = 1,
      col = 1,
      width = 30,
      height = 6,
      style = 'minimal',
      border = 'single',
    })
    local ui = {
      buf = buf,
      win = win,
      ns = vim.api.nvim_create_namespace('cosmic-ui-codeactions-selection-spec'),
      min_width = 30,
      selected = 1,
      border = {},
      model = {
        actions = {
          { text = 'Fix A' },
          { text = 'Fix B' },
        },
      },
      panel = panel.build({
        rows = {
          { kind = 'section', text = 'lua_ls' },
          { kind = 'action', text = 'Fix A' },
          { kind = 'action', text = 'Fix B' },
        },
      }),
    }

    render.render(ui)

    local lines_before = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local cfg_before = vim.api.nvim_win_get_config(win)
    local original_strdisplaywidth = vim.fn.strdisplaywidth
    local original_set_lines = vim.api.nvim_buf_set_lines
    local original_clear_namespace = vim.api.nvim_buf_clear_namespace
    local original_add_highlight = vim.api.nvim_buf_add_highlight
    local original_set_config = vim.api.nvim_win_set_config

    vim.fn.strdisplaywidth = function()
      error('selection update should not remeasure widths')
    end
    vim.api.nvim_buf_set_lines = function()
      error('selection update should not rebuild line specs')
    end
    vim.api.nvim_buf_clear_namespace = function()
      error('selection update should not clear existing highlights')
    end
    vim.api.nvim_buf_add_highlight = function()
      error('selection update should not rebuild highlights')
    end
    vim.api.nvim_win_set_config = function(target, cfg)
      assert.is_nil(cfg.width)
      assert.is_nil(cfg.height)
      assert.is_nil(cfg.row)
      assert.is_nil(cfg.col)
      return original_set_config(target, cfg)
    end

    local ok, err = pcall(function()
      ui.selected = 2
      render.update_selection(ui)
    end)

    vim.fn.strdisplaywidth = original_strdisplaywidth
    vim.api.nvim_buf_set_lines = original_set_lines
    vim.api.nvim_buf_clear_namespace = original_clear_namespace
    vim.api.nvim_buf_add_highlight = original_add_highlight
    vim.api.nvim_win_set_config = original_set_config

    if not ok then
      error(err)
    end

    local cfg_after = vim.api.nvim_win_get_config(win)

    assert.are.same(lines_before, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    assert.are.equal(cfg_before.width, cfg_after.width)
    assert.are.equal(cfg_before.height, cfg_after.height)
    assert.are.equal(cfg_before.row, cfg_after.row)
    assert.are.equal(cfg_before.col, cfg_after.col)
    assert.are.equal('(2/2)', cfg_after.footer[1][1])
    assert.are.same({ ui.action_line_by_idx[2], 0 }, vim.api.nvim_win_get_cursor(win))

    vim.api.nvim_win_close(win, true)
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  it('does not advertise numeric direct picks for small action lists', function()
    local ui = require('cosmic-ui.codeactions.ui')

    ui.open({
      [1] = {
        client = { id = 1, name = 'lua_ls' },
        result = {
          { title = 'Fix A' },
          { title = 'Fix B' },
        },
      },
    }, {})

    local state = lifecycle.get_state()
    local lines = vim.api.nvim_buf_get_lines(state.ui.buf, 0, -1, false)

    assert.is_false(vim.tbl_contains(lines, ' 1-9:pick '))
  end)

  it('does not render duplicate in-buffer title or action-count rows', function()
    local ui = require('cosmic-ui.codeactions.ui')

    ui.open({
      [1] = {
        client = { id = 1, name = 'lua_ls' },
        result = {
          { title = 'Fix A' },
          { title = 'Fix B' },
        },
      },
    }, {})

    local state = lifecycle.get_state()
    local lines = vim.api.nvim_buf_get_lines(state.ui.buf, 0, -1, false)

    assert.is_false(vim.tbl_contains(lines, ' Code Actions '))
    assert.is_false(vim.tbl_contains(lines, ' 2 actions '))
    assert.is_true(vim.tbl_contains(vim.tbl_map(vim.trim, lines), 'lua_ls'))
    assert.is_true(vim.tbl_contains(lines, ' Fix A '))
    assert.is_true(vim.tbl_contains(lines, ' Fix B '))
  end)

  it('renders action rows without numeric prefixes', function()
    local ui = require('cosmic-ui.codeactions.ui')

    ui.open({
      [1] = {
        client = { id = 1, name = 'lua_ls' },
        result = {
          { title = 'Fix A' },
          { title = 'Fix B' },
        },
      },
    }, {})

    local state = lifecycle.get_state()
    local lines = vim.api.nvim_buf_get_lines(state.ui.buf, 0, -1, false)

    assert.is_true(vim.tbl_contains(lines, ' Fix A '))
    assert.is_true(vim.tbl_contains(lines, ' Fix B '))
    assert.is_false(vim.tbl_contains(lines, ' 1. Fix A '))
    assert.is_false(vim.tbl_contains(lines, ' 2. Fix B '))
  end)

  it('centers section headers and inserts one blank row between client sections', function()
    local ui = require('cosmic-ui.codeactions.ui')

    ui.open({
      [2] = {
        client = { id = 2, name = 'zeta' },
        result = {
          { title = 'Fix trailing spaces' },
        },
      },
      [1] = {
        client = { id = 1, name = 'alpha' },
        result = {
          { title = 'Organize Imports' },
          { title = 'Extract Function' },
        },
      },
    }, {})

    local state = lifecycle.get_state()
    local lines = vim.api.nvim_buf_get_lines(state.ui.buf, 0, -1, false)

    local function find_trimmed(text)
      for idx, line in ipairs(lines) do
        if vim.trim(line) == text then
          return idx, line
        end
      end
      return nil, nil
    end

    local alpha_idx, alpha_line = find_trimmed('alpha')
    local zeta_idx, zeta_line = find_trimmed('zeta')

    assert.is_not_nil(alpha_idx)
    assert.is_not_nil(zeta_idx)
    assert.are.equal('', lines[zeta_idx - 1])

    local function assert_centered(line, label)
      local left_pad, text, right_pad = line:match('^(%s*)(.-)(%s*)$')
      assert.are.equal(label, text)
      assert.is_true(math.abs(#left_pad - #right_pad) <= 1)
    end

    assert_centered(alpha_line, 'alpha')
    assert_centered(zeta_line, 'zeta')
  end)

  it('does not reopen a dismissed loading panel when ready-state results arrive for the same request', function()
    local ui = require('cosmic-ui.codeactions.ui')

    local request_state = {
      status = 'loading',
      responses = {},
      total_clients = 1,
      completed_clients = 0,
    }

    ui.open(request_state, {})
    assert.is_not_nil(lifecycle.get_state().ui)

    ui.close()
    assert.is_nil(lifecycle.get_state().ui)

    request_state.status = 'ready'
    request_state.completed_clients = 1
    request_state.responses[1] = {
      client = { id = 1, name = 'lua_ls' },
      result = {
        { title = 'Fix' },
      },
    }

    ui.open(request_state, {})

    assert.is_nil(lifecycle.get_state().ui)
  end)

  it('reopens after a loading panel loses focus while the request is still in flight', function()
    local ui = require('cosmic-ui.codeactions.ui')

    local request_state = {
      status = 'loading',
      responses = {},
      total_clients = 1,
      completed_clients = 0,
    }

    ui.open(request_state, {})
    assert.is_not_nil(lifecycle.get_state().ui)

    local buf = lifecycle.get_state().ui.buf
    vim.api.nvim_exec_autocmds('BufLeave', { buffer = buf })

    assert.is_nil(lifecycle.get_state().ui)
    assert.is_false(lifecycle.is_request_dismissed(request_state))

    request_state.status = 'ready'
    request_state.completed_clients = 1
    request_state.responses[1] = {
      client = { id = 1, name = 'lua_ls' },
      result = {
        { title = 'Fix' },
      },
    }

    ui.open(request_state, {})

    local state = lifecycle.get_state()
    assert.is_not_nil(state.ui)
    assert.is_true(vim.tbl_contains(vim.api.nvim_buf_get_lines(state.ui.buf, 0, -1, false), ' Fix '))
  end)

  it('keeps explicit dismiss semantics when a ready panel is reused for a new loading request', function()
    local ui = require('cosmic-ui.codeactions.ui')

    ui.open({
      [1] = {
        client = { id = 1, name = 'lua_ls' },
        result = {
          { title = 'Fix A' },
        },
      },
    }, {})

    local request_state = {
      status = 'loading',
      responses = {},
      total_clients = 1,
      completed_clients = 0,
    }

    ui.open(request_state, {})
    assert.are.equal(request_state, lifecycle.get_state().ui.request_state)

    ui.close()
    assert.is_nil(lifecycle.get_state().ui)

    request_state.status = 'ready'
    request_state.completed_clients = 1
    request_state.responses[1] = {
      client = { id = 1, name = 'lua_ls' },
      result = {
        { title = 'Fix B' },
      },
    }

    ui.open(request_state, {})

    assert.is_nil(lifecycle.get_state().ui)
  end)

  it('does not install numeric direct-pick keymaps', function()
    local input = require('cosmic-ui.codeactions.ui.input')

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_get_current_win()

    local ui = {
      buf = buf,
      win = win,
      selected = 1,
      model = {
        actions = {
          { text = 'First action' },
          { text = 'Second action' },
          { text = 'Third action' },
        },
      },
    }

    input.set_keymaps(ui, {
      submit_action = function() end,
    }, {
      close_fn = function() end,
      render_fn = function() end,
    })

    local keymaps = vim.api.nvim_buf_get_keymap(buf, 'n')
    local numeric_lhs = {}

    for _, keymap in ipairs(keymaps) do
      if string.match(keymap.lhs, '^%d$') then
        table.insert(numeric_lhs, keymap.lhs)
      end
    end

    assert.are.same({}, numeric_lhs)
  end)

  it('routes selection navigation through the lightweight update path', function()
    local input = require('cosmic-ui.codeactions.ui.input')
    local original_buf = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_create_buf(false, true)
    local ui = {
      buf = buf,
      selected = 1,
      model = {
        actions = {
          { text = 'First action' },
          { text = 'Second action' },
        },
      },
    }
    local calls = {}

    vim.api.nvim_set_current_buf(buf)

    input.set_keymaps(ui, {
      submit_action = function() end,
    }, {
      close_fn = function() end,
      render_fn = function()
        table.insert(calls, 'render')
      end,
      update_selection_fn = function(target_ui)
        table.insert(calls, 'update')
        assert.are.equal(ui, target_ui)
      end,
    })

    vim.api.nvim_feedkeys('j', 'xt', false)
    vim.cmd('redraw')

    vim.api.nvim_set_current_buf(original_buf)
    vim.api.nvim_buf_delete(buf, { force = true })

    assert.are.equal(2, ui.selected)
    assert.are.same({ 'update' }, calls)
  end)
end)

describe('cosmic-ui.codeactions.request', function()
  it('reports loading before ready and keeps request metadata', function()
    local request = require('cosmic-ui.codeactions.request')
    local original_get_namespace = vim.lsp.diagnostic.get_namespace
    local original_diagnostic_get = vim.diagnostic.get
    local original_make_range_params = vim.lsp.util.make_range_params
    local callbacks = {}
    local seen = {}

    vim.lsp.diagnostic.get_namespace = function()
      return 0
    end
    vim.diagnostic.get = function()
      return {}
    end
    vim.lsp.util.make_range_params = function()
      return { context = {} }
    end

    local clients = {
      {
        id = 1,
        name = 'lua_ls',
        offset_encoding = 'utf-16',
        request = function(_, _, _, cb)
          callbacks[1] = cb
        end,
      },
      {
        id = 2,
        name = 'eslint',
        offset_encoding = 'utf-16',
        request = function(_, _, _, cb)
          callbacks[2] = cb
        end,
      },
    }

    local ok, err = pcall(function()
      request.collect({
        bufnr = 0,
        clients = clients,
        user_opts = { params = { context = { only = { 'quickfix' } } } },
        on_complete = function(state)
          table.insert(seen, {
            status = state.status,
            total_clients = state.total_clients,
            completed_clients = state.completed_clients,
            response_count = vim.tbl_count(state.responses),
          })
        end,
      })

      callbacks[1](nil, { { title = 'Fix one' } })
      callbacks[2](nil, { { title = 'Fix two' } })
    end)

    vim.lsp.diagnostic.get_namespace = original_get_namespace
    vim.diagnostic.get = original_diagnostic_get
    vim.lsp.util.make_range_params = original_make_range_params

    assert.is_true(ok, err)
    assert.are.same({
      {
        status = 'loading',
        total_clients = 2,
        completed_clients = 0,
        response_count = 0,
      },
      {
        status = 'ready',
        total_clients = 2,
        completed_clients = 2,
        response_count = 2,
      },
    }, seen)
  end)

  it('freezes the source buffer before the loading callback changes current buffer', function()
    local request = require('cosmic-ui.codeactions.request')
    local original_get_namespace = vim.lsp.diagnostic.get_namespace
    local original_diagnostic_get = vim.diagnostic.get
    local original_make_range_params = vim.lsp.util.make_range_params
    local seen = {}

    vim.lsp.diagnostic.get_namespace = function()
      return 0
    end
    vim.diagnostic.get = function()
      return {}
    end
    vim.lsp.util.make_range_params = function(_, _)
      return {
        textDocument = {
          uri = vim.uri_from_bufnr(vim.api.nvim_get_current_buf()),
        },
        context = {},
      }
    end

    local ok, err = pcall(function()
      vim.cmd('enew!')
      local source_buf = vim.api.nvim_get_current_buf()
      local source_name = vim.fn.tempname() .. '.ts'
      vim.api.nvim_buf_set_name(source_buf, source_name)
      local scratch_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(scratch_buf, 'scratch://loading')

      request.collect({
        bufnr = 0,
        clients = {
          {
            id = 1,
            name = 'lua_ls',
            offset_encoding = 'utf-16',
            request = function(_, _, params, cb, bufnr)
              table.insert(seen, {
                bufnr = bufnr,
                current_buf = vim.api.nvim_get_current_buf(),
                uri = params.textDocument and params.textDocument.uri or nil,
              })
              cb(nil, {})
            end,
          },
        },
        on_complete = function(state)
          if state.status == 'loading' then
            vim.api.nvim_set_current_buf(scratch_buf)
          end
        end,
      })

      assert.are.same({
        {
          bufnr = source_buf,
          current_buf = scratch_buf,
          uri = vim.uri_from_bufnr(source_buf),
        },
      }, seen)
    end)

    vim.lsp.diagnostic.get_namespace = original_get_namespace
    vim.diagnostic.get = original_diagnostic_get
    vim.lsp.util.make_range_params = original_make_range_params

    assert.is_true(ok, err)
  end)
end)
