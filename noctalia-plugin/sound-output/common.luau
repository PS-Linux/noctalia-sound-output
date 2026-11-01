--!nonstrict
-- Shared helpers: talks to the sound-output script and keeps the result in
-- plugin state ("sound") so the widget and the popup stay in sync.

local M = {}

M.SCRIPT = noctalia.expandPath("~/.local/bin/sound-output")
M.POPUP = "ps/sound-output:popup"

function M.run(args, onDone)
  local argv = { M.SCRIPT }
  for _, a in ipairs(args) do
    table.insert(argv, a)
  end
  noctalia.runAsync(argv, function(result)
    if result.exitCode ~= 0 and result.stderr ~= "" then
      noctalia.notifyError("Sound output", result.stderr)
    end
    if onDone then
      onDone(result)
    end
  end, 10000)
end

function M.refresh()
  M.run({ "status" }, function(result)
    local sound = noctalia.json.decode(result.stdout or "")
    if type(sound) == "table" then
      noctalia.state.set("sound", sound)
    end
  end)
end

-- Switch output; shows the new one as selected until the script reports back.
function M.select(name)
  local sound = noctalia.state.get("sound")
  if sound then
    sound.default = name
    noctalia.state.set("sound", sound)
  end
  M.run({ "set", name }, function()
    M.refresh()
  end)
end

function M.toggleMute()
  M.run({ "mute" }, function()
    M.refresh()
  end)
end

function M.volumeGlyph(sound)
  if sound == nil then
    return "volume"
  elseif sound.muted then
    return "volume-off"
  elseif sound.volume == 0 then
    return "volume-3"
  elseif sound.volume < 50 then
    return "volume-2"
  end
  return "volume"
end

function M.current(sound)
  for _, sink in ipairs(sound and sound.sinks or {}) do
    if sink.name == sound.default then
      return sink
    end
  end
  return nil
end

return M
