describe("cosmic-ui.ui.panel", function()
  it("builds a standard empty state row", function()
    local states = require("cosmic-ui.ui.states")
    local row = states.empty("No code actions found")
    assert.are.equal("empty", row.state)
    assert.are.equal("No code actions found", row.text)
  end)

  it("normalizes panel metadata for title, subtitle, and footer hints", function()
    local panel = require("cosmic-ui.ui.panel")
    local model = panel.build({
      title = "Code Actions",
      subtitle = "lua • 3 actions",
      footer = { "Enter:apply", "Esc:close" },
      rows = { { kind = "state", state = "empty", text = "No code actions found" } },
    })

    assert.are.equal("Code Actions", model.title)
    assert.are.equal("lua • 3 actions", model.subtitle)
    assert.are.same({ "Enter:apply", "Esc:close" }, model.footer)
  end)
end)
