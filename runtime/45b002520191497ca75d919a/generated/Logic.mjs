var __defProp = Object.defineProperty;
var __defProps = Object.defineProperties;
var __getOwnPropDescs = Object.getOwnPropertyDescriptors;
var __getOwnPropSymbols = Object.getOwnPropertySymbols;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __propIsEnum = Object.prototype.propertyIsEnumerable;
var __defNormalProp = (obj, key, value) => key in obj ? __defProp(obj, key, { enumerable: true, configurable: true, writable: true, value }) : obj[key] = value;
var __spreadValues = (a, b) => {
  for (var prop in b || (b = {}))
    if (__hasOwnProp.call(b, prop))
      __defNormalProp(a, prop, b[prop]);
  if (__getOwnPropSymbols)
    for (var prop of __getOwnPropSymbols(b)) {
      if (__propIsEnum.call(b, prop))
        __defNormalProp(a, prop, b[prop]);
    }
  return a;
};
var __spreadProps = (a, b) => __defProps(a, __getOwnPropDescs(b));

// src/logic/SwitcherLogic.ts
function wrapIndex(index, delta, count) {
  if (!Number.isInteger(count) || count < 0) {
    throw new RangeError("Candidate count must be a non-negative integer");
  }
  if (count === 0) return -1;
  if (!Number.isInteger(index) || !Number.isInteger(delta)) {
    throw new RangeError("Candidate index and step must be integers");
  }
  return ((index + delta) % count + count) % count;
}
function windowCandidates(snapshot, history) {
  const windows = snapshot.windows.filter((w) => w.monitorKey === snapshot.sourceMonitorKey && w.workspaceKey === snapshot.currentWorkspaceKey);
  const rank = (w) => {
    var _a;
    if (w.key === snapshot.currentWindowKey) return -1;
    const i = history.indexOf(w.key);
    return i >= 0 ? i : history.length + ((_a = w.focusHistoryID) != null ? _a : 1e5);
  };
  return windows.slice().sort((a, b) => rank(a) - rank(b) || a.key.localeCompare(b.key));
}
function fillWorkspaceSlots(snapshot, slots) {
  const out = snapshot.workspaces.filter((w) => !w.isSpecial).slice();
  for (const monitor of snapshot.monitors) {
    if (monitor.slotStart === null) continue;
    for (let slot = 1; slot <= slots; slot++) {
      const id = monitor.slotStart + slot - 1;
      if (out.some((w) => w.id === id)) continue;
      out.push({
        key: "workspace:" + id,
        id,
        name: String(id),
        localSlot: slot,
        monitorKey: monitor.key,
        homeMonitorKey: monitor.key,
        windowKeys: [],
        isSpecial: false,
        exists: false,
        canCreate: true
      });
    }
  }
  return out;
}
function workspaceCandidates(snapshot, history) {
  const scope = fillWorkspaceSlots(snapshot, 5).filter((w) => w.id !== null && w.id > 0 && w.monitorKey === snapshot.sourceMonitorKey);
  const previous = history.find((key) => key !== snapshot.currentWorkspaceKey && scope.some((w) => w.key === key));
  const rank = (w) => {
    if (w.key === snapshot.currentWorkspaceKey) return -2;
    if (w.key === previous) return -1;
    const i = history.indexOf(w.key);
    return i >= 0 ? i : history.length;
  };
  const stable = (a, b) => {
    var _a, _b, _c, _d;
    return snapshot.monitors.findIndex((m) => m.key === a.monitorKey) - snapshot.monitors.findIndex((m) => m.key === b.monitorKey) || ((_b = (_a = a.localSlot) != null ? _a : a.id) != null ? _b : 1e5) - ((_d = (_c = b.localSlot) != null ? _c : b.id) != null ? _d : 1e5) || a.name.localeCompare(b.name);
  };
  return scope.slice().sort((a, b) => rank(a) - rank(b) || stable(a, b));
}
function workspaceActivationTarget(snapshot, key, monitorKey, slots) {
  if (!snapshot.monitors.some((m) => m.key === monitorKey)) return null;
  const workspace = fillWorkspaceSlots(snapshot, slots).find((w) => w.key === key);
  return workspace && workspace.monitorKey === monitorKey && (workspace.exists || workspace.canCreate) ? workspace : null;
}
function reconcileWorkspaceCandidates(snapshot, history, previousKeys) {
  const fresh = workspaceCandidates(snapshot, history);
  const remaining = new Map(fresh.map((workspace) => [workspace.key, workspace]));
  const out = [];
  for (const key of previousKeys) {
    const workspace = remaining.get(key);
    if (!workspace) continue;
    out.push(workspace);
    remaining.delete(key);
  }
  return out.concat(fresh.filter((workspace) => remaining.has(workspace.key)));
}
function initialSelection(candidates, current, direction, occupiedFirst = false) {
  if (candidates.length === 0) return -1;
  const anchor = candidates.findIndex((c) => c.key === current);
  if (occupiedFirst && anchor !== 0) return direction > 0 ? 0 : candidates.length - 1;
  return wrapIndex(anchor >= 0 ? anchor : direction > 0 ? -1 : 0, direction, candidates.length);
}
function newWorkspace(snapshot, monitorKey, slots) {
  var _a;
  return (_a = fillWorkspaceSlots(snapshot, slots).find((w) => w.monitorKey === monitorKey && !w.exists && w.canCreate)) != null ? _a : null;
}

