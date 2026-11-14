-- Execute the real binding file without a desktop, checking ownership and dispatch.
local registry, sent = {}, {}
local function action(kind)
  return function(payload) return { kind = kind, payload = payload } end
end
hl = {
  is_key_down = function() return false end,
  dispatch = function(target) sent[#sent + 1] = target end,
  dsp = {
    global = action("global"),
    focus = action("focus"),
    window = {
      alter_zorder = action("zorder"),
      cycle_next = action("cycle"),
      bring_to_top = action("top"),
    },
  },
}
o = {}
function o.bind(keys, description, callback, options)
  registry[keys] = { description = description, callback = callback, options = options }
end
function o.rebind(keys, description, callback, options)
  registry[keys] = nil
  o.bind(keys, description, callback, options)
end

local tab = {
  { key = "ALT + TAB", shortcut = "window-forward", fallback = { "cycle", "top" } },
  { key = "ALT + SHIFT + TAB", shortcut = "window-backward", fallback = { "zorder", "cycle" } },
  { key = "SUPER + TAB", shortcut = "workspace-forward", fallback = { "focus" } },
  { key = "SUPER + SHIFT + TAB", shortcut = "workspace-backward", fallback = { "focus" } },
  { key = "ALT + grave", shortcut = "app-windows-forward", fallback = {} },
  { key = "ALT + SHIFT + grave", shortcut = "app-windows-backward", fallback = {} },
}
local untouched = { "SUPER + grave", "SUPER + SHIFT + grave", "SUPER + CTRL + TAB" }
for _, entry in ipairs(tab) do o.bind(entry.key, "Original " .. entry.key, function() end) end
for _, key in ipairs(untouched) do o.bind(key, "Original " .. key, function() end) end
if arg[3] then dofile(arg[3]) end
local originals = {}
for _, key in ipairs(untouched) do originals[key] = registry[key].description end
if arg[2] == "unavailable" then hl.is_key_down = nil end
dofile(arg[1])

local count = 0
for _, binding in pairs(registry) do
  if binding.description and binding.description:match("^Switchboard:") then count = count + 1 end
end
local expected = arg[2] == "legacy" and 7 or (arg[2] == "none" or arg[2] == "unavailable") and 0 or 6
assert(count == expected, "Unexpected number of plugin bindings: " .. count)
if arg[2] == "legacy" then return end
for _, key in ipairs(untouched) do
  assert(registry[key].description == originals[key], "Changed unrelated binding: " .. key)
end
if expected == 0 then return end

for _, entry in ipairs(tab) do
  local binding = assert(registry[entry.key])
  assert(binding.options.transparent, "Panel must receive the global Tab path")
  _G.switchboard_lease = { expires = os.time() + 6 }
  sent = {}
  binding.callback()
  assert(#sent == 1 and sent[1].kind == "global", "A Tab must dispatch exactly one global shortcut")
  assert(sent[1].payload == "jessie.switchboard:" .. entry.shortcut)
  for _, lease in ipairs({ false, { expires = os.time() - 1 } }) do
    _G.switchboard_lease = lease or nil
    sent = {}
    binding.callback()
    assert(#sent == #entry.fallback, "Unexpected fallback action count")
    for index, kind in ipairs(entry.fallback) do assert(sent[index].kind == kind) end
    if entry.shortcut == "workspace-forward" then assert(sent[1].payload.workspace == "m+1") end
    if entry.shortcut == "workspace-backward" then assert(sent[1].payload.workspace == "m-1") end
    if entry.shortcut == "window-forward" then assert(sent[1].payload.next == true) end
    if entry.shortcut == "window-backward" then
      assert(sent[1].payload.mode == "bottom" and sent[2].payload.next == false)
    end
  end
end
