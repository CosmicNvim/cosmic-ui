describe('cosmic-ui.ui.panel', function()
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
