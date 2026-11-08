export type WindowKey = string;
export type WorkspaceKey = string;
export type MonitorKey = string;

export interface Geometry {
  readonly x: number;
  readonly y: number;
  readonly width: number;
  readonly height: number;
}

export interface Size {
  readonly width: number;
  readonly height: number;
}

export interface WindowRecord {
  readonly key: WindowKey;
  readonly address: string;
  readonly title: string;
  readonly appId: string;
  readonly workspaceKey: WorkspaceKey;
  readonly monitorKey: MonitorKey;
  readonly geometry: Geometry;
  readonly floating: boolean;
  readonly fullscreen: boolean;
  readonly pinned: boolean;
  readonly focusHistoryID: number | null;
}

export interface WorkspaceRecord {
  readonly key: WorkspaceKey;
  readonly id: number | null;
  readonly name: string;
  readonly localSlot: number | null;
  readonly monitorKey: MonitorKey;
  readonly homeMonitorKey: MonitorKey | null;
  readonly windowKeys: readonly WindowKey[];
  readonly isSpecial: boolean;
  readonly exists: boolean;
  readonly canCreate: boolean;
}

export interface MonitorRecord {
  readonly key: MonitorKey;
  readonly connector: string;
  readonly physicalIdentity: string | null;
  readonly slotStart: number | null;
  readonly geometry: Geometry;
  readonly scale: number;
  readonly transform: number;
}

export interface SwitchboardConfig {
  readonly configVersion: 1;
  readonly previewMode: "snapshot";
  readonly maxCachedWindows: number;
  readonly cacheBudgetMiB: number;
  readonly captureConcurrency: number;
  readonly slotsPerMonitor: number;
  readonly showWorkspaceLabels: boolean;
  readonly showMonitorLabels: boolean;
  readonly debug: boolean;
}
