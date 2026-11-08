import type {
  IdleSession,
  OpenRequest,
  PreparingSession,
  SessionContext,
  SessionState,
} from "../types/Protocol";
import { initialSelection, wrapIndex } from "./SwitcherLogic";

export function createIdleSession(sessionId = 0): IdleSession {
  return { phase: "idle", sessionId };
}

export function prepareSession(
  sessionId: number,
  request: OpenRequest,
  context: SessionContext,
): PreparingSession {
  return {
    phase: "preparing",
    sessionId,
    request: { ...request },
    context: { ...context },
    pendingSteps: request.direction,
    releasePending: false,
  };
}

/** Ignore cancellation from an earlier asynchronous session. */
export function cancelSession(state: SessionState, sessionId: number): SessionState {
  return state.sessionId === sessionId ? createIdleSession(sessionId) : state;
}

export function stepSession(state: SessionState, sessionId: number, direction: number): SessionState {
  if (state.sessionId !== sessionId) return state;
  if (state.phase === "preparing") return { ...state, pendingSteps: state.pendingSteps + direction };
  if (state.phase !== "selecting") return state;
  return { ...state, selectedIndex: wrapIndex(state.selectedIndex, direction, state.candidateKeys.length) };
}

export function selectSession(state: SessionState, index: number): SessionState {
  return state.phase === "selecting" && Number.isInteger(index) && index >= 0 && index < state.candidateKeys.length
    ? { ...state, selectedIndex: index } : state;
}

export function confirmSession(state: SessionState, sessionId: number): SessionState {
  if (state.sessionId !== sessionId) return state;
  if (state.phase === "preparing") return { ...state, releasePending: true };
  if (state.phase !== "selecting") return state;
  const key = state.candidateKeys[state.selectedIndex];
  return key ? { phase: "committing", sessionId, context: state.context, request: state.request,
    releasePending: state.releasePending, targetKey: key } : createIdleSession(sessionId);
}

export function resolveSession(state: SessionState, sessionId: number, keys: readonly string[], current: string | null, occupiedFirst: boolean): SessionState {
  if (state.phase !== "preparing" || state.sessionId !== sessionId) return state;
  const initial = initialSelection(keys.map((key) => ({ key })), current, state.request.direction, occupiedFirst);
  const selecting: SessionState = {
    phase: "selecting", sessionId, context: state.context, request: state.request, releasePending: state.releasePending,
    candidateKeys: keys.slice(), selectedIndex: wrapIndex(initial, state.pendingSteps - state.request.direction, keys.length),
  };
  return state.releasePending ? confirmSession(selecting, sessionId) : selecting;
}