// src/logic/HistoryLogic.ts
function recordFocus(history, key, limit = 64) {
  if (!Number.isInteger(limit) || limit < 1) {
    throw new RangeError("History limit must be a positive integer");
  }
  if (key.length === 0) return history.slice();
  return [key, ...history.filter((entry) => entry !== key)].slice(0, limit);
}

// src/logic/ApplicationLogic.ts
function applicationKey(window) {
  const identity = (window.applicationId || window.appId).trim().toLowerCase();
  return identity ? "application:" + identity : "application:" + window.key;
}
function applicationCandidates(snapshot, history) {
  const groups = /* @__PURE__ */ new Map();
  for (const window of windowCandidates(snapshot, history)) {
    const key = applicationKey(window);
    let group = groups.get(key);
    if (!group) {
      group = { key, appId: window.applicationId || window.appId, windows: [] };
      groups.set(key, group);
    }
    group.windows.push(window);
  }
  return Array.from(groups.values());
}
function reconcileApplicationCandidates(snapshot, history, previousKeys) {
  const fresh = applicationCandidates(snapshot, history);
  const remaining = new Map(fresh.map((app) => [app.key, app]));
  const out = [];
  for (const key of previousKeys) {
    const app = remaining.get(key);
    if (app) {
      out.push(app);
      remaining.delete(key);
    }
  }
  return out.concat(fresh.filter((app) => remaining.has(app.key)));
}

// src/logic/SessionLogic.ts
function createIdleSession(sessionId = 0) {
  return { phase: "idle", sessionId };
}
function prepareSession(sessionId, request, context) {
  return {
    phase: "preparing",
    sessionId,
    request: __spreadValues({}, request),
    context: __spreadValues({}, context),
    pendingSteps: request.direction,
    releasePending: false
  };
}
function cancelSession(state, sessionId) {
  return state.sessionId === sessionId ? createIdleSession(sessionId) : state;
}
function stepSession(state, sessionId, direction) {
  if (state.sessionId !== sessionId) return state;
  if (state.phase === "preparing") return __spreadProps(__spreadValues({}, state), { pendingSteps: state.pendingSteps + direction });
  if (state.phase !== "selecting") return state;
  return __spreadProps(__spreadValues({}, state), { selectedIndex: wrapIndex(state.selectedIndex, direction, state.candidateKeys.length) });
}
function selectSession(state, index) {
  return state.phase === "selecting" && Number.isInteger(index) && index >= 0 && index < state.candidateKeys.length ? __spreadProps(__spreadValues({}, state), { selectedIndex: index }) : state;
}
function refreshSession(state, sessionId, keys) {
  if (state.phase !== "selecting" || state.sessionId !== sessionId) return state;
  if (keys.length === state.candidateKeys.length && keys.every((key, i) => key === state.candidateKeys[i])) return state;
  const selectedKey = state.candidateKeys[state.selectedIndex];
  const selectedIndex = selectedKey ? keys.indexOf(selectedKey) : initialSelection(keys.map((key) => ({ key })), state.context.originWorkspaceKey, state.request.direction);
  if (selectedKey && selectedIndex < 0) return createIdleSession(sessionId);
  return __spreadProps(__spreadValues({}, state), { candidateKeys: keys.slice(), selectedIndex });
}
function confirmSession(state, sessionId) {
  if (state.sessionId !== sessionId) return state;
  if (state.phase === "preparing") return __spreadProps(__spreadValues({}, state), { releasePending: true });
  if (state.phase !== "selecting") return state;
  const key = state.candidateKeys[state.selectedIndex];
  return key ? {
    phase: "committing",
    sessionId,
    context: state.context,
    request: state.request,
    releasePending: state.releasePending,
    targetKey: key
  } : createIdleSession(sessionId);
}
function resolveSession(state, sessionId, keys, current, occupiedFirst) {
  if (state.phase !== "preparing" || state.sessionId !== sessionId) return state;
  const initial = initialSelection(keys.map((key) => ({ key })), current, state.request.direction, occupiedFirst);
  const selecting = {
    phase: "selecting",
    sessionId,
    context: state.context,
    request: state.request,
    releasePending: state.releasePending,
    candidateKeys: keys.slice(),
    selectedIndex: wrapIndex(initial, state.pendingSteps - state.request.direction, keys.length)
  };
  return state.releasePending ? confirmSession(selecting, sessionId) : selecting;
}

