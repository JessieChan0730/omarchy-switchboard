import type { ApplicationRecord, DesktopSnapshot, WindowRecord } from "../types/Models";
import { windowCandidates } from "./SwitcherLogic";

/** Desktop-entry identity groups app classes without merging unknown windows. */
export function applicationKey(window: WindowRecord): string {
  const identity = (window.applicationId || window.appId).trim().toLowerCase();
  return identity ? "application:" + identity : "application:" + window.key;
}

/** First occurrence in window MRU determines both app MRU and its default window. */
export function applicationCandidates(snapshot: DesktopSnapshot, history: readonly string[]): readonly ApplicationRecord[] {
  const groups = new Map<string, { key: string; appId: string; windows: WindowRecord[] }>();
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

/** Keep navigation order stable while adding and removing real windows. */
export function reconcileApplicationCandidates(
  snapshot: DesktopSnapshot, history: readonly string[], previousKeys: readonly string[],
): readonly ApplicationRecord[] {
  const fresh = applicationCandidates(snapshot, history);
  const remaining = new Map(fresh.map((app) => [app.key, app]));
  const out: ApplicationRecord[] = [];
  for (const key of previousKeys) {
    const app = remaining.get(key);
    if (app) { out.push(app); remaining.delete(key); }
  }
  return out.concat(fresh.filter((app) => remaining.has(app.key)));
}
