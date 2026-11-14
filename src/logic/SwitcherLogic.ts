import type { DesktopSnapshot, WindowRecord, WorkspaceRecord } from "../types/Models";

/** Wrap an existing candidate index. Empty lists have no selection. */
export function wrapIndex(index: number, delta: number, count: number): number {
  if (!Number.isInteger(count) || count < 0) {
    throw new RangeError("Candidate count must be a non-negative integer");
  }
  if (count === 0) return -1;
  if (!Number.isInteger(index) || !Number.isInteger(delta)) {
    throw new RangeError("Candidate index and step must be integers");
  }
  return ((index + delta) % count + count) % count;
}

export function windowCandidates(snapshot: DesktopSnapshot, history: readonly string[]): readonly WindowRecord[] {
  const windows = snapshot.windows.filter((w) => w.monitorKey === snapshot.sourceMonitorKey
    && w.workspaceKey === snapshot.currentWorkspaceKey);
  const rank = (w: WindowRecord): number => {
    if (w.key === snapshot.currentWindowKey) return -1;
    const i = history.indexOf(w.key);
    return i >= 0 ? i : history.length + (w.focusHistoryID ?? 100000);
  };
  return windows.slice().sort((a, b) => rank(a) - rank(b) || a.key.localeCompare(b.key));
}

export function fillWorkspaceSlots(snapshot: DesktopSnapshot, slots: number): readonly WorkspaceRecord[] {
  const out = snapshot.workspaces.filter((w) => !w.isSpecial).slice();
  for (const monitor of snapshot.monitors) {
    if (monitor.slotStart === null) continue;
    for (let slot = 1; slot <= slots; slot++) {
      const id = monitor.slotStart + slot - 1;
      // Existing workspaces, including guests, retain their actual monitor ownership.
      if (out.some((w) => w.id === id)) continue;
      out.push({ key: "workspace:" + id, id, name: String(id), localSlot: slot,
        monitorKey: monitor.key, homeMonitorKey: monitor.key, windowKeys: [],
        isSpecial: false, exists: false, canCreate: true });
    }
  }
  return out;
}

export function workspaceCandidates(snapshot: DesktopSnapshot, history: readonly string[]): readonly WorkspaceRecord[] {
  // Omarchy's bar always shows the first five slots of each monitor, then
  // any other numbered workspaces that exist, including visiting workspaces.
  // Fill only those permanent entries; opening the overview must not create them.
  const scope = fillWorkspaceSlots(snapshot, 5).filter((w) => w.id !== null && w.id > 0
    && w.monitorKey === snapshot.sourceMonitorKey);
  const previous = history.find((key) => key !== snapshot.currentWorkspaceKey && scope.some((w) => w.key === key));
  const rank = (w: WorkspaceRecord): number => {
    if (w.key === snapshot.currentWorkspaceKey) return -2;
    if (w.key === previous) return -1;
    const i = history.indexOf(w.key);
    return i >= 0 ? i : history.length;
  };
  const stable = (a: WorkspaceRecord, b: WorkspaceRecord): number =>
    snapshot.monitors.findIndex((m) => m.key === a.monitorKey) - snapshot.monitors.findIndex((m) => m.key === b.monitorKey)
      || (a.localSlot ?? a.id ?? 100000) - (b.localSlot ?? b.id ?? 100000) || a.name.localeCompare(b.name);
  return scope.slice().sort((a, b) => rank(a) - rank(b) || stable(a, b));
}

/** Revalidate the global workspace ID without following it onto another screen. */
export function workspaceActivationTarget(
  snapshot: DesktopSnapshot,
  key: string,
  monitorKey: string,
  slots: number,
): WorkspaceRecord | null {
  if (!snapshot.monitors.some((m) => m.key === monitorKey)) return null;
  const workspace = fillWorkspaceSlots(snapshot, slots).find((w) => w.key === key);
  return workspace && workspace.monitorKey === monitorKey && (workspace.exists || workspace.canCreate)
    ? workspace : null;
}

/** Refresh visiting workspaces while preserving the order the user is navigating. */
export function reconcileWorkspaceCandidates(
  snapshot: DesktopSnapshot,
  history: readonly string[],
  previousKeys: readonly string[],
): readonly WorkspaceRecord[] {
  const fresh = workspaceCandidates(snapshot, history);
  const remaining = new Map(fresh.map((workspace) => [workspace.key, workspace]));
  const out: WorkspaceRecord[] = [];
  for (const key of previousKeys) {
    const workspace = remaining.get(key);
    if (!workspace) continue;
    out.push(workspace);
    remaining.delete(key);
  }
  return out.concat(fresh.filter((workspace) => remaining.has(workspace.key)));
}

export function initialSelection(candidates: readonly { readonly key: string }[], current: string | null, direction: number, occupiedFirst = false): number {
  if (candidates.length === 0) return -1;
  const anchor = candidates.findIndex((c) => c.key === current);
  if (occupiedFirst && anchor !== 0) return direction > 0 ? 0 : candidates.length - 1;
  return wrapIndex(anchor >= 0 ? anchor : direction > 0 ? -1 : 0, direction, candidates.length);
}

export function newWorkspace(snapshot: DesktopSnapshot, monitorKey: string, slots: number): WorkspaceRecord | null {
  return fillWorkspaceSlots(snapshot, slots).find((w) => w.monitorKey === monitorKey && !w.exists && w.canCreate) ?? null;
}