// src/logic/WorkspaceLayout.ts
function navigateGrid(index, count, columns, direction) {
  if (count <= 0) return -1;
  if (index < 0 || index >= count || columns < 1) return index;
  const column = index % columns;
  if (direction === "left") return column > 0 ? index - 1 : index;
  if (direction === "right") return column + 1 < columns && index + 1 < count ? index + 1 : index;
  if (direction === "up") return index >= columns ? index - columns : index;
  return index + columns < count ? index + columns : index;
}
function workspaceGrid(count) {
  if (!Number.isFinite(count) || count <= 0) return { rows: 1, columns: 1 };
  const items = Math.max(1, Math.floor(count));
  const columns = items > 12 ? 4 : Math.ceil(items / Math.floor(Math.sqrt(items)));
  return { rows: Math.ceil(items / columns), columns };
}
function fitGeometry(window, viewport, card) {
  const values = [
    window.x,
    window.y,
    window.width,
    window.height,
    viewport.x,
    viewport.y,
    viewport.width,
    viewport.height,
    card.width,
    card.height
  ];
  if (!values.every(Number.isFinite) || window.width <= 0 || window.height <= 0 || viewport.width <= 0 || viewport.height <= 0 || card.width <= 0 || card.height <= 0) return null;
  const scale = Math.min(card.width / viewport.width, card.height / viewport.height);
  const offsetX = (card.width - viewport.width * scale) / 2;
  const offsetY = (card.height - viewport.height * scale) / 2;
  return {
    x: offsetX + (window.x - viewport.x) * scale,
    y: offsetY + (window.y - viewport.y) * scale,
    width: window.width * scale,
    height: window.height * scale
  };
}

// src/logic/WorkspaceBadge.ts
function workspaceBadge(workspace, monitor) {
  const id = workspace.id;
  if (id === null || id <= 0) return { number: null, visiting: false };
  const start = monitor == null ? void 0 : monitor.slotStart;
  if (start === void 0 || start === null) return { number: id, visiting: false };
  const slot = id - start + 1;
  if (slot < 1 || slot > 10) return { number: id, visiting: true };
  return { number: slot === 10 ? 0 : slot, visiting: false };
}

