--!nonstrict
-- Bar icon: volume glyph and percentage. Right click opens the output popup
-- above it. Left click and scroll are bound in plugin.toml.

local C = require("./common.luau")

-- Clicking the icon while the popup is open also counts as an outside click,
-- which may close it just before onRightClick runs. Don't reopen it then.
local REOPEN_GUARD_MS = 250
local POLL_MS = 10000
local DEBOUNCE_MS = 120

local refreshAt = nil
local lastPoll = 0

local function render()
  local sound = noctalia.state.get("sound")
  barWidget.setGlyph(C.volumeGlyph(sound))
  barWidget.setText(sound and (tostring(sound.volume) .. "%") or "")
  local sink = C.current(sound)
  if sink then
    barWidget.setTooltip(sink.label .. (sound.muted and " · muted" or ""))
  end
end

local function wake(at)
  noctalia.setUpdateInterval(math.max(16, at - noctalia.nowMs()))
end

noctalia.state.watch("sound", render)

-- Live updates: refresh shortly after any output or default-output change
-- (several events arrive together, so they're batched).
noctalia.runStream("pactl subscribe", function(line)
  if string.find(line, "on sink #", 1, true) or string.find(line, "on server", 1, true) then
    refreshAt = refreshAt or (noctalia.nowMs() + DEBOUNCE_MS)
    wake(refreshAt)
  end
end)

function update()
  local now = noctalia.nowMs()
  if refreshAt and now >= refreshAt then
    refreshAt = nil
    lastPoll = now
    C.refresh()
  elseif now - lastPoll >= POLL_MS then
    lastPoll = now
    C.refresh()
  end
  wake(refreshAt or (lastPoll + POLL_MS))
  render()
end

function onRightClick()
  local closedAt = noctalia.state.get("popupClosedAt") or 0
  if noctalia.state.get("popupOpen") == true or noctalia.nowMs() - closedAt >= REOPEN_GUARD_MS then
    noctalia.togglePanel(C.POPUP)
  end
end
