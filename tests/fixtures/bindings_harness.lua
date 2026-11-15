-- Run the real runtime owner against binding handles with Hyprland's expiry
-- semantics, including reload, competing owners and watchdog restoration.
local registry, sent, timers = {}, {}, {}
local function action(kind)
  return function(payload) return { kind = kind, payload = payload } end
end
local function handle(kind)
  local h = { enabled = true, expired = false }
  setmetatable(h, { __tostring = function(self) return self.expired and "HL." .. kind .. "(expired)" or "HL." .. kind .. "(live)" end })
  function h:set_enabled(value) assert(not self.expired, "Dereferenced expired handle"); self.enabled = value end
  function h:is_enabled() assert(not self.expired, "Dereferenced expired handle"); return self.enabled end
  return h
end
hl = {
  unbind = function(keys)
    if registry[keys] then registry[keys].expired = true end
    registry[keys] = nil
  end,
  bind = function(keys, callback, options)
    local h = handle("Keybind")
    h.callback, h.options, h.description = callback, options, options.description
    registry[keys] = h
    return h
  end,
  timer = function(callback, options)
    assert(options.type == "repeat" and options.timeout == 1000)
    local h = handle("Timer"); h.callback = callback; timers[#timers + 1] = h; return h
  end,
  is_key_down = function() return false end,
  dispatch = function(target) sent[#sent + 1] = target end,
  dsp = {
    global = action("global"), exec_cmd = action("exec"), focus = action("focus"),
    window = { alter_zorder = action("zorder"), cycle_next = action("cycle"), bring_to_top = action("top") },
  },
}
o = {}
local tab = {
  { key = "ALT + TAB", shortcut = "window-forward", fallback = { "cycle", "top" } },
  { key = "ALT + SHIFT + TAB", shortcut = "window-backward", fallback = { "zorder", "cycle" } },
  { key = "SUPER + TAB", shortcut = "workspace-forward", fallback = { "focus" } },
  { key = "SUPER + SHIFT + TAB", shortcut = "workspace-backward", fallback = { "focus" } },
  { key = "ALT + code:49", shortcut = "app-windows-forward", fallback = {} },
  { key = "ALT + SHIFT + code:49", shortcut = "app-windows-backward", fallback = {} },
}
local untouched = { "SUPER + grave", "SUPER + SHIFT + grave", "SUPER + CTRL + TAB" }
for _, key in ipairs(untouched) do hl.bind(key, function() end, { description = "User " .. key }) end
for _, entry in ipairs(tab) do hl.bind(entry.key, function() end, { description = "Original " .. entry.key }) end
hl.bind("ALT + grave", function() end, { description = "User grave" })
hl.bind("ALT + SHIFT + grave", function() end, { description = "User shifted grave" })
local original = {}
for _, key in ipairs(untouched) do original[key] = registry[key] end
local owner = dofile(arg[1])
if arg[2] == "unavailable" then
  hl.timer = nil
  assert(not owner:claim("first", 1, "jessie.switchboard"))
  assert(registry[tab[1].key].description:match("^Original"))
  return
end
assert(owner:claim("first", 1, "jessie.switchboard"))
assert(owner:claim("first", 1, "jessie.switchboard"))
assert(#timers == 1, "A repeated claim must not duplicate timers/bindings")
for _, key in ipairs(untouched) do assert(registry[key] == original[key], "Changed an unrelated user binding") end
assert(not registry["ALT + grave"] and not registry["ALT + SHIFT + grave"])
for _, entry in ipairs(tab) do
  local binding = assert(registry[entry.key])
  assert(binding.options.transparent)
  sent = {}; binding.callback()
  assert(#sent == 1 and sent[1].kind == "global")
  assert(sent[1].payload == "jessie.switchboard:" .. entry.shortcut)
  owner.expires = os.time() - 1
  sent = {}; binding.callback()
  assert(#sent == #entry.fallback)
  for i, kind in ipairs(entry.fallback) do assert(sent[i].kind == kind) end
  owner.expires = os.time() + 8
end
local successor = dofile(arg[1])
assert(successor:claim("second", 2, "jessie.switchboard"))
assert(not owner:release("first"), "Old destruction must not release a successor")
assert(not owner:renew("first"))
assert(not owner:claim("first", 1, "jessie.switchboard"), "Delayed old claims must not steal ownership")
assert(not timers[1].enabled)
assert(successor:renew("second"))
-- A user's rebind expires a handle. Renew must not dereference it, and a
-- subsequent claim must reinstall exactly six active bindings.
hl.unbind(tab[1].key)
assert(not successor:renew("second"))
assert(successor:claim("second", 2, "jessie.switchboard"))
local live = 0
for _, t in ipairs(timers) do if t.enabled then live = live + 1 end end
assert(live == 1)
successor.expires = os.time() - 1
sent = {}; successor.timer.callback()
assert(_G.switchboard_runtime == nil)
assert(#sent == 1 and sent[1].kind == "exec" and sent[1].payload == "hyprctl reload", "Expired lease must restore the user's configuration")
assert(not successor:release("second"), "Repeated cleanup must not reload twice")
for _, entry in ipairs(tab) do assert(not registry[entry.key].enabled) end
-- Config reload discards all runtime state; the same QML owner can claim again.
for _, b in pairs(registry) do b.expired = true end
for _, t in ipairs(timers) do t.expired = true end
registry = {}
assert(dofile(arg[1]):claim("third", 3, "jessie.switchboard"))
