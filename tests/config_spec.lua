describe('cosmic-ui config', function()
  local original_config
  local original_notify_once
  local config
  local warnings

  local function warned_for(path)
    local needle = ('`%s`'):format(path)
    for _, warning in ipairs(warnings) do
      if warning.message:find(needle, 1, true) then
        return true
      end
    end

    return false
  end

  before_each(function()
    original_config = package.loaded['cosmic-ui.config']
    original_notify_once = vim.notify_once
    warnings = {}

    vim.notify_once = function(message, level, opts)
      table.insert(warnings, {
        message = message,
        level = level,
        opts = opts,
      })
    end

    package.loaded['cosmic-ui.config'] = nil
    config = require('cosmic-ui.config')
  end)

  after_each(function()
    vim.notify_once = original_notify_once
    package.loaded['cosmic-ui.config'] = original_config
  end)

  it('warns and falls back for invalid documented setup values', function()
    config.setup({
      notify_title = 42,
      rename = {
        enabled = 'yes',
        prompt = 42,
        prompt_hl = {},
        border = 'rounded',
      },
      codeactions = {
        enabled = 1,
        min_width = 'wide',
        border = false,
      },
      formatters = {
        enabled = 'no',
      },
    })

    assert.are.equal('CosmicUI', config.get().notify_title)
    assert.are.same({
      border = {
        highlight = 'FloatBorder',
        title = 'Rename',
        title_align = 'left',
        title_hl = 'FloatBorder',
      },
      prompt = '> ',
      prompt_hl = 'Comment',
    }, config.module_opts('rename'))
    assert.is_nil(config.module_opts('codeactions').min_width)
    assert.are.same({
      bottom_hl = 'FloatBorder',
      highlight = 'FloatBorder',
      title = 'Code Actions',
      title_align = 'center',
      title_hl = 'FloatBorder',
    }, config.module_opts('codeactions').border)
    assert.are.same({}, config.module_opts('formatters'))
    assert.is_true(config.module_enabled('rename'))
    assert.is_true(config.module_enabled('codeactions'))
    assert.is_true(config.module_enabled('formatters'))

    for _, path in ipairs({
      'notify_title',
      'rename.enabled',
      'rename.prompt',
      'rename.prompt_hl',
      'rename.border',
      'codeactions.enabled',
      'codeactions.min_width',
      'codeactions.border',
      'formatters.enabled',
    }) do
      assert.is_true(warned_for(path), ('expected a warning for %s'):format(path))
    end
  end)

  it('sanitizes invalid nested border fields without discarding valid siblings', function()
    config.setup({
      rename = {
        border = {
          style = { 1 },
          title = 9,
          title_align = 'middle',
          highlight = false,
          title_hl = {},
        },
        prompt = 'rename: ',
      },
      codeactions = {
        border = {
          style = false,
          title = {},
          title_align = 'middle',
          highlight = 4,
          title_hl = false,
          bottom_hl = {},
        },
        min_width = 48,
      },
    })

    assert.are.equal('rename: ', config.module_opts('rename').prompt)
    assert.are.same({
      highlight = 'FloatBorder',
      title = 'Rename',
      title_align = 'left',
      title_hl = 'FloatBorder',
    }, config.module_opts('rename').border)
    assert.are.equal(48, config.module_opts('codeactions').min_width)
    assert.are.same({
      bottom_hl = 'FloatBorder',
      highlight = 'FloatBorder',
      title = 'Code Actions',
      title_align = 'center',
      title_hl = 'FloatBorder',
    }, config.module_opts('codeactions').border)

    for _, path in ipairs({
      'rename.border.style',
      'rename.border.title',
      'rename.border.title_align',
      'rename.border.highlight',
      'rename.border.title_hl',
      'codeactions.border.style',
      'codeactions.border.title',
      'codeactions.border.title_align',
      'codeactions.border.highlight',
      'codeactions.border.title_hl',
      'codeactions.border.bottom_hl',
    }) do
      assert.is_true(warned_for(path), ('expected a warning for %s'):format(path))
    end
  end)

  it('preserves valid documented setup values and module enable semantics', function()
    local border_style = {
      { '+', 'Corner' },
      '-',
      { '+', 'Corner' },
      '|',
    }

    config.setup({
      notify_title = 'Cosmic Test',
      rename = {
        enabled = false,
        prompt = 'rename> ',
        prompt_hl = 'Identifier',
        border = {
          style = border_style,
          title = 'Rename Symbol',
          title_align = 'right',
          highlight = 'NormalFloat',
          title_hl = 'Title',
        },
      },
      codeactions = {
        enabled = true,
        min_width = 48,
        border = {
          style = 'rounded',
          title = 'Actions',
          title_align = 'left',
          highlight = 'NormalFloat',
          title_hl = 'Title',
          bottom_hl = 'Comment',
        },
      },
      formatters = {
        enabled = false,
      },
    })

    assert.are.equal('Cosmic Test', config.get().notify_title)
    assert.are.equal('rename> ', config.module_opts('rename').prompt)
    assert.are.equal('Identifier', config.module_opts('rename').prompt_hl)
    assert.are.same(border_style, config.module_opts('rename').border.style)
    assert.are.equal('Rename Symbol', config.module_opts('rename').border.title)
    assert.are.equal('right', config.module_opts('rename').border.title_align)
    assert.are.equal(48, config.module_opts('codeactions').min_width)
    assert.are.equal('rounded', config.module_opts('codeactions').border.style)
    assert.are.equal('Comment', config.module_opts('codeactions').border.bottom_hl)
    assert.is_false(config.module_enabled('rename'))
    assert.is_true(config.module_enabled('codeactions'))
    assert.is_false(config.module_enabled('formatters'))
    assert.are.same({}, warnings)
  end)

  it('keeps unknown setup keys ignored with warnings', function()
    config.setup({
      legacy = true,
      rename = {
        unknown = 'value',
      },
    })

    assert.is_nil(config.get().legacy)
    assert.is_nil(config.module_opts('rename').unknown)
    assert.is_true(warned_for('legacy'))
    assert.is_true(warned_for('rename.unknown'))
  end)
end)