// src/logic/Validation.ts
var DEFAULT_CONFIG = Object.freeze({
  configVersion: 1,
  previewMode: "snapshot",
  maxCachedWindows: 24,
  cacheBudgetMiB: 128,
  captureConcurrency: 2,
  slotsPerMonitor: 10,
  showWorkspaceLabels: true,
  showMonitorLabels: true,
  debug: false,
  bindingsEnabled: false
});
function isRecord(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
function integer(value, fallback, min, max) {
  return typeof value === "number" && Number.isInteger(value) && value >= min && value <= max ? value : fallback;
}
function boolean(value, fallback) {
  return typeof value === "boolean" ? value : fallback;
}
function parseConfig(raw) {
  const data = isRecord(raw) ? raw : {};
  if (data["configVersion"] !== void 0 && data["configVersion"] !== 1) {
    throw new Error("Unsupported Switchboard config version");
  }
  return {
    configVersion: 1,
    previewMode: "snapshot",
    maxCachedWindows: integer(data["maxCachedWindows"], 24, 1, 256),
    cacheBudgetMiB: integer(data["cacheBudgetMiB"], 128, 16, 1024),
    captureConcurrency: integer(data["captureConcurrency"], 2, 1, 4),
    slotsPerMonitor: integer(data["slotsPerMonitor"], 10, 1, 10),
    showWorkspaceLabels: boolean(data["showWorkspaceLabels"], true),
    showMonitorLabels: boolean(data["showMonitorLabels"], true),
    debug: boolean(data["debug"], false),
    bindingsEnabled: boolean(data["bindingsEnabled"], false)
  };
}
function parseOpenRequest(payloadJson) {
  let value;
  try {
    value = typeof payloadJson === "string" ? JSON.parse(payloadJson) : payloadJson;
  } catch (e) {
    value = null;
  }
  const data = isRecord(value) ? value : {};
  return {
    mode: data["mode"] === "workspace" ? "workspace" : data["mode"] === "app-windows" ? "app-windows" : "window",
    direction: data["direction"] === -1 ? -1 : 1,
    holdToConfirm: data["holdToConfirm"] === true,
    globalInput: data["globalInput"] === true
  };
}
function text(value) {
  return typeof value === "string" ? value : "";
}
function number(value, fallback = 0) {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}
function geometry(value) {
  const data = isRecord(value) ? value : {};
  return { x: number(data["x"]), y: number(data["y"]), width: number(data["width"]), height: number(data["height"]) };
}
function parseSnapshot(raw) {
  const data = isRecord(raw) ? raw : {};
  const list = (value) => Array.isArray(value) ? value.filter(isRecord) : [];
  const monitors = list(data["monitors"]).filter((m) => text(m["key"]) !== "").map((m) => ({
    key: text(m["key"]),
    connector: text(m["connector"]),
    physicalIdentity: text(m["physicalIdentity"]) || null,
    slotStart: typeof m["slotStart"] === "number" && Number.isInteger(m["slotStart"]) && m["slotStart"] > 0 ? m["slotStart"] : null,
    geometry: geometry(m["geometry"]),
    scale: number(m["scale"], 1),
    transform: number(m["transform"])
  }));
  const monitorKeys = monitors.map((m) => m.key);
  const workspaces = list(data["workspaces"]).filter((w) => text(w["key"]) !== "" && monitorKeys.includes(text(w["monitorKey"]))).map((w) => ({
    key: text(w["key"]),
    id: typeof w["id"] === "number" && Number.isInteger(w["id"]) ? w["id"] : null,
    name: text(w["name"]),
    localSlot: typeof w["localSlot"] === "number" && Number.isInteger(w["localSlot"]) ? w["localSlot"] : null,
    monitorKey: text(w["monitorKey"]),
    homeMonitorKey: text(w["homeMonitorKey"]) || null,
    windowKeys: [],
    isSpecial: boolean(w["isSpecial"], false),
    exists: boolean(w["exists"], true),
    canCreate: boolean(w["canCreate"], false)
  }));
  const ordinaryKeys = workspaces.filter((w) => !w.isSpecial).map((w) => w.key);
  const windows = list(data["windows"]).filter((w) => text(w["key"]) !== "" && /^0x[0-9a-f]+$/i.test(text(w["address"])) && ordinaryKeys.includes(text(w["workspaceKey"])) && monitorKeys.includes(text(w["monitorKey"]))).map((w) => ({
    key: text(w["key"]),
    address: text(w["address"]),
    title: text(w["title"]),
    appId: text(w["appId"]),
    applicationId: text(w["applicationId"]) || text(w["appId"]),
    workspaceKey: text(w["workspaceKey"]),
    monitorKey: text(w["monitorKey"]),
    geometry: geometry(w["geometry"]),
    floating: boolean(w["floating"], false),
    fullscreen: boolean(w["fullscreen"], false),
    pinned: boolean(w["pinned"], false),
    focusHistoryID: typeof w["focusHistoryID"] === "number" ? w["focusHistoryID"] : null
  })).filter((w, i, all) => all.findIndex((other) => other.key === w.key) === i);
  return {
    windows,
    monitors,
    workspaces: workspaces.map((w) => __spreadProps(__spreadValues({}, w), { windowKeys: windows.filter((win) => win.workspaceKey === w.key).map((win) => win.key) })),
    currentWindowKey: text(data["currentWindowKey"]) || null,
    currentWorkspaceKey: text(data["currentWorkspaceKey"]) || null,
    sourceMonitorKey: text(data["sourceMonitorKey"]) || null
  };
}
function luaString(value) {
  return '"' + value.replace(/[\\"\x00-\x1f\x7f]/g, (c) => "\\" + (c === "\\" || c === '"' ? c : ("000" + c.charCodeAt(0)).slice(-3))) + '"';
}
export {
  DEFAULT_CONFIG,
  applicationCandidates,
  applicationKey,
  cancelSession,
  confirmSession,
  createIdleSession,
  fillWorkspaceSlots,
  fitGeometry,
  initialSelection,
  luaString,
  navigateGrid,
  newWorkspace,
  parseConfig,
  parseOpenRequest,
  parseSnapshot,
  prepareSession,
  reconcileApplicationCandidates,
  reconcileWorkspaceCandidates,
  recordFocus,
  refreshSession,
  resolveSession,
  selectSession,
  stepSession,
  windowCandidates,
  workspaceActivationTarget,
  workspaceBadge,
  workspaceCandidates,
  workspaceGrid,
  wrapIndex
};
