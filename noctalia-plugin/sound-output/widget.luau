--!nonstrict
-- Bar icon: volume glyph and percentage. Hover opens the output popup above
-- it; click opens Noctalia's audio panel. Scroll and right click are bound in
-- plugin.toml. The popup reports its own hover state ("popupHovered"), and the
-- popup closes once neither the icon nor the popup has been hovered for
-- CLOSE_GRACE_MS.

local C = require("./common.luau")

local CLOSE_GRACE_MS = 350
-- Opening another panel makes the pointer leave and re-enter the icon; hover
-- is ignored this long after a click so the popup doesn't open over it.
local CLICK_QUIET_MS = 800
local POLL_MS = 10000
local DEBOUNCE_MS = 120

local hoverIcon, hoverPopup, popupOpen = false, false, false
local closeAt = nil
local refreshAt = nil
local suppressUntilLeave = false
local quietUntil = 0
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

local function openPopup()
  if not popupOpen then
    popupOpen = true
    noctalia.togglePanel(C.POPUP)
  end
end

local function closePopup()
  if popupOpen then
    popupOpen = false
    noctalia.togglePanel(C.POPUP)
  end
end

local function wake(at)
  noctalia.setUpdateInterval(math.max(16, at - noctalia.nowMs()))
end

local function scheduleClose()
  closeAt = noctalia.nowMs() + CLOSE_GRACE_MS
  wake(closeAt)
end

noctalia.state.watch("sound", render)
noctalia.state.watch("popupOpen", function(open)
  popupOpen = open == true
end)
noctalia.state.watch("popupHovered", function(hovered)
  hoverPopup = hovered == true
  if hoverPopup then
    closeAt = nil
  else
    scheduleClose()
  end
end)

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
  if closeAt and now >= closeAt then
    closeAt = nil
    if not hoverIcon and not hoverPopup then
      closePopup()
    end
  end
  if refreshAt and now >= refreshAt then
    refreshAt = nil
    lastPoll = now
    C.refresh()
  elseif now - lastPoll >= POLL_MS then
    lastPoll = now
    C.refresh()
  end
  local nextAt = lastPoll + POLL_MS
  if closeAt then
    nextAt = math.min(nextAt, closeAt)
  end
  if refreshAt then
    nextAt = math.min(nextAt, refreshAt)
  end
  wake(nextAt)
  render()
end

function onHover(entered)
  local quiet = noctalia.nowMs() < quietUntil
  hoverIcon = entered
  if entered then
    closeAt = nil
    if not suppressUntilLeave and not quiet then
      openPopup()
    end
  else
    if not quiet then
      suppressUntilLeave = false
    end
    scheduleClose()
  end
end

function onClick()
  suppressUntilLeave = true
  quietUntil = noctalia.nowMs() + CLICK_QUIET_MS
  closeAt = nil
  closePopup()
  noctalia.runAsync({ "noctalia", "msg", "panel-toggle", "control-center", "audio" })
end
