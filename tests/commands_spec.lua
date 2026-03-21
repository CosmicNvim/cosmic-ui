describe('cosmic-ui commands', function()
  local original_cosmic
  local original_global
  local command_names = {
    'CosmicRename',
    'CosmicCodeActions',
    'CosmicFormatters',
    'CosmicFormat',
  }

  local function delete_commands()
    for _, name in ipairs(command_names) do
      pcall(vim.api.nvim_del_user_command, name)
    end
  end

  before_each(function()
    original_cosmic = package.loaded['cosmic-ui']
    original_global = rawget(_G, 'CosmicUI')

    delete_commands()
    package.loaded['cosmic-ui'] = nil
    _G.CosmicUI = nil
    vim.g.loaded_cosmic_ui = nil
  end)

  after_each(function()
    delete_commands()
    package.loaded['cosmic-ui'] = original_cosmic
    _G.CosmicUI = original_global
    vim.g.loaded_cosmic_ui = nil
  end)

  it('registers optional Cosmic commands only after plugin load and dispatches to the matching wrappers', function()
    local before = vim.api.nvim_get_commands({})

    assert.is_nil(before.CosmicRename)
    assert.is_nil(before.CosmicCodeActions)
    assert.is_nil(before.CosmicFormatters)
    assert.is_nil(before.CosmicFormat)

    local calls = {
      rename = 0,
      codeactions = 0,
      formatters = 0,
      format = 0,
    }

    package.loaded['cosmic-ui'] = {
      rename = {
        open = function()
          calls.rename = calls.rename + 1
        end,
      },
      codeactions = {
        open = function()
          calls.codeactions = calls.codeactions + 1
        end,
      },
      formatters = {
        open = function()
          calls.formatters = calls.formatters + 1
        end,
        format = function()
          calls.format = calls.format + 1
        end,
      },
    }

    vim.cmd('runtime plugin/cosmic-ui.lua')

    local after = vim.api.nvim_get_commands({})

    assert.is_truthy(after.CosmicRename)
    assert.is_truthy(after.CosmicCodeActions)
    assert.is_truthy(after.CosmicFormatters)
    assert.is_truthy(after.CosmicFormat)

    assert.matches('Open the Cosmic rename prompt', vim.fn.execute('command CosmicRename'), 1, true)
    assert.matches('Open the Cosmic code action panel', vim.fn.execute('command CosmicCodeActions'), 1, true)
    assert.matches('Open the Cosmic formatter panel', vim.fn.execute('command CosmicFormatters'), 1, true)
    assert.matches(
      'Format the current buffer with Cosmic formatter routing',
      vim.fn.execute('command CosmicFormat'),
      1,
      true
    )

    vim.cmd('CosmicRename')
    vim.cmd('CosmicCodeActions')
    vim.cmd('CosmicFormatters')
    vim.cmd('CosmicFormat')

    assert.are.same({
      rename = 1,
      codeactions = 1,
      formatters = 1,
      format = 1,
    }, calls)
  end)
end)
