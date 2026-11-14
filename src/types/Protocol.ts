import type { MonitorKey, WindowKey, WorkspaceKey } from "./Models";

export type SwitcherMode = "window" | "app-windows" | "workspace";
export type Direction = 1 | -1;

export interface OpenRequest {
  readonly mode: SwitcherMode;
  readonly direction: Direction;
  readonly holdToConfirm?: boolean;
  readonly globalInput?: boolean;
}

export interface SessionContext {
  readonly sourceMonitorKey: MonitorKey | null;
  readonly originWindowKey: WindowKey | null;
  readonly originWorkspaceKey: WorkspaceKey | null;
}

export interface IdleSession {
  readonly phase: "idle";
  readonly sessionId: number;
}

interface ActiveSession {
  readonly sessionId: number;
  readonly request: OpenRequest;
  readonly context: SessionContext;
  readonly releasePending: boolean;
}

export interface PreparingSession extends ActiveSession {
  readonly phase: "preparing";
  readonly pendingSteps: number;
}

export interface SelectingSession extends ActiveSession {
  readonly phase: "selecting";
  readonly candidateKeys: readonly string[];
  readonly selectedIndex: number;
}

export interface CommittingSession extends ActiveSession {
  readonly phase: "committing";
  readonly targetKey: string;
}

export type SessionState =
  | IdleSession
  | PreparingSession
  | SelectingSession
  | CommittingSession;

export type SessionEvent =
  | { readonly type: "step"; readonly sessionId: number; readonly direction: Direction }
  | { readonly type: "modifierReleased"; readonly sessionId: number }
  | { readonly type: "confirm"; readonly sessionId: number }
  | { readonly type: "cancel"; readonly sessionId: number };

export type ActivationTarget =
  | { readonly kind: "window"; readonly key: WindowKey }
  | { readonly kind: "workspace"; readonly key: WorkspaceKey };
