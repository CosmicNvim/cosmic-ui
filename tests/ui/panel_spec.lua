describe('cosmic-ui.ui.panel', function()
  it('keeps hotkey helper text readable in shared panels', function()
    local constants = require('cosmic-ui.ui.constants')

    assert.are.equal('Special', constants.highlight_links.CosmicUiPanelHintKey)
    assert.are.equal('NormalFloat', constants.highlight_links.CosmicUiPanelHintText)
  end)

  it('builds a standard empty state row', function()
    local states = require('cosmic-ui.ui.states')
    local row = states.empty('No code actions found')
    assert.are.equal('empty', row.state)
    assert.are.equal('No code actions found', row.text)
  end)

  it('normalizes header, footer hints, and state rows into a stable panel model', function()
    local panel = require('cosmic-ui.ui.panel')
    local model = panel.build({
      title = 'Code Actions',
      subtitle = 'lua • 3 actions',
      footer = { 'Enter:apply', 'Esc:close' },
      rows = { { kind = 'state', state = 'empty', text = 'No code actions found' } },
    })

    assert.are.equal('Code Actions', model.title)
    assert.are.equal('lua • 3 actions', model.subtitle)
    assert.are.equal('CosmicUiPanelTitle', model.title_highlight)
    assert.are.equal('CosmicUiPanelSubtitle', model.subtitle_highlight)
    assert.are.same({
      {
        key = 'Enter',
        text = 'apply',
        key_highlight = 'CosmicUiPanelHintKey',
        text_highlight = 'CosmicUiPanelHintText',
      },
      {
        key = 'Esc',
        text = 'close',
        key_highlight = 'CosmicUiPanelHintKey',
        text_highlight = 'CosmicUiPanelHintText',
      },
    }, model.footer)
    assert.are.same({
      kind = 'state',
      state = 'empty',
      text = 'No code actions found',
      highlight = 'CosmicUiPanelStateInfo',
    }, model.rows[1])
    assert.is_nil(model.selected)
  end)

  it('fills in stable defaults for missing panel metadata', function()
    local panel = require('cosmic-ui.ui.panel')
    local model = panel.build({})

    assert.are.equal('', model.title)
    assert.are.equal('', model.subtitle)
    assert.are.equal('CosmicUiPanelTitle', model.title_highlight)
    assert.are.equal('CosmicUiPanelSubtitle', model.subtitle_highlight)
    assert.are.same({}, model.footer)
    assert.are.same({}, model.rows)
    assert.is_nil(model.selected)
  end)

  it('defaults panel layout to standard and preserves compact when requested', function()
    local panel = require('cosmic-ui.ui.panel')

    assert.are.equal('standard', panel.build({}).layout)
    assert.are.equal('compact', panel.build({ layout = 'compact' }).layout)
  end)

  it('prepares a panel by ensuring shared highlight links before returning the model', function()
    local constants = require('cosmic-ui.ui.constants')
    local panel = require('cosmic-ui.ui.panel')

    local model = panel.prepare({
      footer = { 'Enter:apply' },
      rows = { { kind = 'state', state = 'error', text = 'Request failed' } },
    })

    assert.are.same({
      key = 'Enter',
      text = 'apply',
      key_highlight = 'CosmicUiPanelHintKey',
      text_highlight = 'CosmicUiPanelHintText',
    }, model.footer[1])
    assert.are.equal('CosmicUiPanelStateError', model.rows[1].highlight)

    for group, link in pairs(constants.highlight_links) do
      local hl = vim.api.nvim_get_hl(0, { name = group, link = true })
      assert.are.equal(link, hl.link)
    end
  end)

  it('renders normalized footer entries into stable text and highlight spans', function()
    local panel = require('cosmic-ui.ui.panel')
    local footer = panel.build({
      footer = {
        'Enter:apply',
        {
          key = 'Esc',
          text = 'close',
          key_highlight = 'Special',
          text_highlight = 'NormalFloat',
        },
      },
    }).footer

    local text, spans = panel.render_footer(footer)

    assert.are.equal('Enter:apply  Esc:close', text)
    assert.are.same({
      {
        highlight = 'CosmicUiPanelHintKey',
        start_col = 0,
        end_col = 5,
      },
      {
        highlight = 'CosmicUiPanelHintText',
        start_col = 6,
        end_col = 11,
      },
      {
        highlight = 'Special',
        start_col = 13,
        end_col = 16,
      },
      {
        highlight = 'NormalFloat',
        start_col = 17,
        end_col = 22,
      },
    }, spans)
  end)

  it('prepares standard panel render output for sections, actions, states, and footer rows', function()
    local panel = require('cosmic-ui.ui.panel')
    local model = panel.build({
      footer = {
        'Enter:apply',
        'Esc:close',
      },
      rows = {
        { kind = 'state', state = 'warn', text = '1 source failed to return code actions' },
        { kind = 'section', text = 'alpha' },
        { kind = 'action', text = 'Fix A' },
        { kind = 'separator', text = 'beta' },
        { kind = 'action', text = 'Fix B' },
      },
    })

    local prepared = panel.prepare_standard(model, { min_width = 30 })

    assert.are.equal(40, prepared.width)
    assert.are.equal(8, prepared.height)
    assert.are.same({
      ' 1 source failed to return code actions ',
      '                 alpha                  ',
      ' Fix A ',
      '',
      '                  beta                  ',
      ' Fix B ',
      '',
      ' Enter:apply  Esc:close ',
    }, prepared.lines)
    assert.are.same({
      [1] = { highlight = 'CosmicUiPanelStateWarn' },
      [2] = { highlight = 'CosmicUiPanelSection' },
      [5] = { highlight = 'CosmicUiPanelSection' },
      [8] = {
        spans = {
          {
            highlight = 'CosmicUiPanelHintKey',
            start_col = 1,
            end_col = 6,
          },
          {
            highlight = 'CosmicUiPanelHintText',
            start_col = 7,
            end_col = 12,
          },
          {
            highlight = 'CosmicUiPanelHintKey',
            start_col = 14,
            end_col = 17,
          },
          {
            highlight = 'CosmicUiPanelHintText',
            start_col = 18,
            end_col = 23,
          },
        },
      },
    }, prepared.highlights)
    assert.are.same({
      [1] = 3,
      [2] = 6,
    }, prepared.action_line_by_idx)
  end)

  it('restores focus through the panel-facing helper', function()
    local panel = require('cosmic-ui.ui.panel')
    local first = vim.api.nvim_get_current_win()
    vim.cmd('split')
    local second = vim.api.nvim_get_current_win()

    assert.are_not.equal(first, second)

    panel.restore_focus(first)
    assert.are.equal(first, vim.api.nvim_get_current_win())

    vim.api.nvim_win_close(second, true)
  end)
end)
