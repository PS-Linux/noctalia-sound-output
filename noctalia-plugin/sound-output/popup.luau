--!nonstrict
-- Popup above the bar icon: one row per output, click one to switch to it.

local C = require("./common.luau")

local function outputRow(sink, selected)
  return ui.row({
    key = sink.name,
    gap = 10,
    align = "center",
    padding = 8,
    radius = 8,
    fill = selected and "primary/0.10" or "surface_container",
    opacity = sink.available and 1 or 0.5,
    onClick = function()
      if not selected then
        C.select(sink.name)
      end
      panel.close()
    end,
  }, {
    ui.glyph({ name = sink.icon, size = 20, color = selected and "primary" or "on_surface_variant" }),
    ui.column({ gap = 1, flexGrow = 1 }, {
      ui.label({ text = sink.label, fontWeight = "medium", maxLines = 1 }),
      ui.label({
        text = sink.detail .. (sink.available and "" or " · unplugged"),
        fontSize = 11,
        color = selected and "primary" or "on_surface_variant",
        maxLines = 1,
      }),
    }),
    ui.glyph({ name = "check", size = 18, color = "primary", visible = selected }),
  })
end

local function render()
  local sound = noctalia.state.get("sound")
  local rows = {}

  table.insert(rows, ui.row({ gap = 8, align = "center", paddingH = 4 }, {
    ui.glyph({ name = C.volumeGlyph(sound), size = 16, color = "primary" }),
    ui.label({ text = "Sound output", fontWeight = "semibold", flexGrow = 1 }),
    ui.label({
      text = sound and (sound.muted and "Muted" or (tostring(sound.volume) .. "%")) or "",
      fontSize = 12,
      color = "on_surface_variant",
    }),
    ui.button({
      glyph = sound and sound.muted and "volume-off" or "volume",
      variant = "ghost",
      controlSize = "sm",
      tooltip = sound and sound.muted and "Unmute" or "Mute",
      selected = sound ~= nil and sound.muted,
      onClick = C.toggleMute,
    }),
  }))

  if sound == nil then
    table.insert(rows, ui.label({ text = "Loading…", color = "on_surface_variant" }))
  elseif #sound.sinks == 0 then
    table.insert(rows, ui.label({ text = "No sound outputs found.", color = "on_surface_variant" }))
  else
    for _, sink in ipairs(sound.sinks) do
      table.insert(rows, outputRow(sink, sink.name == sound.default))
    end
  end

  table.insert(rows, ui.label({
    text = "Scroll the icon for volume · click it for app volumes",
    fontSize = 10,
    color = "on_surface_variant",
    textAlign = "center",
  }))

  panel.render(ui.column({ gap = 6, padding = 10 }, rows))
end

noctalia.state.watch("sound", render)

function onOpen()
  noctalia.state.set("popupOpen", true)
  render()
  C.refresh()
end

function onClose()
  noctalia.state.set("popupOpen", false)
  noctalia.state.set("popupClosedAt", noctalia.nowMs())
end
