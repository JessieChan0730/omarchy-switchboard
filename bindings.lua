-- Loaded by the installer-managed include in the user's bindings.lua.
-- No file IO or subprocess waits occur in compositor key callbacks.
local M = { plugin_id = "jessie.switchboard", ready = false }
if not (hl and o and hl.is_key_down and hl.dsp and hl.dsp.global) then return M end

local function ready()
  local lease = _G.switchboard_lease
  return lease and type(lease.expires) == "number" and lease.expires >= os.time()
end

local function bind(keys, description, shortcut, fallback)
  o.rebind(keys, description, function()
    if ready() then
      hl.dispatch(hl.dsp.global(M.plugin_id .. ":" .. shortcut))
    elseif fallback then
      fallback()
    end
  end, { transparent = true })
end

local function next_window(forward)
  return function()
    if not forward then hl.dispatch(hl.dsp.window.alter_zorder({ mode = "bottom" })) end
    hl.dispatch(hl.dsp.window.cycle_next({ next = forward }))
    if forward then hl.dispatch(hl.dsp.window.bring_to_top()) end
  end
end

bind("ALT + TAB", "Switchboard: next window", "window-forward", next_window(true))
bind("ALT + SHIFT + TAB", "Switchboard: previous window", "window-backward", next_window(false))
bind("SUPER + TAB", "Switchboard: next workspace", "workspace-forward", function()
  hl.dispatch(hl.dsp.focus({ workspace = "m+1" }))
end)
bind("SUPER + SHIFT + TAB", "Switchboard: previous workspace", "workspace-backward", function()
  hl.dispatch(hl.dsp.focus({ workspace = "m-1" }))
end)
bind("ALT + grave", "Switchboard: previous window toggle", "previous-window", next_window(false))
bind("SUPER + grave", "Switchboard: previous workspace toggle", "previous-workspace", function()
  hl.dispatch(hl.dsp.workspace.toggle_special("qconsole"))
end)
-- SUPER+SHIFT+grave and SUPER+CTRL+TAB keep their existing bindings.
M.ready = true
return M
