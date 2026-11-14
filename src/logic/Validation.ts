import type { DesktopSnapshot, Geometry, MonitorRecord, SwitchboardConfig, WindowRecord, WorkspaceRecord } from "../types/Models";
import type { OpenRequest } from "../types/Protocol";

export const DEFAULT_CONFIG: SwitchboardConfig = Object.freeze({
  configVersion: 1,
  previewMode: "snapshot",
  maxCachedWindows: 24,
  cacheBudgetMiB: 128,
  captureConcurrency: 2,
  slotsPerMonitor: 10,
  showWorkspaceLabels: true,
  showMonitorLabels: true,
  debug: false,
  bindingsEnabled: false,
});

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function integer(value: unknown, fallback: number, min: number, max: number): number {
  return typeof value === "number" && Number.isInteger(value) && value >= min && value <= max
    ? value : fallback;
}

function boolean(value: unknown, fallback: boolean): boolean {
  return typeof value === "boolean" ? value : fallback;
}

export function parseConfig(raw: unknown): SwitchboardConfig {
  const data = isRecord(raw) ? raw : {};
  if (data["configVersion"] !== undefined && data["configVersion"] !== 1) {
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
    bindingsEnabled: boolean(data["bindingsEnabled"], false),
  };
}

export function parseOpenRequest(payloadJson: unknown): OpenRequest {
  let value: unknown;
  try {
    value = typeof payloadJson === "string" ? JSON.parse(payloadJson) : payloadJson;
  } catch {
    value = null;
  }
  const data = isRecord(value) ? value : {};
  return {
    mode: data["mode"] === "workspace" ? "workspace" : data["mode"] === "app-windows" ? "app-windows" : "window",
    direction: data["direction"] === -1 ? -1 : 1,
    holdToConfirm: data["holdToConfirm"] === true,
    globalInput: data["globalInput"] === true,
  };
}

function text(value: unknown): string { return typeof value === "string" ? value : ""; }
function number(value: unknown, fallback = 0): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}
function geometry(value: unknown): Geometry {
  const data = isRecord(value) ? value : {};
  return { x: number(data["x"]), y: number(data["y"]), width: number(data["width"]), height: number(data["height"]) };
}

/** QObject data crosses this boundary as unknown; malformed identities are dropped. */
export function parseSnapshot(raw: unknown): DesktopSnapshot {
  const data = isRecord(raw) ? raw : {};
  const list = (value: unknown): Record<string, unknown>[] => Array.isArray(value) ? value.filter(isRecord) : [];
  const monitors: MonitorRecord[] = list(data["monitors"]).filter((m) => text(m["key"]) !== "").map((m) => ({
    key: text(m["key"]), connector: text(m["connector"]), physicalIdentity: text(m["physicalIdentity"]) || null,
    slotStart: typeof m["slotStart"] === "number" && Number.isInteger(m["slotStart"]) && m["slotStart"] > 0 ? m["slotStart"] : null,
    geometry: geometry(m["geometry"]), scale: number(m["scale"], 1), transform: number(m["transform"]),
  }));
  const monitorKeys = monitors.map((m) => m.key);
  const workspaces: WorkspaceRecord[] = list(data["workspaces"]).filter((w) => text(w["key"]) !== "" && monitorKeys.includes(text(w["monitorKey"]))).map((w) => ({
    key: text(w["key"]), id: typeof w["id"] === "number" && Number.isInteger(w["id"]) ? w["id"] : null,
    name: text(w["name"]), localSlot: typeof w["localSlot"] === "number" && Number.isInteger(w["localSlot"]) ? w["localSlot"] : null,
    monitorKey: text(w["monitorKey"]), homeMonitorKey: text(w["homeMonitorKey"]) || null,
    windowKeys: [], isSpecial: boolean(w["isSpecial"], false), exists: boolean(w["exists"], true), canCreate: boolean(w["canCreate"], false),
  }));
  const ordinaryKeys = workspaces.filter((w) => !w.isSpecial).map((w) => w.key);
  const windows: WindowRecord[] = list(data["windows"]).filter((w) => text(w["key"]) !== ""
    && /^0x[0-9a-f]+$/i.test(text(w["address"])) && ordinaryKeys.includes(text(w["workspaceKey"]))
    && monitorKeys.includes(text(w["monitorKey"]))).map((w) => ({
    key: text(w["key"]), address: text(w["address"]), title: text(w["title"]), appId: text(w["appId"]),
    applicationId: text(w["applicationId"]) || text(w["appId"]),
    workspaceKey: text(w["workspaceKey"]), monitorKey: text(w["monitorKey"]), geometry: geometry(w["geometry"]),
    floating: boolean(w["floating"], false), fullscreen: boolean(w["fullscreen"], false), pinned: boolean(w["pinned"], false),
    focusHistoryID: typeof w["focusHistoryID"] === "number" ? w["focusHistoryID"] : null,
  })).filter((w, i, all) => all.findIndex((other) => other.key === w.key) === i);
  return {
    windows, monitors, workspaces: workspaces.map((w) => ({ ...w, windowKeys: windows.filter((win) => win.workspaceKey === w.key).map((win) => win.key) })),
    currentWindowKey: text(data["currentWindowKey"]) || null,
    currentWorkspaceKey: text(data["currentWorkspaceKey"]) || null,
    sourceMonitorKey: text(data["sourceMonitorKey"]) || null,
  };
}

/** Lua string escaping, independent of shell quoting, including control characters. */
export function luaString(value: string): string {
  return '"' + value.replace(/[\\"\x00-\x1f\x7f]/g, (c) => "\\" + (c === "\\" || c === '"' ? c : ("000" + c.charCodeAt(0)).slice(-3))) + '"';
}
