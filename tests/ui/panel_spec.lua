describe("cosmic-ui.ui.panel", function()
  it("builds a standard empty state row", function()
    local states = require("cosmic-ui.ui.states")
    local row = states.empty("No code actions found")
    assert.are.equal("empty", row.state)
    assert.are.equal("No code actions found", row.text)
  end)

  it("normalizes header, footer hints, and state rows into a stable panel model", function()
    local panel = require("cosmic-ui.ui.panel")
    local model = panel.build({
      title = "Code Actions",
      subtitle = "lua • 3 actions",
      footer = { "Enter:apply", "Esc:close" },
      rows = { { kind = "state", state = "empty", text = "No code actions found" } },
    })

    assert.are.equal("Code Actions", model.title)
    assert.are.equal("lua • 3 actions", model.subtitle)
    assert.are.same({
      { key = "Enter", text = "apply" },
      { key = "Esc", text = "close" },
    }, model.footer)
    assert.are.same({
      kind = "state",
      state = "empty",
      text = "No code actions found",
      highlight = "CosmicUiPanelStateInfo",
    }, model.rows[1])
    assert.is_nil(model.selected)
  end)

  it("fills in stable defaults for missing panel metadata", function()
    local panel = require("cosmic-ui.ui.panel")
    local model = panel.build({})

    assert.are.equal("", model.title)
    assert.are.equal("", model.subtitle)
    assert.are.same({}, model.footer)
    assert.are.same({}, model.rows)
    assert.is_nil(model.selected)
  end)

  it("prepares a panel by ensuring shared highlights before returning the model", function()
    local highlights = require("cosmic-ui.ui.highlights")
    local panel = require("cosmic-ui.ui.panel")
    local spy = require("luassert.spy")
    local ensure = spy.on(highlights, "ensure")

    local model = panel.prepare({
      footer = { "Enter:apply" },
      rows = { { kind = "state", state = "error", text = "Request failed" } },
    })

    assert.spy(ensure).was.called(1)
    assert.are.same({ key = "Enter", text = "apply" }, model.footer[1])
    assert.are.equal("CosmicUiPanelStateError", model.rows[1].highlight)
    ensure:revert()
  end)
end)
