-- Runtime ownership only: no permanent configuration include is required.
-- Key callbacks never read files or wait for subprocesses.
local M = { handles = {}, token = nil, issued_at = 0, plugin_id = "jessie.switchboard" }

local function alive(handle, kind)
  return handle ~= nil and tostring(handle) ~= "HL." .. kind .. "(expired)"
end

local function supported()
  return hl and o and hl.unbind and hl.bind and hl.timer and hl.is_key_down
    and hl.dsp and hl.dsp.global and hl.dsp.exec_cmd
end

function M:retire()
  for _, handle in ipairs(self.handles) do
    -- remove()/unbind() removes every binding on the chord in Hyprland 0.56.
    -- Disable our handles; configuration reload removes them safely.
    if alive(handle, "Keybind") then handle:set_enabled(false) end
  end
  if alive(self.timer, "Timer") then self.timer:set_enabled(false) end
  self.handles = {}
end

function M:release(token)
  if _G.switchboard_runtime ~= self or self.token ~= token then return false end
  self:retire()
  _G.switchboard_runtime = nil
  _G.switchboard_lease = nil
  -- Restore the user's current Lua configuration, including arbitrary callback
  -- bindings. The CLI cannot enumerate all binding options/handles to snapshot.
  hl.dispatch(hl.dsp.exec_cmd("hyprctl reload"))
  return true
end

function M:renew(token)
  if _G.switchboard_runtime ~= self or self.token ~= token then return false end
  for _, handle in ipairs(self.handles) do
    if not alive(handle, "Keybind") or not handle:is_enabled() then return false end
  end
  self.expires = os.time() + 8
  return #self.handles == 6
end

local function next_window(forward)
  return function()
    if not forward then hl.dispatch(hl.dsp.window.alter_zorder({ mode = "bottom" })) end
    hl.dispatch(hl.dsp.window.cycle_next({ next = forward }))
    if forward then hl.dispatch(hl.dsp.window.bring_to_top()) end
  end
end

function M:claim(token, issued_at, plugin_id)
  if not supported() then return false end
  local previous = _G.switchboard_runtime
  if previous and previous.issued_at > issued_at then return false end
  if previous == self and self.token == token and self:renew(token) then return true end
  if previous then previous:retire() end
  self.token, self.issued_at, self.plugin_id = token, issued_at, plugin_id
  self.expires = os.time() + 8
  _G.switchboard_runtime = self
  local function bind(keys, description, shortcut, fallback)
    hl.unbind(keys)
    self.handles[#self.handles + 1] = hl.bind(keys, function()
      if _G.switchboard_runtime == self and self.expires >= os.time() then
        hl.dispatch(hl.dsp.global(self.plugin_id .. ":" .. shortcut))
      elseif fallback then
        fallback()
      end
    end, { description = description, transparent = true })
  end
  local ok, err = pcall(function()
    bind("ALT + TAB", "Switchboard: next application", "window-forward", next_window(true))
    bind("ALT + SHIFT + TAB", "Switchboard: previous application", "window-backward", next_window(false))
    hl.unbind("ALT + grave")
    hl.unbind("ALT + SHIFT + grave")
    bind("ALT + code:49", "Switchboard: next application window", "app-windows-forward")
    bind("ALT + SHIFT + code:49", "Switchboard: previous application window", "app-windows-backward")
    bind("SUPER + TAB", "Switchboard: next workspace", "workspace-forward", function()
      hl.dispatch(hl.dsp.focus({ workspace = "m+1" }))
    end)
    bind("SUPER + SHIFT + TAB", "Switchboard: previous workspace", "workspace-backward", function()
      hl.dispatch(hl.dsp.focus({ workspace = "m-1" }))
    end)
    self.timer = hl.timer(function()
      if _G.switchboard_runtime == self and self.expires < os.time() then self:release(self.token) end
    end, { timeout = 1000, type = "repeat" })
  end)
  if not ok then
    self:release(token)
    print("Switchboard bindings: " .. tostring(err))
    return false
  end
  return true
end

return M
