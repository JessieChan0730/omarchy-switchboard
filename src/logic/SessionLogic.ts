import type {
  IdleSession,
  OpenRequest,
  PreparingSession,
  SessionContext,
  SessionState,
} from "../types/Protocol";

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

// P0: snapshot/step/release/commit transitions depend on verified input ordering.
