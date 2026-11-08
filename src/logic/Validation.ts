import type { SwitchboardConfig } from "../types/Models";
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
    slotsPerMonitor: integer(data["slotsPerMonitor"], 10, 1, 100),
    showWorkspaceLabels: boolean(data["showWorkspaceLabels"], true),
    showMonitorLabels: boolean(data["showMonitorLabels"], true),
    debug: boolean(data["debug"], false),
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
    mode: data["mode"] === "workspace" ? "workspace" : "window",
    direction: data["direction"] === -1 ? -1 : 1,
  };
}

// P0: validate compositor records before exposing them to candidate algorithms.
