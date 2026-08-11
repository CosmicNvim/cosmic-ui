describe('cosmic-ui.formatters.ui.rows', function()
  local function find_row(rows, id)
    for _, row in ipairs(rows) do
      if row.id == id then
        return row
      end
    end

    return nil
  end

  local function rstrip(text)
    return (text:gsub('%s+$', ''))
  end

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

  it('renders conform-unavailable rows with explanatory text', function()
    local rows = require('cosmic-ui.formatters.ui.rows')
    local built = rows.build_rows({
      conform = { available = false, reason = 'conform unavailable', formatters = {}, fallback = {} },
      lsp_clients = {},
    }, { conform = 'C', lsp = 'L', file = 'F', filetype = 'lua' }, { unavailable = '!' })

    local row = find_row(built, 'conform_unavailable')
    assert.are.same({
      id = 'conform_unavailable',
      text = '! C Conform unavailable: conform unavailable',
      toggleable = false,
      kind = 'info',
      status = 'unavailable',
      status_icon = '!',
      source_icon = 'C',
      reason = 'conform unavailable',
    }, row)
  end)

  it('renders empty backend rows with explicit source labels', function()
    local rows = require('cosmic-ui.formatters.ui.rows')
    local built = rows.build_rows({
      conform = {
        available = true,
        reason = nil,
        formatters = {},
        fallback = { display_global_mode = 'fallback' },
      },
      lsp_clients = {},
    }, { conform = 'C', lsp = 'L', file = 'F', filetype = 'lua' }, { unavailable = '!' })

    assert.are.same({
      id = 'conform_empty',
      text = '! C Conform: no formatters available',
      toggleable = false,
      kind = 'info',
      status = 'unavailable',
      status_icon = '!',
      source_icon = 'C',
    }, find_row(built, 'conform_empty'))

    assert.are.same({
      id = 'lsp_empty',
      text = '! L LSP: no attached clients',
      toggleable = false,
      kind = 'info',
      status = 'unavailable',
      status_icon = '!',
      source_icon = 'L',
    }, find_row(built, 'lsp_empty'))
  end)

  it('stores shared section metadata separately from section text', function()
    local rows = require('cosmic-ui.formatters.ui.rows')
    local built = rows.build_rows({
      conform = {
        available = true,
        reason = nil,
        formatters = {
          { name = 'stylua', enabled = true },
        },
        fallback = {
          display_global_mode = 'never',
          display_specific_mode = 'fallback',
        },
      },
      lsp_clients = {
        { name = 'lua_ls', available = true, enabled = true },
      },
    }, { conform = 'C', lsp = 'L', file = 'F', filetype = 'lua' }, {
      enabled = '+',
      disabled = '-',
      unavailable = '!',
    })

    assert.are.same({
      id = 'section_conform',
      text = 'Conform',
      toggleable = false,
      kind = 'section',
    }, find_row(built, 'section_conform'))

    assert.are.same({
      id = 'section_lsp',
      text = 'LSP',
      subtitle = 'fallback',
      toggleable = false,
      kind = 'section',
    }, find_row(built, 'section_lsp'))
  end)

  it('renders section subtitles and shared footer highlights through the formatter panel', function()
    local constants = require('cosmic-ui.formatters.constants')
    local highlights = require('cosmic-ui.formatters.ui.highlights')
    local input = require('cosmic-ui.formatters.ui.input')
    local render = require('cosmic-ui.formatters.ui.render')
    local ui_state = { ns = vim.api.nvim_create_namespace('cosmic-ui-formatters-spec') }

    local buf = vim.api.nvim_create_buf(false, true)
    local ui = {
      buf = buf,
      win = vim.api.nvim_get_current_win(),
      scope = 'buffer',
      target_bufnr = 0,
      selected = nil,
      rows = {},
      footer = input.footer_entries(),
    }
    local handlers = {
      status_fn = function()
        return {}
      end,
    }
    local deps = {
      logger = {},
      close_fn = function()
        error('render should not close the panel')
      end,
      ui_state = ui_state,
      constants = constants,
      highlights = highlights,
      rows = {
        get_devicons = function()
          return {}
        end,
        make_icons = function()
          return {
            file = 'F',
            filetype = 'lua',
          }
        end,
        build_rows = function()
          return {
            {
              id = 'section_lsp',
              kind = 'section',
              text = 'LSP',
              subtitle = 'fallback',
              toggleable = false,
            },
            {
              id = 'lsp_lua_ls',
              kind = 'item',
              text = '+ L lua_ls',
              toggleable = true,
              status = 'enabled',
              status_icon = '+',
              source_icon = 'L',
              action = {
                kind = 'item',
                source = 'lsp',
                name = 'lua_ls',
              },
            },
          }
        end,
      },
      window = {
        centered_float_config = function(width, height)
          return {
            row = 1,
            col = 1,
            width = width,
            height = height,
          }
        end,
        set_float_config = function() end,
      },
    }

    highlights.ensure(constants.highlight_links)
    render.render(ui, handlers, deps)

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local extmarks = collect_highlights(buf, ui_state.ns)
    local has_footer_key_hl = false
    local has_footer_text_hl = false
    local has_subtitle_hl = false

    assert.are.equal(' LSP  fallback', rstrip(lines[ui.rows[1].lnum]))
    assert.are.equal(' Enter:toggle  s:scope  r:reset  a:toggle all  f:format  q:close', rstrip(lines[ui.footer_lnum]))
    assert.are.same({
      highlight = 'CosmicUiPanelHintKey',
      start_col = 1,
      end_col = 6,
    }, ui.footer_spans[1])
    assert.are.same({
      highlight = 'CosmicUiPanelHintText',
      start_col = 7,
      end_col = 13,
    }, ui.footer_spans[2])

    for _, mark in ipairs(extmarks) do
      if mark.lnum == ui.footer_lnum - 1 and mark.hl_group == 'CosmicUiPanelHintKey' then
        has_footer_key_hl = true
      end
      if mark.lnum == ui.footer_lnum - 1 and mark.hl_group == 'CosmicUiPanelHintText' then
        has_footer_text_hl = true
      end
      if mark.lnum == ui.rows[1].lnum - 1 and mark.hl_group == 'CosmicUiFmtSubtitle' then
        has_subtitle_hl = true
      end
    end

    vim.api.nvim_buf_delete(buf, { force = true })

    assert.is_true(has_footer_key_hl)
    assert.is_true(has_footer_text_hl)
    assert.is_true(has_subtitle_hl)
  end)

  it('reuses the existing formatter highlight namespace during rerenders', function()
    local constants = require('cosmic-ui.formatters.constants')
    local render = require('cosmic-ui.formatters.ui.render')

    local buf = vim.api.nvim_create_buf(false, true)
    local ensure_calls = 0
    local seen_ns = {}
    local ui = {
      buf = buf,
      win = vim.api.nvim_get_current_win(),
      scope = 'buffer',
      target_bufnr = 0,
      selected = nil,
      rows = {},
      footer = {},
    }
    local handlers = {
      status_fn = function()
        return {}
      end,
    }
    local deps = {
      logger = {},
      close_fn = function()
        error('render should not close the panel')
      end,
      ui_state = { ns = 77 },
      constants = constants,
      highlights = {
        ensure = function()
          ensure_calls = ensure_calls + 1
          return 88
        end,
        apply = function(_, ns)
          table.insert(seen_ns, ns)
        end,
      },
      rows = {
        get_devicons = function()
          return {}
        end,
        make_icons = function()
          return {
            file = 'F',
            filetype = 'lua',
          }
        end,
        build_rows = function()
          return {}
        end,
      },
      window = {
        centered_float_config = function(width, height)
          return {
            row = 1,
            col = 1,
            width = width,
            height = height,
          }
        end,
        set_float_config = function() end,
      },
    }

    render.render(ui, handlers, deps)
    render.render(ui, handlers, deps)

    vim.api.nvim_buf_delete(buf, { force = true })

    assert.are.equal(0, ensure_calls)
    assert.are.same({ 77, 77 }, seen_ns)
  end)

  it('updates formatter selection from cached lines without rebuilding rows', function()
    local render = require('cosmic-ui.formatters.ui.render')

    local original_buf = vim.api.nvim_get_current_buf()
    local original_set_lines = vim.api.nvim_buf_set_lines
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_get_current_win()
    local apply_calls = 0
    local ui = {
      buf = buf,
      win = win,
      selected = 2,
      rows = {
        {
          kind = 'item',
          toggleable = true,
          lnum = 2,
        },
        {
          kind = 'item',
          toggleable = true,
          lnum = 3,
        },
      },
      rendered_lines = {
        'header',
        'first',
        'second',
      },
    }
    local deps = {
      ui_state = { ns = 123 },
      highlights = {
        apply = function(target_buf, ns, target_ui, lines)
          apply_calls = apply_calls + 1
          assert.are.equal(buf, target_buf)
          assert.are.equal(123, ns)
          assert.are.equal(ui, target_ui)
          assert.are.equal(ui.rendered_lines, lines)
        end,
      },
      rows = {
        get_devicons = function()
          error('selection update should not rediscover devicons')
        end,
        make_icons = function()
          error('selection update should not rebuild icons')
        end,
        build_rows = function()
          error('selection update should not rebuild rows')
        end,
      },
    }

    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, ui.rendered_lines)
    vim.api.nvim_buf_set_lines = function()
      error('selection update should not rewrite buffer lines')
    end

    local ok, err = pcall(function()
      render.update_selection(ui, deps)
    end)
    local cursor_after = vim.api.nvim_win_get_cursor(win)

    vim.api.nvim_buf_set_lines = original_set_lines
    vim.api.nvim_set_current_buf(original_buf)
    vim.api.nvim_buf_delete(buf, { force = true })

    assert.is_true(ok, err)
    assert.are.equal(1, apply_calls)
    assert.are.same({ ui.rows[2].lnum, 0 }, cursor_after)
  end)

  it('keeps every formatter row selectable when content exceeds the panel height', function()
    local constants = require('cosmic-ui.formatters.constants')
    local render = require('cosmic-ui.formatters.ui.render')

    local original_buf = vim.api.nvim_get_current_buf()
    local buf = vim.api.nvim_create_buf(false, true)
    local all_rows = {}
    for idx = 1, 40 do
      table.insert(all_rows, {
        id = 'formatter_' .. idx,
        kind = 'item',
        text = 'formatter ' .. idx,
        toggleable = true,
        status = 'enabled',
        status_icon = '+',
        source_icon = 'C',
        action = {
          kind = 'item',
          source = 'conform',
          name = 'formatter_' .. idx,
        },
      })
    end

    local ui = {
      buf = buf,
      win = vim.api.nvim_get_current_win(),
      scope = 'buffer',
      target_bufnr = buf,
      selected = 30,
      rows = {},
      footer = {},
    }
    local deps = {
      logger = {},
      close_fn = function()
        error('render should not close the panel')
      end,
      ui_state = { ns = 123 },
      constants = constants,
      highlights = {
        apply = function() end,
      },
      rows = {
        get_devicons = function()
          return {}
        end,
        make_icons = function()
          return {
            file = 'F',
            filetype = 'lua',
          }
        end,
        build_rows = function()
          return all_rows
        end,
      },
      window = {
        centered_float_config = function(width, height)
          return {
            row = 1,
            col = 1,
            width = width,
            height = height,
          }
        end,
        set_float_config = function() end,
      },
    }

    vim.api.nvim_set_current_buf(buf)
    render.render(ui, {
      status_fn = function()
        return {}
      end,
    }, deps)

    local window = require('cosmic-ui.window')
    local border = vim.o.winborder ~= '' and vim.o.winborder or nil
    local _, max_height = window.fit_float_size(1, vim.o.lines, {
      height_ratio = 0.8,
      border = border,
    })

    local cursor_after = vim.api.nvim_win_get_cursor(ui.win)

    vim.api.nvim_set_current_buf(original_buf)
    vim.api.nvim_buf_delete(buf, { force = true })

    assert.is_true(#ui.rendered_lines > max_height)
    assert.are.equal(#all_rows, #ui.rows)
    assert.are.equal(30, ui.selected)
    for _, line in ipairs(ui.rendered_lines) do
      assert.are_not.equal('...', rstrip(line))
    end
    assert.are.same({ ui.rows[30].lnum, 0 }, cursor_after)
  end)
end)
