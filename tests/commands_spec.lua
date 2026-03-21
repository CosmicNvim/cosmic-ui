describe('cosmic-ui commands', function()
  it('registers optional Cosmic commands', function()
    vim.cmd('runtime plugin/cosmic-ui.lua')

    local commands = vim.api.nvim_get_commands({})

    assert.is_truthy(commands.CosmicRename)
    assert.is_truthy(commands.CosmicCodeActions)
    assert.is_truthy(commands.CosmicFormatters)
    assert.is_truthy(commands.CosmicFormat)
  end)
end)
