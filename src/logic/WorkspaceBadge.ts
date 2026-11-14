import type { MonitorRecord, WorkspaceRecord } from "../types/Models";

/** A short slot belongs to the current monitor's block; guests keep their ID. */
export function workspaceBadge(
  workspace: WorkspaceRecord,
  monitor: MonitorRecord | undefined,
): { number: number | null; visiting: boolean } {
  const id = workspace.id;
  if (id === null || id <= 0) return { number: null, visiting: false };
  const start = monitor?.slotStart;
  // Without a known block, the global ID is the only unambiguous label.
  if (start === undefined || start === null) return { number: id, visiting: false };
  const slot = id - start + 1;
  if (slot < 1 || slot > 10) return { number: id, visiting: true };
  return { number: slot === 10 ? 0 : slot, visiting: false };
}
